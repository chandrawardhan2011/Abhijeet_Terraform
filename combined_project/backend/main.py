from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from proxmoxer import ProxmoxAPI
import subprocess, os, asyncio, json, re, threading
from typing import Optional, Dict, List
from pathlib import Path

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])
app.mount("/static", StaticFiles(directory="../static"), name="static")

@app.get("/scenario_briefings.json")
def scenario_briefings(): return FileResponse("../static/scenario_briefings.json")

PROXMOX_HOST  = "50.50.50.81"
USER          = "root@pam"
PASSWORD      = "Admin@12345"
NODE          = "trg"
TERRAFORM_DIR = "../terraform"
ANSIBLE_DIR   = "../ansible"

OPERATOR_CREDENTIALS = {
    "admin":      "cyberrange2024",
    "operator":   "operator@123",
    "instructor": "instructor@123",
}

VULN_DB: Dict[str, dict] = {
    "ssh_brute_force":  {"id":"ssh_brute_force","name":"SSH Brute Force","description":"Weakens SSH: enables password auth, allows root login, removes lockout","cve":"N/A","severity":"high","vm_types":["linux","ubu","web","db","ftp","wazuh"]},
    "dirty_cow":        {"id":"dirty_cow","name":"Dirty COW (CVE-2016-5195)","description":"Kernel race condition privilege escalation simulation","cve":"CVE-2016-5195","severity":"critical","vm_types":["linux","ubu"]},
    "sudo_privesc":     {"id":"sudo_privesc","name":"Sudo Privilege Escalation","description":"Misconfigured sudoers: NOPASSWD + dangerous commands for any user","cve":"N/A","severity":"critical","vm_types":["linux","ubu","web","db","ftp"]},
    "cronjob_misconfig":{"id":"cronjob_misconfig","name":"Cronjob Misconfiguration","description":"World-writable cron script executed by root every minute","cve":"N/A","severity":"high","vm_types":["linux","ubu","web","db","ftp"]},
    "sql_injection":    {"id":"sql_injection","name":"SQL Injection (OWASP A03)","description":"Vulnerable PHP login page with no sanitisation on port 9001","cve":"N/A","severity":"critical","vm_types":["web"]},
    "ftp_anonymous":    {"id":"ftp_anonymous","name":"FTP Anonymous Login","description":"Anonymous FTP enabled with sensitive files exposed","cve":"N/A","severity":"medium","vm_types":["ftp"]},
    "mysql_brute_force":{"id":"mysql_brute_force","name":"MySQL Brute Force","description":"Remote root MySQL login with weak password bound to all interfaces","cve":"N/A","severity":"critical","vm_types":["db"]},
    "eternal_blue":     {"id":"eternal_blue","name":"EternalBlue (CVE-2017-0144)","description":"SMBv1 enabled, firewall off, weak shares — EternalBlue target","cve":"CVE-2017-0144","severity":"critical","vm_types":["windows","win10"]},
    "rdp_brute_force":  {"id":"rdp_brute_force","name":"RDP Brute Force","description":"RDP with no lockout policy, weak creds, NLA disabled","cve":"N/A","severity":"high","vm_types":["windows","win10"]},
    "pass_the_hash":    {"id":"pass_the_hash","name":"Pass-the-Hash","description":"WDigest enabled, NTLMv1 allowed, SMB signing off","cve":"N/A","severity":"critical","vm_types":["windows","win10"]},
}

# ── Vuln injection log ────────────────────────────────────────────────────────
VULN_LOG_PATH = Path("/tmp/temp/vulb.txt")

def log_vuln_injection(vuln_id: str, vuln: dict) -> None:
    """Append injected vulnerability to /tmp/temp/vulb.txt.
    Format: <serial>:<cve>:<name>
    """
    try:
        VULN_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        # Read existing entries to get next serial number
        existing = []
        if VULN_LOG_PATH.exists():
            existing = [l.strip() for l in VULN_LOG_PATH.read_text().splitlines() if l.strip()]
        # Avoid duplicate entries (same vuln_id already logged)
        already_logged = any(f":{vuln_id}:" in line or line.endswith(f":{vuln['name']}") for line in existing)
        if already_logged:
            return
        serial = len(existing) + 1
        cve    = vuln.get("cve") or "N/A"
        name   = vuln.get("name", vuln_id)
        entry  = f"{serial}:{cve}:{name}"
        with open(VULN_LOG_PATH, "a") as f:
            f.write(entry + "\n")
    except Exception as e:
        print(f"[WARN] Could not write vuln log: {e}")

# ── Global state ───────────────────────────────────────────────────────────────
last_config: dict = {"win10":0,"linux":0,"kali":0,"wazuh":0,"web":0,"db":0,"ftp":0}
deployed_vmids: set = set()
active_exercise: Optional[dict] = None
ansible_state: dict = {"phase":"idle","progress":0,"last_msg":""}
vuln_injection_status: Dict[str, dict] = {}

# ── Models ─────────────────────────────────────────────────────────────────────
class LoginRequest(BaseModel):
    username: str
    password: str

class Deploy(BaseModel):
    win10:int; linux:int; kali:int; wazuh:int; web:int; db:int; ftp:int

class ExerciseConfig(BaseModel):
    name: str; course: str; duration: str; scenario: str
    vm_counts: Dict[str, int]

class VulnInjectRequest(BaseModel):
    target_host: str; vuln_id: str; vm_type: str

# ── Helpers ────────────────────────────────────────────────────────────────────
def get_proxmox():
    return ProxmoxAPI(PROXMOX_HOST, user=USER, password=PASSWORD, verify_ssl=False)

def generate_inventory(cfg: dict) -> str:
    lines = []
    def section(g, hosts):
        lines.append(f"\n[{g}]")
        for n, ip in hosts: lines.append(f"{n} ansible_host={ip}")
    section("wazuh_servers",  [(f"wazuh-server-{i+1}",f"10.0.20.{10+i}") for i in range(cfg.get("wazuh",0))])
    section("web_servers",    [(f"web-server-{i+1}",  f"10.0.20.{20+i}") for i in range(cfg.get("web",0))])
    section("db_servers",     [(f"db-server-{i+1}",   f"10.0.20.{30+i}") for i in range(cfg.get("db",0))])
    section("ftp_servers",    [(f"ftp-server-{i+1}",  f"10.0.20.{40+i}") for i in range(cfg.get("ftp",0))])
    section("linux_clients",  [(f"linux-{i+1}",       f"10.0.20.{200+i}") for i in range(cfg.get("linux",0))])
    section("windows_clients",[(f"windows-{i+1}",     f"10.0.20.{100+i}") for i in range(cfg.get("win10",0))])
    lines += ["\n[servers:children]","wazuh_servers","web_servers","db_servers","ftp_servers",
              "\n[linux_targets:children]","linux_clients","servers",
              "\n[all_clients:children]","linux_clients","windows_clients"]
    return "\n".join(lines) + "\n"

def write_dynamic_inventory(cfg):
    p = os.path.join(ANSIBLE_DIR, "inventory", "hosts.ini")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p,"w").write(generate_inventory(cfg))

def refresh_deployed_vmids():
    global deployed_vmids
    try:
        r = subprocess.run(["terraform","show","-json"], cwd=TERRAFORM_DIR, capture_output=True, text=True, timeout=15)
        if r.returncode != 0 or not r.stdout.strip(): deployed_vmids = set(); return
        state = json.loads(r.stdout)
        resources = (state.get("values") or {}).get("root_module",{}).get("resources",[])
        vmids = set()
        for res in resources:
            if res.get("type") not in ("proxmox_vm_qemu","proxmox_virtual_environment_vm"): continue
            attrs = res.get("values",{})
            raw = attrs.get("vmid") or attrs.get("vm_id") or attrs.get("id")
            if raw is not None:
                try: vmids.add(int(raw))
                except: pass
        deployed_vmids = vmids
    except Exception as e: print(f"[ERROR] vmids: {e}")

def classify_vm(name):
    n = name.lower()
    if any(k in n for k in ("win","windows","w10","win10")): return "windows"
    if "kali" in n: return "kali"
    if any(k in n for k in ("wazuh","web","db","ftp","server")): return "server"
    return "linux"

def is_routable_ipv4(ip):
    if not ip: return False
    p = ip.split(".")
    if len(p) != 4: return False
    try: o = [int(x) for x in p]
    except: return False
    if not all(0<=x<=255 for x in o): return False
    if o[0] in (0,127): return False
    if o[0]==169 and o[1]==254: return False
    if o[0]>=224: return False
    return True

def get_ip_for_vm(vmid):
    px = get_proxmox()
    try:
        cfg = px.nodes(NODE).qemu(vmid).config.get()
        ip0 = cfg.get("ipconfig0","")
        if ip0 and "ip=" in ip0 and "dhcp" not in ip0:
            m = re.search(r"ip=(\d+\.\d+\.\d+\.\d+)", ip0)
            if m and is_routable_ipv4(m.group(1)): return m.group(1)
    except: pass
    try:
        raw = px.nodes(NODE).qemu(vmid).agent("network-get-interfaces").get()
        il = raw if isinstance(raw,list) else raw.get("result",[])
        for iface in il:
            if iface.get("name","") in ("lo","lo0"): continue
            for addr in iface.get("ip-addresses",[]):
                if addr.get("ip-address-type") != "ipv4": continue
                c = addr.get("ip-address","")
                if is_routable_ipv4(c): return c
    except: pass
    return "BOOTING"

# ── HTTP endpoints ─────────────────────────────────────────────────────────────

@app.post("/api/log-vuln-injection")
async def api_log_vuln_injection(request: Request):
    data = await request.json()
    vuln_id = data.get("vuln_id","")
    if vuln_id in VULN_DB:
        log_vuln_injection(vuln_id, VULN_DB[vuln_id])
        return {"ok": True}
    return JSONResponse(status_code=404, content={"error": "unknown vuln"})

@app.get("/")
def home(): return FileResponse("../static/index.html")

@app.post("/api/login")
def login(req: LoginRequest):
    exp = OPERATOR_CREDENTIALS.get(req.username)
    if exp and exp == req.password:
        return {"status":"ok","token":f"cr_{req.username}_session","username":req.username}
    return JSONResponse(status_code=401, content={"status":"error","message":"Invalid credentials"})

@app.get("/api/vulns")
def get_vulns(): return list(VULN_DB.values())

@app.get("/api/vulns/{vm_type}")
def get_vulns_for_type(vm_type: str):
    return [v for v in VULN_DB.values() if vm_type in v["vm_types"]]

@app.post("/api/inject-vuln")
def inject_vuln(req: VulnInjectRequest):
    if req.vuln_id not in VULN_DB:
        return JSONResponse(status_code=404, content={"error": f"Unknown vuln: {req.vuln_id}"})
    key = f"{req.target_host}_{req.vuln_id}"
    vuln_injection_status[key] = {"status":"running","log":[]}
    def run():
        try:
            r = subprocess.run(
                ["ansible-playbook","vuln-inject.yml","-i","inventory/hosts.ini",
                 "-e",f"target_host={req.target_host}","-e",f"vuln_id={req.vuln_id}",
                 "-e",f"vm_type={req.vm_type}",
                 "-e",f"vuln_cve={VULN_DB[req.vuln_id]['cve']}",
                 "-e",f"vuln_name={VULN_DB[req.vuln_id]['name']}"],
                cwd=ANSIBLE_DIR, capture_output=True, text=True, timeout=120)
            vuln_injection_status[key] = {
                "status": "success" if r.returncode==0 else "failed",
                "log": (r.stdout+r.stderr).splitlines()
            }
        except Exception as e:
            vuln_injection_status[key] = {"status":"failed","log":[str(e)]}
    threading.Thread(target=run, daemon=True).start()
    return {"status":"started","key":key}

@app.get("/api/inject-status/{key}")
def inject_status(key: str):
    return vuln_injection_status.get(key, {"status":"not_found","log":[]})

@app.post("/api/exercise/start")
def start_exercise(config: ExerciseConfig):
    global active_exercise, last_config
    last_config = {k: config.vm_counts.get(k,0) for k in ("win10","linux","kali","wazuh","web","db","ftp")}
    active_exercise = {"name":config.name,"course":config.course,"duration":config.duration,
                       "scenario":config.scenario,
                       "vm_counts":last_config,"status":"deploying"}
    return {"status":"ok","exercise":active_exercise}

@app.get("/api/exercise/active")
def get_active_exercise(): return active_exercise or {}

@app.post("/api/exercise/stop")
def stop_exercise():
    global active_exercise; active_exercise = None; return {"status":"ok"}

@app.post("/deploy")
def deploy(data: Deploy):
    global last_config
    last_config = {"win10":data.win10,"linux":data.linux,"kali":data.kali,
                   "wazuh":data.wazuh,"web":data.web,"db":data.db,"ftp":data.ftp}
    return {"status":"started"}

@app.post("/destroy")
def destroy():
    subprocess.run(["terraform","init","-input=false"], cwd=TERRAFORM_DIR, capture_output=True)
    r = subprocess.run(
        ["terraform","destroy","-auto-approve"]+[f"-var={k}_count={v}" for k,v in
         [("win10",last_config["win10"]),("linux",last_config["linux"]),("kali",last_config["kali"]),
          ("wazuh",last_config["wazuh"]),("web",last_config["web"]),("db",last_config["db"]),("ftp",last_config["ftp"])]],
        cwd=TERRAFORM_DIR, capture_output=True, text=True)
    if r.returncode == 0:
        global deployed_vmids; deployed_vmids = set()
    return {"status":"destroyed" if r.returncode==0 else "failed","stderr":r.stderr}

@app.get("/status")
def get_status():
    if not deployed_vmids: return []
    px = get_proxmox()
    vms = []
    try:
        for vm in px.nodes(NODE).qemu.get():
            vmid = int(vm["vmid"])
            if vmid not in deployed_vmids: continue
            ip = get_ip_for_vm(vmid) if vm["status"]=="running" else "STOPPED"
            vms.append({"name":vm["name"],"ip":ip,"status":vm["status"],"type":classify_vm(vm["name"])})
    except Exception as e: print(f"[ERROR] status: {e}"); return []
    return vms

@app.get("/ansible/status")
def get_ansible_status(): return ansible_state

# ── WebSocket Terraform ────────────────────────────────────────────────────────
@app.websocket("/ws")
async def websocket_terraform(ws: WebSocket):
    await ws.accept()
    try: data = await ws.receive_json()
    except: return
    action = data.get("action")
    if action not in ("deploy","destroy"):
        await ws.send_json({"log":f"[ERROR] Unknown action: '{action}'.","progress":0,"complete":True})
        await ws.close(); return
    env  = {**os.environ,"PYTHONUNBUFFERED":"1"}
    loop = asyncio.get_running_loop()
    await ws.send_json({"log":"▶ Running terraform init...","progress":3})
    init_proc = subprocess.Popen(["terraform","init","-input=false"], cwd=TERRAFORM_DIR,
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1, env=env)
    while True:
        line = await loop.run_in_executor(None, init_proc.stdout.readline)
        if line:
            line = line.strip()
            if line:
                try: await ws.send_json({"log":line,"progress":3})
                except: init_proc.kill(); return
        elif init_proc.poll() is not None: break
        else: await asyncio.sleep(0.1)
    init_proc.wait()
    if init_proc.returncode != 0:
        await ws.send_json({"log":"✘ terraform init failed.","progress":0,"complete":True})
        await ws.close(); return
    await ws.send_json({"log":"✔ terraform init complete.","progress":8})
    tf_vars = [
        f"-var=win10_count={last_config.get('win10',0)}",
        f"-var=linux_count={last_config.get('linux',0)}",
        f"-var=kali_count={last_config.get('kali',0)}",
        f"-var=wazuh_count={last_config.get('wazuh',0)}",
        f"-var=web_count={last_config.get('web',0)}",
        f"-var=db_count={last_config.get('db',0)}",
        f"-var=ftp_count={last_config.get('ftp',0)}",
    ]
    cmd = (["stdbuf","-oL","terraform","apply","-auto-approve","-parallelism=1","-lock-timeout=120s"]+tf_vars
           if action=="deploy" else
           ["stdbuf","-oL","terraform","destroy","-auto-approve","-parallelism=1","-lock-timeout=120s"]+tf_vars)
    import queue as queue_module
    process = subprocess.Popen(cmd, cwd=TERRAFORM_DIR, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, bufsize=1, env=env)
    progress = 0

    # Use a queue so readline never blocks the event loop
    line_queue = queue_module.Queue()
    def enqueue_output(out, q):
        for line in iter(out.readline, ''):
            q.put(line)
        q.put(None)  # sentinel
    reader_thread = threading.Thread(target=enqueue_output, args=(process.stdout, line_queue), daemon=True)
    reader_thread.start()

    while True:
        try:
            line = line_queue.get_nowait()
            if line is None:
                break
            line = line.strip()
            if not line: continue
            if "Initializing" in line: progress=10
            elif "Plan:" in line: progress=30
            elif "Creating" in line or "Destroying" in line: progress=60
            elif "Still" in line: progress=80
            elif "complete!" in line: progress=100
            try: await ws.send_json({"log":line,"progress":progress})
            except: process.kill(); return
        except queue_module.Empty:
            if process.poll() is not None:
                break
            # Send keepalive every 15s of silence to keep WS alive
            try: await ws.send_json({"log":"⟳ Terraform running...","progress":progress})
            except: process.kill(); return
            await asyncio.sleep(15)
    process.wait()
    if process.returncode == 0:
        if action=="deploy":
            await loop.run_in_executor(None, refresh_deployed_vmids)
            await loop.run_in_executor(None, write_dynamic_inventory, last_config)
            await ws.send_json({"log":"Terraform complete. Waiting 600s for VMs to boot...","progress":100})
            for i in range(60):
                await asyncio.sleep(10)
                remaining = 600 - (i+1)*10
                try: await ws.send_json({"log":f"⟳ Waiting for VMs to boot... {remaining}s remaining","progress":100})
                except: process.kill(); return
            await ws.send_json({"log":"✔ Terraform complete. Starting Ansible...","progress":100,"ansible_ready":True})
        else:
            global deployed_vmids; deployed_vmids = set()
            await ws.send_json({"log":"✔ Infrastructure destroyed.","progress":100,"complete":True})
    else:
        await ws.send_json({"log":"✘ Terraform failed — check output above.","progress":0,"complete":True})
    try: await ws.close()
    except: pass

# ── WebSocket Ansible ──────────────────────────────────────────────────────────
@app.websocket("/ws/ansible")
async def websocket_ansible(ws: WebSocket):
    await ws.accept()
    global ansible_state
    ansible_state = {"phase":"running","progress":0,"last_msg":"Starting Ansible..."}
    env = {**os.environ,"PYTHONUNBUFFERED":"1","ANSIBLE_FORCE_COLOR":"0","ANSIBLE_HOST_KEY_CHECKING":"False"}
    cmd = ["stdbuf","-oL","ansible-playbook","site.yml","-i","inventory/hosts.ini",
           "--ssh-extra-args","-o StrictHostKeyChecking=no"]
    process = subprocess.Popen(cmd, cwd=ANSIBLE_DIR, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, bufsize=1, env=env)
    progress = 0
    counts   = {"ok":0,"changed":0,"failed":0}
    loop     = asyncio.get_running_loop()
    while True:
        line = await loop.run_in_executor(None, process.stdout.readline)
        if line:
            line = line.rstrip()
            if not line: continue
            l = line.lower()
            if "play [" in l:         progress = max(progress,10)
            if "gathering facts" in l: progress = max(progress,15)
            if "task [" in l:         progress = max(progress,20)
            if "ok:" in l:            progress = min(progress+2,90)
            if "changed:" in l:       progress = min(progress+3,90)
            if "play recap" in l:     progress = 95
            m = re.search(r"ok=(\d+).*changed=(\d+).*failed=(\d+)", line)
            if m:
                counts["ok"]+=int(m.group(1)); counts["changed"]+=int(m.group(2)); counts["failed"]+=int(m.group(3))
            ansible_state["progress"] = progress; ansible_state["last_msg"] = line
            try: await ws.send_json({"log":line,"progress":progress,"counts":counts})
            except: process.kill(); ansible_state["phase"]="failed"; return
        elif process.poll() is not None: break
        else: await asyncio.sleep(0.1)
    process.wait()
    success = process.returncode==0 and counts["failed"]==0
    ansible_state = {"phase":"success" if success else "failed","progress":100 if success else progress,"last_msg":"Ansible complete" if success else "Ansible failed"}
    msg = f"{'✔' if success else '✘'} Ansible {'complete' if success else 'failed'} — {counts['ok']} ok, {counts['changed']} changed, {counts['failed']} failed."
    try: await ws.send_json({"log":msg,"progress":100 if success else progress,"counts":counts,"complete":True,"success":success})
    except: pass
    try: await ws.close()
    except: pass

# ── WebSocket Vuln Injection ───────────────────────────────────────────────────
@app.websocket("/ws/inject")
async def websocket_inject(ws: WebSocket):
    await ws.accept()
    try: data = await ws.receive_json()
    except: return
    target_host = data.get("target_host")
    vuln_id     = data.get("vuln_id")
    vm_type     = data.get("vm_type","linux")
    if vuln_id not in VULN_DB:
        await ws.send_json({"log":f"[ERROR] Unknown vuln: {vuln_id}","complete":True,"success":False})
        await ws.close(); return
    vuln = VULN_DB[vuln_id]
    await ws.send_json({"log":f"▶ Injecting: {vuln['name']} → {target_host}","progress":5})
    env  = {**os.environ,"PYTHONUNBUFFERED":"1","ANSIBLE_FORCE_COLOR":"0"}
    loop = asyncio.get_running_loop()
    cmd  = ["stdbuf","-oL","ansible-playbook","vuln-inject.yml","-i","inventory/hosts.ini",
            "-e",f"target_host={target_host}","-e",f"vuln_id={vuln_id}","-e",f"vm_type={vm_type}",
            "-e",f"vuln_cve={vuln['cve']}",
            "-e",f"vuln_name={vuln['name']}"]
    process = subprocess.Popen(cmd, cwd=ANSIBLE_DIR, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, bufsize=1, env=env)
    progress = 5
    while True:
        line = await loop.run_in_executor(None, process.stdout.readline)
        if line:
            line = line.rstrip()
            if not line: continue
            if "task [" in line.lower(): progress = min(progress+20,85)
            if "ok:"    in line.lower(): progress = min(progress+10,95)
            try: await ws.send_json({"log":line,"progress":progress})
            except: process.kill(); return
        elif process.poll() is not None: break
        else: await asyncio.sleep(0.1)
    process.wait()
    success = process.returncode == 0
    if success:
        log_vuln_injection(vuln_id, vuln)
    try:
        await ws.send_json({"log":f"{'✔' if success else '✘'} Injection {'complete' if success else 'failed'}: {vuln['name']}",
                            "progress":100,"complete":True,"success":success})
    except: pass
    try: await ws.close()
    except: pass
