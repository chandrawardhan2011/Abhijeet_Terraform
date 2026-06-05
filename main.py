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

PROXMOX_HOST  = "50.50.50.200"
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
    # ── Linux — all server types ──────────────────────────────────────────
    "ssh_brute_force":           {"id":"ssh_brute_force","label":"LS01",          "name":"SSH Brute Force",                      "cve":"CWE-307",      "severity":"high",     "vm_types":["linux","ubu","web","db","ftp","wazuh"]},

    "sudo_privesc":              {"id":"sudo_privesc","label":"LS03",             "name":"Sudo Privilege Escalation",             "cve":"CWE-269",      "severity":"critical", "vm_types":["linux","ubu","web","db","ftp"]},
    "cronjob_misconfig":         {"id":"cronjob_misconfig","label":"LS04",        "name":"Cronjob Misconfiguration",              "cve":"CWE-732",      "severity":"high",     "vm_types":["linux","web","db","ftp"]},
    "weak_file_permissions":     {"id":"weak_file_permissions","label":"LS07",    "name":"Weak File Permissions",                 "cve":"CWE-732",      "severity":"medium",   "vm_types":["linux","web","db","ftp","wazuh"]},
    "unpatched_kernel":          {"id":"unpatched_kernel","label":"LS08",         "name":"Unpatched Kernel / ASLR Disabled",      "cve":"CWE-693",      "severity":"critical", "vm_types":["linux","wazuh"]},
    "suid_binary":               {"id":"suid_binary","label":"LS09",              "name":"SUID Binary Misconfiguration",          "cve":"CWE-250",      "severity":"high",     "vm_types":["linux","web","db","ftp"]},
    "nfs_misconfiguration":      {"id":"nfs_misconfiguration","label":"LS10",     "name":"NFS no_root_squash Misconfiguration",   "cve":"CWE-732",      "severity":"high",     "vm_types":["linux","db"]},
    "plain_text_creds":          {"id":"plain_text_creds","label":"LS11",         "name":"Plaintext Credentials in Config",       "cve":"CWE-312",      "severity":"high",     "vm_types":["linux","web","db"]},
    "open_ports":                {"id":"open_ports","label":"LS12",               "name":"Unnecessary Open Ports / No Firewall",  "cve":"CWE-284",      "severity":"medium",   "vm_types":["linux","web","db","ftp","wazuh"]},
    "log_tampering":             {"id":"log_tampering","label":"LS13",            "name":"Log Tampering / Audit Disabled",        "cve":"CWE-778",      "severity":"medium",   "vm_types":["linux","web","db","ftp"]},
    "insecure_service_config":   {"id":"insecure_service_config","label":"LS14",  "name":"Insecure Service Configuration",        "cve":"CWE-16",       "severity":"low",      "vm_types":["web"]},
    # ── Linux — client specific ───────────────────────────────────────────

    "weak_passwords":            {"id":"weak_passwords","label":"LC05",           "name":"Weak User Passwords",                   "cve":"CWE-521",      "severity":"medium",   "vm_types":["linux","ubu"]},
    "unprotected_ssh_keys":      {"id":"unprotected_ssh_keys","label":"LC06",     "name":"Unprotected SSH Private Keys",          "cve":"CWE-312",      "severity":"high",     "vm_types":["linux","ubu"]},
    "no_host_firewall":          {"id":"no_host_firewall","label":"LC07",         "name":"No Host Firewall",                      "cve":"CWE-284",      "severity":"medium",   "vm_types":["linux","ubu"]},
    "kernel_hardening_disabled": {"id":"kernel_hardening_disabled","label":"LC08","name":"Kernel Hardening Disabled",             "cve":"CWE-693",      "severity":"critical", "vm_types":["linux","ubu"]},
    "insecure_bash_history":     {"id":"insecure_bash_history","label":"LC09",    "name":"Sensitive Data in Bash History",        "cve":"CWE-312",      "severity":"low",      "vm_types":["linux","ubu"]},
    "lxd_privesc":               {"id":"lxd_privesc","label":"LC10",              "name":"LXD Group Privilege Escalation",        "cve":"CWE-269",      "severity":"critical", "vm_types":["linux","ubu"]},
    "exposed_api_keys":          {"id":"exposed_api_keys","label":"LC11",         "name":"Exposed API Keys in Environment",       "cve":"CWE-312",      "severity":"high",     "vm_types":["linux","ubu"]},
    "netcat_backdoor":           {"id":"netcat_backdoor","label":"LC12",          "name":"Netcat Backdoor (4444/1337)",            "cve":"CWE-912",      "severity":"critical", "vm_types":["linux","ubu"]},

    # ── Linux — server specific ───────────────────────────────────────────
    "sql_injection":             {"id":"sql_injection","label":"VL01",            "name":"SQL Injection (OWASP A03)",              "cve":"OWASP-A03",    "severity":"critical", "vm_types":["web"]},
    "ftp_anonymous":             {"id":"ftp_anonymous","label":"LS06",            "name":"FTP Anonymous Login",                   "cve":"CWE-287",      "severity":"medium",   "vm_types":["ftp"]},
    "mysql_brute_force":         {"id":"mysql_brute_force","label":"LS05",        "name":"MySQL Remote Root Brute Force",         "cve":"CWE-521",      "severity":"critical", "vm_types":["db"]},
    # ── Windows Clients ───────────────────────────────────────────────────

    "rdp_brute_force":           {"id":"rdp_brute_force","label":"WC02",          "name":"RDP Brute Force — No Lockout",          "cve":"CWE-307",      "severity":"high",     "vm_types":["windows","win10","addc"]},
    "pass_the_hash":             {"id":"pass_the_hash","label":"WC03",            "name":"Pass-the-Hash — WDigest",               "cve":"CWE-522",      "severity":"critical", "vm_types":["windows","win10","addc"]},
    "weak_admin_password":       {"id":"weak_admin_password","label":"WC04",      "name":"Weak Administrator Password",           "cve":"CWE-521",      "severity":"high",     "vm_types":["windows","win10"]},
    "autorun_enabled":           {"id":"autorun_enabled","label":"WC05",          "name":"AutoRun/AutoPlay Enabled",              "cve":"CVE-2010-0568","severity":"medium",   "vm_types":["windows","win10"]},
    "uac_bypass":                {"id":"uac_bypass","label":"WC06",               "name":"UAC Fully Disabled",                    "cve":"CWE-269",      "severity":"critical", "vm_types":["windows","win10"]},
    "powershell_unrestricted":   {"id":"powershell_unrestricted","label":"WC07",  "name":"PowerShell Unrestricted + AMSI Off",    "cve":"CWE-78",       "severity":"high",     "vm_types":["windows","win10"]},

    "lsass_dump":                {"id":"lsass_dump","label":"WC09",               "name":"LSASS Credential Dump — No PPL",        "cve":"CWE-522",      "severity":"critical", "vm_types":["windows","win10","addc"]},
    "smb_signing_off":           {"id":"smb_signing_off","label":"WC10",          "name":"SMB Signing Disabled",                  "cve":"CWE-300",      "severity":"medium",   "vm_types":["windows","win10","addc"]},
    "local_admin_everyone":      {"id":"local_admin_everyone","label":"WC11",     "name":"Everyone in Local Administrators",      "cve":"CWE-269",      "severity":"high",     "vm_types":["windows","win10"]},
    "windows_update_disabled":   {"id":"windows_update_disabled","label":"WC12",  "name":"Windows Update Disabled",               "cve":"CWE-693",      "severity":"low",      "vm_types":["windows","win10"]},
    # ── Windows Clients — additional ─────────────────────────────────────
    "kerberoasting_client":      {"id":"kerberoasting_client","label":"WC13",    "name":"Kerberoastable SPN Account",            "cve":"CWE-522",      "severity":"critical", "vm_types":["windows","win10"]},
    "netbios_enabled":           {"id":"netbios_enabled","label":"WC14",         "name":"NetBIOS/LLMNR Enabled",                 "cve":"CWE-300",      "severity":"medium",   "vm_types":["windows","win10"]},
    "applocker_disabled":        {"id":"applocker_disabled","label":"WC15",      "name":"AppLocker / App Control Disabled",      "cve":"CWE-693",      "severity":"medium",   "vm_types":["windows","win10"]},
    # ── Linux client aliases (different label, same script) ─────────────
    "lc01_dirty_cow":        {"id":"lc01_dirty_cow",        "label":"LC01","script":"dirty_cow",        "name":"Dirty COW / ASLR Disabled",              "cve":"CVE-2016-5195","severity":"critical","vm_types":["linux","ubu"]},
    "lc04_cronjob":          {"id":"lc04_cronjob",          "label":"LC04","script":"cronjob_misconfig", "name":"Writable Cron Jobs",                     "cve":"CWE-732",      "severity":"high",    "vm_types":["linux","ubu"]},
    "lc13_passwd_writable":  {"id":"lc13_passwd_writable",  "label":"LC13","script":"passwd_writable",   "name":"World Writable passwd/shadow",           "cve":"CWE-732",      "severity":"critical","vm_types":["linux","ubu"]},

    # ── ADDC alias ────────────────────────────────────────────────────────
    "ad15_lsass":            {"id":"ad15_lsass",            "label":"AD15","script":"lsass_dump",        "name":"LSASS Dumping Exposure",                 "cve":"CWE-522",      "severity":"critical","vm_types":["addc"]},
    # ── Windows Server / ADDC — additional ──────────────────────────────
    "protected_users_disabled":  {"id":"protected_users_disabled", "label":"AD13","name":"Protected Users Not Enforced",       "cve":"CWE-522","severity":"high",    "vm_types":["addc"]},
    "admin_shares_exposed":      {"id":"admin_shares_exposed",      "label":"AD14","name":"Administrative Shares Exposed",       "cve":"CWE-284","severity":"medium",  "vm_types":["addc"]},
    # ── Windows Server / ADDC ─────────────────────────────────────────────
    "kerberoasting":             {"id":"kerberoasting","label":"AD01",            "name":"Kerberoasting — Weak SPNs",             "cve":"CWE-522",      "severity":"critical", "vm_types":["addc"]},
    "asrep_roasting":            {"id":"asrep_roasting","label":"AD02",           "name":"AS-REP Roasting — No Pre-Auth",         "cve":"CWE-522",      "severity":"high",     "vm_types":["addc"]},
    "dcsync":                    {"id":"dcsync","label":"AD03",                   "name":"DCSync — Replication Rights",           "cve":"CWE-269",      "severity":"critical", "vm_types":["addc"]},
    "password_spray_target":     {"id":"password_spray_target","label":"AD07",    "name":"Password Spray Target",                 "cve":"CWE-521",      "severity":"medium",   "vm_types":["addc"]},
    "golden_ticket_target":      {"id":"golden_ticket_target","label":"AD05",     "name":"Golden Ticket — Weak KRBTGT",           "cve":"CWE-522",      "severity":"critical", "vm_types":["addc"]},
    "domain_user_enum":          {"id":"domain_user_enum","label":"AD06",         "name":"Unauthenticated LDAP/SAM Enum",         "cve":"CWE-200",      "severity":"low",      "vm_types":["addc"]},
    "weak_gpo":                  {"id":"weak_gpo","label":"AD04",                 "name":"Weak Group Policy",                     "cve":"CWE-521",      "severity":"medium",   "vm_types":["addc"]},
    "ad_recycle_disabled":       {"id":"ad_recycle_disabled","label":"AD08",      "name":"AD Auditing Disabled",                  "cve":"CWE-778",      "severity":"low",      "vm_types":["addc"]},
    "ntlm_relay_target":         {"id":"ntlm_relay_target","label":"AD09",        "name":"NTLM Relay — SMB/LDAP Signing Off",     "cve":"CWE-300",      "severity":"high",     "vm_types":["addc"]},
    "unconstrained_delegation":  {"id":"unconstrained_delegation","label":"AD10", "name":"Unconstrained Kerberos Delegation",     "cve":"CWE-522",      "severity":"critical", "vm_types":["addc"]},
    "shadow_credentials":        {"id":"shadow_credentials","label":"AD11",       "name":"Shadow Credentials",                    "cve":"CWE-287",      "severity":"high",     "vm_types":["addc"]},
    "replication_exposed":       {"id":"replication_exposed","label":"AD12",      "name":"Domain Replication Exposed",            "cve":"CWE-269",      "severity":"critical", "vm_types":["addc"]},
    # ── Scenario Scripts ─────────────────────────────────────────────────────
    "scenario_2":                {"id":"scenario_2","label":"SC02",               "name":"Scenario 2 — TryHackMe Lab Setup",      "cve":"CWE-284",      "severity":"critical", "script":"scenario_2",      "vm_types":["windows","win10"]},
    "scenario2linux":            {"id":"scenario2linux","label":"SC03",            "name":"Scenario 2 Linux — TryHackMe Lab",      "cve":"CWE-284",      "severity":"critical", "script":"scenario2linux",   "vm_types":["ubu","linux"]},
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
    lab_mode: str = "both"          # "training" | "exercise" | "both"
    s2_vuln_type: str = ""          # "system" | "web" | ""

class VulnInjectRequest(BaseModel):
    target_host: str; vuln_id: str; vm_type: str

# ── Helpers ────────────────────────────────────────────────────────────────────
def get_proxmox():
    return ProxmoxAPI(PROXMOX_HOST, user=USER, password=PASSWORD, verify_ssl=False)

def generate_inventory(cfg: dict) -> str:
    lines = ["[local]","localhost ansible_connection=local","","\n[addc_servers]","windows-addc ansible_host=10.0.20.101",""]
    def section(g, hosts):
        lines.append(f"\n[{g}]")
        for n, ip in hosts: lines.append(f"{n} ansible_host={ip}")
    section("wazuh_servers",  [(f"wazuh-server-{i+1}",f"10.0.20.{10+i}") for i in range(cfg.get("wazuh",0))])
    section("web_servers",    [(f"web-server-{i+1}",  f"10.0.20.{21+i}") for i in range(cfg.get("web",0))])
    section("db_servers",     [(f"db-server-{i+1}",   f"10.0.20.{30+i}") for i in range(cfg.get("db",0))])
    section("ftp_servers",    [(f"ftp-server-{i+1}",  f"10.0.20.{40+i}") for i in range(cfg.get("ftp",0))])
    section("linux_clients",  [(f"linux-{i+1}",       f"10.0.20.{200+i}") for i in range(cfg.get("linux",0))])
    section("windows_clients",[(f"windows-{i+1}",     f"10.0.20.{150+i}") for i in range(cfg.get("win10",0))])
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

# Manually configured machines always shown alongside Terraform VMs
STATIC_VMS = [
    {"name": "windows-addc", "ip": "10.0.20.101", "status": "running", "type": "windows"}
]

def classify_vm(name):
    n = name.lower()
    if any(k in n for k in ("win","windows","w10","win10","addc")): return "windows"
    if "kali" in n: return "kali"
    if any(k in n for k in ("wazuh","web","db","ftp","server")): return "server"
    if "linux-" in n: return "ubu"   # linux-1, linux-2 … are Ubuntu 22.04 clients
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
                 "-e",f"vuln_name={VULN_DB[req.vuln_id]['name']}",
                 "-e",f"vuln_label={VULN_DB[req.vuln_id].get('label', req.vuln_id)}",
                 "-e",f"vuln_script={VULN_DB[req.vuln_id].get('script', req.vuln_id)}"],
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
                       "lab_mode":config.lab_mode,
                       "s2_vuln_type":config.s2_vuln_type,
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
    return vms + STATIC_VMS

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
    lab_mode = (active_exercise or {}).get("lab_mode","both")
    cmd = ["stdbuf","-oL","ansible-playbook","site.yml","-i","inventory/hosts.ini",
           "--ssh-extra-args","-o StrictHostKeyChecking=no",
           "-e", f"lab_mode={lab_mode}"]
    process = subprocess.Popen(cmd, cwd=ANSIBLE_DIR, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, bufsize=1, env=env)
    progress = 0
    counts   = {"ok":0,"changed":0,"failed":0}
    in_recap = False
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
            if "play recap" in l:     progress = 95; in_recap = True
            if in_recap:
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
            "-e",f"vuln_name={vuln['name']}",
            "-e",f"vuln_label={vuln.get('label', vuln_id)}",
            "-e",f"vuln_script={vuln.get('script', vuln_id)}"]
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


# ── Patch script map — which script to run per VM type ────────────────────────
PATCH_SCRIPTS = {
    # Generic Linux server fallback (used when server type cannot be determined)
    "linux":        "roles/patch/files/patch_linux_servers.sh",
    "linux_server": "roles/patch/files/patch_linux_servers.sh",
    # Linux client
    "linux_client": "roles/patch/files/patch_linux_clients.sh",
    "ubu":          "roles/patch/files/patch_linux_clients.sh",
    # Dedicated per-server-type scripts — each patches common + service-specific vulns
    "web":          "roles/patch/files/patch_web_server.sh",
    "db":           "roles/patch/files/patch_db_server.sh",
    "ftp":          "roles/patch/files/patch_ftp_server.sh",
    "wazuh":        "roles/patch/files/patch_wazuh_server.sh",
    # Windows
    "windows":      "roles/patch/files/patch_windows_client.ps1",
    "win10":        "roles/patch/files/patch_windows_client.ps1",
    "addc":         "roles/patch/files/patch_addc.ps1",
}

@app.websocket("/ws/patch")
async def websocket_patch(ws: WebSocket):
    await ws.accept()
    try: data = await ws.receive_json()
    except: return
    target_host = data.get("target_host")
    vm_type     = data.get("vm_type", "linux")

    # Determine correct patch script
    patch_script = PATCH_SCRIPTS.get(vm_type)
    if not patch_script:
        await ws.send_json({"log": f"[ERROR] No patch script for vm_type: {vm_type}", "complete": True, "success": False})
        await ws.close(); return

    await ws.send_json({"log": f"▶ Patching all vulnerabilities on {target_host}", "progress": 5})

    env  = {**os.environ, "PYTHONUNBUFFERED": "1", "ANSIBLE_FORCE_COLOR": "0"}
    loop = asyncio.get_running_loop()

    is_windows = vm_type in ("windows", "win10", "addc")

    if is_windows:
        # Use a static playbook file — avoids all escaping/YAML generation issues
        # Variables passed via -e at runtime
        cmd = ["stdbuf", "-oL", "ansible-playbook",
               "patch_windows.yml",
               "-i", "inventory/hosts.ini",
               "-e", "target_host={}".format(target_host),
               "-e", "patch_script={}".format(os.path.join(ANSIBLE_DIR, patch_script))]
        tmp_pb_path = None
    else:
        # Run patch .sh via Ansible script module (copies + executes in one step)
        cmd = ["stdbuf", "-oL", "ansible", target_host,
               "-i", "inventory/hosts.ini",
               "-m", "script",
               "-a", patch_script,
               "--become"]

    process = subprocess.Popen(cmd, cwd=ANSIBLE_DIR, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, bufsize=1, env=env)
    progress = 5
    while True:
        line = await loop.run_in_executor(None, process.stdout.readline)
        if line:
            line = line.rstrip()
            if not line: continue
            if any(k in line.lower() for k in ["[+]","ok","changed"]): progress = min(progress+8, 90)
            if any(k in line.lower() for k in ["[!]","error","failed"]): pass
            try: await ws.send_json({"log": line, "progress": progress})
            except: process.kill(); return
        elif process.poll() is not None: break
        else: await asyncio.sleep(0.1)
    process.wait()
    success = process.returncode == 0
    try:
        await ws.send_json({
            "log": f"{'✔' if success else '✘'} Patch {'complete' if success else 'failed'}: {target_host}",
            "progress": 100, "complete": True, "success": success
        })
    except: pass
    try: await ws.close()
    except: passVULN_DB = {
    # ── Linux Client (linux-1 / ubu) ─────────────────────────────────────────
    "ssh_brute_force":           {"id":"ssh_brute_force",           "label":"LS01","script":"ssh_brute_force",           "name":"SSH Brute Force",                       "cve":"CWE-307",       "severity":"high",     "vm_types":["linux","ubu","web","db","ftp","wazuh"]},
    "sudo_privesc":              {"id":"sudo_privesc",               "label":"LS03","script":"sudo_privesc",               "name":"Sudo Privilege Escalation",             "cve":"CWE-269",       "severity":"critical", "vm_types":["linux","ubu","web","db","ftp"]},
    "suid_binary":               {"id":"suid_binary",                "label":"LS09","script":"suid_binary",                "name":"SUID Binary Misconfiguration",          "cve":"CWE-250",       "severity":"high",     "vm_types":["linux","web","db","ftp"]},
    "nfs_misconfiguration":      {"id":"nfs_misconfiguration",       "label":"LS10","script":"nfs_misconfiguration",       "name":"NFS no_root_squash",                    "cve":"CWE-732",       "severity":"high",     "vm_types":["linux","db"]},
    "plain_text_creds":          {"id":"plain_text_creds",           "label":"LS11","script":"plain_text_creds",           "name":"Plaintext Credentials in Config",       "cve":"CWE-312",       "severity":"high",     "vm_types":["linux","ubu","web","db"]},
    "open_ports":                {"id":"open_ports",                  "label":"LS12","script":"open_ports",                 "name":"Unnecessary Open Ports / No Firewall",  "cve":"CWE-284",       "severity":"medium",   "vm_types":["linux","ubu","web","db","ftp","wazuh"]},
    "log_tampering":             {"id":"log_tampering",               "label":"LS13","script":"log_tampering",              "name":"Log Tampering / Audit Disabled",        "cve":"CWE-778",       "severity":"medium",   "vm_types":["linux","ubu","web","db","ftp"]},
    "weak_passwords":            {"id":"weak_passwords",              "label":"LC05","script":"weak_passwords",             "name":"Weak User Passwords",                   "cve":"CWE-521",       "severity":"medium",   "vm_types":["ubu"]},
    "unprotected_ssh_keys":      {"id":"unprotected_ssh_keys",        "label":"LC06","script":"unprotected_ssh_keys",       "name":"Unprotected SSH Private Keys",          "cve":"CWE-312",       "severity":"high",     "vm_types":["ubu"]},
    "no_host_firewall":          {"id":"no_host_firewall",            "label":"LC07","script":"no_host_firewall",           "name":"No Host Firewall",                      "cve":"CWE-284",       "severity":"medium",   "vm_types":["ubu"]},
    "kernel_hardening_disabled": {"id":"kernel_hardening_disabled",   "label":"LC08","script":"kernel_hardening_disabled",  "name":"Kernel Hardening Disabled",             "cve":"CWE-693",       "severity":"critical", "vm_types":["ubu"]},
    "insecure_bash_history":     {"id":"insecure_bash_history",       "label":"LC09","script":"insecure_bash_history",      "name":"Sensitive Data in Bash History",        "cve":"CWE-312",       "severity":"low",      "vm_types":["ubu"]},
    "lxd_privesc":               {"id":"lxd_privesc",                 "label":"LC10","script":"lxd_privesc",                "name":"LXD Group Privilege Escalation",        "cve":"CWE-269",       "severity":"critical", "vm_types":["ubu"]},
    "exposed_api_keys":          {"id":"exposed_api_keys",            "label":"LC11","script":"exposed_api_keys",           "name":"Exposed API Keys in Environment",       "cve":"CWE-312",       "severity":"high",     "vm_types":["ubu"]},
    "netcat_backdoor":           {"id":"netcat_backdoor",             "label":"LC12","script":"netcat_backdoor",            "name":"Netcat Backdoor (4444/1337)",           "cve":"CWE-912",       "severity":"critical", "vm_types":["ubu"]},
    "passwd_writable":           {"id":"passwd_writable",             "label":"LC13","script":"passwd_writable",            "name":"World Writable passwd/shadow",          "cve":"CWE-732",       "severity":"critical", "vm_types":["ubu"]},
    "dirty_cow":                 {"id":"dirty_cow",                   "label":"LC01","script":"dirty_cow",                  "name":"Dirty COW / ASLR Disabled",             "cve":"CVE-2016-5195", "severity":"critical", "vm_types":["ubu"]},
    "lc04_cronjob":              {"id":"lc04_cronjob",                "label":"LC04","script":"cronjob_misconfig",          "name":"Writable Cron Jobs",                    "cve":"CWE-732",       "severity":"high",     "vm_types":["ubu"]},
    "rpcbind_exposed":           {"id":"rpcbind_exposed",             "label":"LC14","script":"rpcbind_exposed",            "name":"RPC Portmapper Exposed",                "cve":"CWE-284",       "severity":"low",      "vm_types":["ubu"]},
    # ── Linux Servers only ───────────────────────────────────────────────────
    "weak_file_permissions":     {"id":"weak_file_permissions",       "label":"LS07","script":"weak_file_permissions",      "name":"Weak File Permissions",                 "cve":"CWE-732",       "severity":"medium",   "vm_types":["linux","web","db","ftp","wazuh"]},
    "mysql_brute_force":         {"id":"mysql_brute_force",           "label":"LS13M","script":"mysql_brute_force",         "name":"MySQL Remote Root",                     "cve":"CWE-521",       "severity":"critical", "vm_types":["db"]},
    "ftp_anonymous":             {"id":"ftp_anonymous",               "label":"LS14F","script":"ftp_anonymous",             "name":"FTP Anonymous Login",                   "cve":"CWE-284",       "severity":"medium",   "vm_types":["ftp"]},
    "insecure_service_config":   {"id":"insecure_service_config",     "label":"LS12A","script":"insecure_service_config",   "name":"Insecure Apache Config",                "cve":"CWE-16",        "severity":"low",      "vm_types":["web"]},
    # ── Windows Client ───────────────────────────────────────────────────────
    "weak_admin_password":       {"id":"weak_admin_password",         "label":"WC01","script":"weak_admin_password",        "name":"Weak Admin Password",                   "cve":"CWE-521",       "severity":"high",     "vm_types":["windows","win10"]},
    "rdp_brute_force":           {"id":"rdp_brute_force",             "label":"WC02","script":"rdp_brute_force",            "name":"RDP Brute Force",                       "cve":"CWE-307",       "severity":"high",     "vm_types":["windows","win10"]},
    "pass_the_hash":             {"id":"pass_the_hash",               "label":"WC03","script":"pass_the_hash",              "name":"Pass-the-Hash / WDigest",               "cve":"CWE-522",       "severity":"critical", "vm_types":["windows","win10"]},
    "uac_bypass":                {"id":"uac_bypass",                  "label":"WC04","script":"uac_bypass",                 "name":"UAC Bypass / Disabled",                 "cve":"CWE-269",       "severity":"critical", "vm_types":["windows","win10"]},
    "powershell_unrestricted":   {"id":"powershell_unrestricted",     "label":"WC05","script":"powershell_unrestricted",    "name":"PowerShell Unrestricted",               "cve":"CWE-732",       "severity":"high",     "vm_types":["windows","win10"]},
    "lsass_dump":                {"id":"lsass_dump",                  "label":"WC06","script":"lsass_dump",                 "name":"LSASS Dump",                            "cve":"CWE-522",       "severity":"critical", "vm_types":["windows","win10"]},
    "smb_signing_off":           {"id":"smb_signing_off",             "label":"WC07","script":"smb_signing_off",            "name":"SMB Signing Off",                       "cve":"CWE-300",       "severity":"medium",   "vm_types":["windows","win10"]},
    "local_admin_everyone":      {"id":"local_admin_everyone",        "label":"WC08","script":"local_admin_everyone",       "name":"Everyone in Local Administrators",      "cve":"CWE-269",       "severity":"high",     "vm_types":["windows","win10"]},
    "applocker_disabled":        {"id":"applocker_disabled",          "label":"WC09","script":"applocker_disabled",         "name":"AppLocker Disabled",                    "cve":"CWE-732",       "severity":"medium",   "vm_types":["windows","win10"]},
    "netbios_enabled":           {"id":"netbios_enabled",             "label":"WC10","script":"netbios_enabled",            "name":"NetBIOS / LLMNR Enabled",               "cve":"CWE-300",       "severity":"medium",   "vm_types":["windows","win10"]},
    "ntlm_relay_target":         {"id":"ntlm_relay_target",           "label":"WC11","script":"ntlm_relay_target",          "name":"NTLM Relay Target",                     "cve":"CWE-300",       "severity":"high",     "vm_types":["windows","win10"]},
    "autorun_enabled":           {"id":"autorun_enabled",             "label":"WC12","script":"autorun_enabled",            "name":"AutoRun Enabled",                       "cve":"CWE-114",       "severity":"medium",   "vm_types":["windows","win10"]},
    "windows_update_disabled":   {"id":"windows_update_disabled",     "label":"WC13","script":"windows_update_disabled",   "name":"Windows Update Disabled",               "cve":"CWE-1329",      "severity":"low",      "vm_types":["windows","win10"]},
    # ── ADDC ─────────────────────────────────────────────────────────────────
    "asrep_roasting":            {"id":"asrep_roasting",              "label":"AD01","script":"asrep_roasting",             "name":"AS-REP Roasting",                       "cve":"CWE-522",       "severity":"critical", "vm_types":["addc"]},
    "dcsync":                    {"id":"dcsync",                      "label":"AD02","script":"dcsync",                     "name":"DCSync",                                "cve":"CWE-269",       "severity":"critical", "vm_types":["addc"]},
    "domain_user_enum":          {"id":"domain_user_enum",            "label":"AD03","script":"domain_user_enum",           "name":"Domain User Enumeration",               "cve":"CWE-284",       "severity":"medium",   "vm_types":["addc"]},
    "golden_ticket_target":      {"id":"golden_ticket_target",        "label":"AD04","script":"golden_ticket_target",       "name":"Golden Ticket Target",                  "cve":"CWE-522",       "severity":"critical", "vm_types":["addc"]},
    "kerberoasting":             {"id":"kerberoasting",               "label":"AD05","script":"kerberoasting",              "name":"Kerberoasting",                         "cve":"CWE-522",       "severity":"critical", "vm_types":["addc"]},
    "password_spray_target":     {"id":"password_spray_target",       "label":"AD06","script":"password_spray_target",      "name":"Password Spray Target",                 "cve":"CWE-521",       "severity":"high",     "vm_types":["addc"]},
    "protected_users_disabled":  {"id":"protected_users_disabled",    "label":"AD07","script":"protected_users_disabled",   "name":"Protected Users Disabled",              "cve":"CWE-269",       "severity":"high",     "vm_types":["addc"]},
    "replication_exposed":       {"id":"replication_exposed",         "label":"AD08","script":"replication_exposed",        "name":"Replication Exposed",                   "cve":"CWE-269",       "severity":"critical", "vm_types":["addc"]},
    "shadow_credentials":        {"id":"shadow_credentials",          "label":"AD09","script":"shadow_credentials",         "name":"Shadow Credentials",                    "cve":"CWE-522",       "severity":"critical", "vm_types":["addc"]},
    "unconstrained_delegation":  {"id":"unconstrained_delegation",    "label":"AD10","script":"unconstrained_delegation",   "name":"Unconstrained Delegation",              "cve":"CWE-269",       "severity":"critical", "vm_types":["addc"]},
    "weak_gpo":                  {"id":"weak_gpo",                    "label":"AD11","script":"weak_gpo",                   "name":"Weak GPO / Password Policy",            "cve":"CWE-521",       "severity":"medium",   "vm_types":["addc"]},
    "ad_recycle_disabled":       {"id":"ad_recycle_disabled",         "label":"AD12","script":"ad_recycle_disabled",        "name":"AD Recycle Bin Disabled / Auditing Cleared","cve":"CWE-269",   "severity":"critical", "vm_types":["addc"]},
    # ── Scenario Scripts ─────────────────────────────────────────────────────
    "scenario_2":                {"id":"scenario_2",                  "label":"SC02","script":"scenario_2",                 "name":"Scenario 2 — TryHackMe Lab Setup",      "cve":"CWE-284",       "severity":"critical", "vm_types":["windows","win10"]},
    "scenario2linux":            {"id":"scenario2linux",              "label":"SC03","script":"scenario2linux",             "name":"Scenario 2 Linux — TryHackMe Lab",      "cve":"CWE-284",       "severity":"critical", "vm_types":["ubu","linux"]},
    "scenario3win":              {"id":"scenario3win",                "label":"SC04","script":"scenario3win",               "name":"Scenario 3 Windows — Full Injection",   "cve":"CWE-284",       "severity":"critical", "vm_types":["windows","win10"]},
    "scenario3linux":            {"id":"scenario3linux",              "label":"SC05","script":"scenario3linux",             "name":"Scenario 3 Linux — Full Injection",     "cve":"CWE-284",       "severity":"critical", "vm_types":["ubu","linux"]},
}
app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])
app.mount("/static", StaticFiles(directory="../static"), name="static")

@app.get("/scenario_briefings.json")
def scenario_briefings(): return FileResponse("../static/scenario_briefings.json")

PROXMOX_HOST  = "50.50.50.200"
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
    # ── Linux — all server types ──────────────────────────────────────────
    "ssh_brute_force":           {"id":"ssh_brute_force","label":"LS01",          "name":"SSH Brute Force",                      "cve":"CWE-307",      "severity":"high",     "vm_types":["linux","ubu","web","db","ftp","wazuh"]},

    "sudo_privesc":              {"id":"sudo_privesc","label":"LS03",             "name":"Sudo Privilege Escalation",             "cve":"CWE-269",      "severity":"critical", "vm_types":["linux","ubu","web","db","ftp"]},
    "cronjob_misconfig":         {"id":"cronjob_misconfig","label":"LS04",        "name":"Cronjob Misconfiguration",              "cve":"CWE-732",      "severity":"high",     "vm_types":["linux","web","db","ftp"]},
    "weak_file_permissions":     {"id":"weak_file_permissions","label":"LS07",    "name":"Weak File Permissions",                 "cve":"CWE-732",      "severity":"medium",   "vm_types":["linux","web","db","ftp","wazuh"]},
    "unpatched_kernel":          {"id":"unpatched_kernel","label":"LS08",         "name":"Unpatched Kernel / ASLR Disabled",      "cve":"CWE-693",      "severity":"critical", "vm_types":["linux","wazuh"]},
    "suid_binary":               {"id":"suid_binary","label":"LS09",              "name":"SUID Binary Misconfiguration",          "cve":"CWE-250",      "severity":"high",     "vm_types":["linux","web","db","ftp"]},
    "nfs_misconfiguration":      {"id":"nfs_misconfiguration","label":"LS10",     "name":"NFS no_root_squash Misconfiguration",   "cve":"CWE-732",      "severity":"high",     "vm_types":["linux","db"]},
    "plain_text_creds":          {"id":"plain_text_creds","label":"LS11",         "name":"Plaintext Credentials in Config",       "cve":"CWE-312",      "severity":"high",     "vm_types":["linux","web","db"]},
    "open_ports":                {"id":"open_ports","label":"LS12",               "name":"Unnecessary Open Ports / No Firewall",  "cve":"CWE-284",      "severity":"medium",   "vm_types":["linux","web","db","ftp","wazuh"]},
    "log_tampering":             {"id":"log_tampering","label":"LS13",            "name":"Log Tampering / Audit Disabled",        "cve":"CWE-778",      "severity":"medium",   "vm_types":["linux","web","db","ftp"]},
    "insecure_service_config":   {"id":"insecure_service_config","label":"LS14",  "name":"Insecure Service Configuration",        "cve":"CWE-16",       "severity":"low",      "vm_types":["web"]},
    # ── Linux — client specific ───────────────────────────────────────────

    "weak_passwords":            {"id":"weak_passwords","label":"LC05",           "name":"Weak User Passwords",                   "cve":"CWE-521",      "severity":"medium",   "vm_types":["linux","ubu"]},
    "unprotected_ssh_keys":      {"id":"unprotected_ssh_keys","label":"LC06",     "name":"Unprotected SSH Private Keys",          "cve":"CWE-312",      "severity":"high",     "vm_types":["linux","ubu"]},
    "no_host_firewall":          {"id":"no_host_firewall","label":"LC07",         "name":"No Host Firewall",                      "cve":"CWE-284",      "severity":"medium",   "vm_types":["linux","ubu"]},
    "kernel_hardening_disabled": {"id":"kernel_hardening_disabled","label":"LC08","name":"Kernel Hardening Disabled",             "cve":"CWE-693",      "severity":"critical", "vm_types":["linux","ubu"]},
    "insecure_bash_history":     {"id":"insecure_bash_history","label":"LC09",    "name":"Sensitive Data in Bash History",        "cve":"CWE-312",      "severity":"low",      "vm_types":["linux","ubu"]},
    "lxd_privesc":               {"id":"lxd_privesc","label":"LC10",              "name":"LXD Group Privilege Escalation",        "cve":"CWE-269",      "severity":"critical", "vm_types":["linux","ubu"]},
    "exposed_api_keys":          {"id":"exposed_api_keys","label":"LC11",         "name":"Exposed API Keys in Environment",       "cve":"CWE-312",      "severity":"high",     "vm_types":["linux","ubu"]},
    "netcat_backdoor":           {"id":"netcat_backdoor","label":"LC12",          "name":"Netcat Backdoor (4444/1337)",            "cve":"CWE-912",      "severity":"critical", "vm_types":["linux","ubu"]},

    # ── Linux — server specific ───────────────────────────────────────────
    "sql_injection":             {"id":"sql_injection","label":"VL01",            "name":"SQL Injection (OWASP A03)",              "cve":"OWASP-A03",    "severity":"critical", "vm_types":["web"]},
    "ftp_anonymous":             {"id":"ftp_anonymous","label":"LS06",            "name":"FTP Anonymous Login",                   "cve":"CWE-287",      "severity":"medium",   "vm_types":["ftp"]},
    "mysql_brute_force":         {"id":"mysql_brute_force","label":"LS05",        "name":"MySQL Remote Root Brute Force",         "cve":"CWE-521",      "severity":"critical", "vm_types":["db"]},
    # ── Windows Clients ───────────────────────────────────────────────────

    "rdp_brute_force":           {"id":"rdp_brute_force","label":"WC02",          "name":"RDP Brute Force — No Lockout",          "cve":"CWE-307",      "severity":"high",     "vm_types":["windows","win10","addc"]},
    "pass_the_hash":             {"id":"pass_the_hash","label":"WC03",            "name":"Pass-the-Hash — WDigest",               "cve":"CWE-522",      "severity":"critical", "vm_types":["windows","win10","addc"]},
    "weak_admin_password":       {"id":"weak_admin_password","label":"WC04",      "name":"Weak Administrator Password",           "cve":"CWE-521",      "severity":"high",     "vm_types":["windows","win10"]},
    "autorun_enabled":           {"id":"autorun_enabled","label":"WC05",          "name":"AutoRun/AutoPlay Enabled",              "cve":"CVE-2010-0568","severity":"medium",   "vm_types":["windows","win10"]},
    "uac_bypass":                {"id":"uac_bypass","label":"WC06",               "name":"UAC Fully Disabled",                    "cve":"CWE-269",      "severity":"critical", "vm_types":["windows","win10"]},
    "powershell_unrestricted":   {"id":"powershell_unrestricted","label":"WC07",  "name":"PowerShell Unrestricted + AMSI Off",    "cve":"CWE-78",       "severity":"high",     "vm_types":["windows","win10"]},

    "lsass_dump":                {"id":"lsass_dump","label":"WC09",               "name":"LSASS Credential Dump — No PPL",        "cve":"CWE-522",      "severity":"critical", "vm_types":["windows","win10","addc"]},
    "smb_signing_off":           {"id":"smb_signing_off","label":"WC10",          "name":"SMB Signing Disabled",                  "cve":"CWE-300",      "severity":"medium",   "vm_types":["windows","win10","addc"]},
    "local_admin_everyone":      {"id":"local_admin_everyone","label":"WC11",     "name":"Everyone in Local Administrators",      "cve":"CWE-269",      "severity":"high",     "vm_types":["windows","win10"]},
    "windows_update_disabled":   {"id":"windows_update_disabled","label":"WC12",  "name":"Windows Update Disabled",               "cve":"CWE-693",      "severity":"low",      "vm_types":["windows","win10"]},
    # ── Windows Clients — additional ─────────────────────────────────────
    "kerberoasting_client":      {"id":"kerberoasting_client","label":"WC13",    "name":"Kerberoastable SPN Account",            "cve":"CWE-522",      "severity":"critical", "vm_types":["windows","win10"]},
    "netbios_enabled":           {"id":"netbios_enabled","label":"WC14",         "name":"NetBIOS/LLMNR Enabled",                 "cve":"CWE-300",      "severity":"medium",   "vm_types":["windows","win10"]},
    "applocker_disabled":        {"id":"applocker_disabled","label":"WC15",      "name":"AppLocker / App Control Disabled",      "cve":"CWE-693",      "severity":"medium",   "vm_types":["windows","win10"]},
    # ── Linux client aliases (different label, same script) ─────────────
    "lc01_dirty_cow":        {"id":"lc01_dirty_cow",        "label":"LC01","script":"dirty_cow",        "name":"Dirty COW / ASLR Disabled",              "cve":"CVE-2016-5195","severity":"critical","vm_types":["linux","ubu"]},
    "lc04_cronjob":          {"id":"lc04_cronjob",          "label":"LC04","script":"cronjob_misconfig", "name":"Writable Cron Jobs",                     "cve":"CWE-732",      "severity":"high",    "vm_types":["linux","ubu"]},
    "lc13_passwd_writable":  {"id":"lc13_passwd_writable",  "label":"LC13","script":"passwd_writable",   "name":"World Writable passwd/shadow",           "cve":"CWE-732",      "severity":"critical","vm_types":["linux","ubu"]},

    # ── ADDC alias ────────────────────────────────────────────────────────
    "ad15_lsass":            {"id":"ad15_lsass",            "label":"AD15","script":"lsass_dump",        "name":"LSASS Dumping Exposure",                 "cve":"CWE-522",      "severity":"critical","vm_types":["addc"]},
    # ── Windows Server / ADDC — additional ──────────────────────────────
    "protected_users_disabled":  {"id":"protected_users_disabled", "label":"AD13","name":"Protected Users Not Enforced",       "cve":"CWE-522","severity":"high",    "vm_types":["addc"]},
    "admin_shares_exposed":      {"id":"admin_shares_exposed",      "label":"AD14","name":"Administrative Shares Exposed",       "cve":"CWE-284","severity":"medium",  "vm_types":["addc"]},
    # ── Windows Server / ADDC ─────────────────────────────────────────────
    "kerberoasting":             {"id":"kerberoasting","label":"AD01",            "name":"Kerberoasting — Weak SPNs",             "cve":"CWE-522",      "severity":"critical", "vm_types":["addc"]},
    "asrep_roasting":            {"id":"asrep_roasting","label":"AD02",           "name":"AS-REP Roasting — No Pre-Auth",         "cve":"CWE-522",      "severity":"high",     "vm_types":["addc"]},
    "dcsync":                    {"id":"dcsync","label":"AD03",                   "name":"DCSync — Replication Rights",           "cve":"CWE-269",      "severity":"critical", "vm_types":["addc"]},
    "password_spray_target":     {"id":"password_spray_target","label":"AD07",    "name":"Password Spray Target",                 "cve":"CWE-521",      "severity":"medium",   "vm_types":["addc"]},
    "golden_ticket_target":      {"id":"golden_ticket_target","label":"AD05",     "name":"Golden Ticket — Weak KRBTGT",           "cve":"CWE-522",      "severity":"critical", "vm_types":["addc"]},
    "domain_user_enum":          {"id":"domain_user_enum","label":"AD06",         "name":"Unauthenticated LDAP/SAM Enum",         "cve":"CWE-200",      "severity":"low",      "vm_types":["addc"]},
    "weak_gpo":                  {"id":"weak_gpo","label":"AD04",                 "name":"Weak Group Policy",                     "cve":"CWE-521",      "severity":"medium",   "vm_types":["addc"]},
    "ad_recycle_disabled":       {"id":"ad_recycle_disabled","label":"AD08",      "name":"AD Auditing Disabled",                  "cve":"CWE-778",      "severity":"low",      "vm_types":["addc"]},
    "ntlm_relay_target":         {"id":"ntlm_relay_target","label":"AD09",        "name":"NTLM Relay — SMB/LDAP Signing Off",     "cve":"CWE-300",      "severity":"high",     "vm_types":["addc"]},
    "unconstrained_delegation":  {"id":"unconstrained_delegation","label":"AD10", "name":"Unconstrained Kerberos Delegation",     "cve":"CWE-522",      "severity":"critical", "vm_types":["addc"]},
    "shadow_credentials":        {"id":"shadow_credentials","label":"AD11",       "name":"Shadow Credentials",                    "cve":"CWE-287",      "severity":"high",     "vm_types":["addc"]},
    "replication_exposed":       {"id":"replication_exposed","label":"AD12",      "name":"Domain Replication Exposed",            "cve":"CWE-269",      "severity":"critical", "vm_types":["addc"]},
    # ── Scenario Scripts ─────────────────────────────────────────────────────
    "scenario_2":                {"id":"scenario_2","label":"SC02",               "name":"Scenario 2 — TryHackMe Lab Setup",      "cve":"CWE-284",      "severity":"critical", "script":"scenario_2",      "vm_types":["windows","win10"]},
    "scenario2linux":            {"id":"scenario2linux","label":"SC03",            "name":"Scenario 2 Linux — TryHackMe Lab",      "cve":"CWE-284",      "severity":"critical", "script":"scenario2linux",   "vm_types":["ubu","linux"]},
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
    lab_mode: str = "both"          # "training" | "exercise" | "both"
    s2_vuln_type: str = ""          # "system" | "web" | ""

class VulnInjectRequest(BaseModel):
    target_host: str; vuln_id: str; vm_type: str

# ── Helpers ────────────────────────────────────────────────────────────────────
def get_proxmox():
    return ProxmoxAPI(PROXMOX_HOST, user=USER, password=PASSWORD, verify_ssl=False)

def generate_inventory(cfg: dict) -> str:
    lines = ["[local]","localhost ansible_connection=local","","\n[addc_servers]","windows-addc ansible_host=10.0.20.101",""]
    def section(g, hosts):
        lines.append(f"\n[{g}]")
        for n, ip in hosts: lines.append(f"{n} ansible_host={ip}")
    section("wazuh_servers",  [(f"wazuh-server-{i+1}",f"10.0.20.{10+i}") for i in range(cfg.get("wazuh",0))])
    section("web_servers",    [(f"web-server-{i+1}",  f"10.0.20.{21+i}") for i in range(cfg.get("web",0))])
    section("db_servers",     [(f"db-server-{i+1}",   f"10.0.20.{30+i}") for i in range(cfg.get("db",0))])
    section("ftp_servers",    [(f"ftp-server-{i+1}",  f"10.0.20.{40+i}") for i in range(cfg.get("ftp",0))])
    section("linux_clients",  [(f"linux-{i+1}",       f"10.0.20.{200+i}") for i in range(cfg.get("linux",0))])
    section("windows_clients",[(f"windows-{i+1}",     f"10.0.20.{150+i}") for i in range(cfg.get("win10",0))])
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

# Manually configured machines always shown alongside Terraform VMs
STATIC_VMS = [
    {"name": "windows-addc", "ip": "10.0.20.101", "status": "running", "type": "windows"}
]

def classify_vm(name):
    n = name.lower()
    if any(k in n for k in ("win","windows","w10","win10","addc")): return "windows"
    if "kali" in n: return "kali"
    if any(k in n for k in ("wazuh","web","db","ftp","server")): return "server"
    if "linux-" in n: return "ubu"   # linux-1, linux-2 … are Ubuntu 22.04 clients
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
                 "-e",f"vuln_name={VULN_DB[req.vuln_id]['name']}",
                 "-e",f"vuln_label={VULN_DB[req.vuln_id].get('label', req.vuln_id)}",
                 "-e",f"vuln_script={VULN_DB[req.vuln_id].get('script', req.vuln_id)}"],
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
                       "lab_mode":config.lab_mode,
                       "s2_vuln_type":config.s2_vuln_type,
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
    return vms + STATIC_VMS

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
    lab_mode = (active_exercise or {}).get("lab_mode","both")
    cmd = ["stdbuf","-oL","ansible-playbook","site.yml","-i","inventory/hosts.ini",
           "--ssh-extra-args","-o StrictHostKeyChecking=no",
           "-e", f"lab_mode={lab_mode}"]
    process = subprocess.Popen(cmd, cwd=ANSIBLE_DIR, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, bufsize=1, env=env)
    progress = 0
    counts   = {"ok":0,"changed":0,"failed":0}
    in_recap = False
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
            if "play recap" in l:     progress = 95; in_recap = True
            if in_recap:
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
            "-e",f"vuln_name={vuln['name']}",
            "-e",f"vuln_label={vuln.get('label', vuln_id)}",
            "-e",f"vuln_script={vuln.get('script', vuln_id)}"]
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


# ── Patch script map — which script to run per VM type ────────────────────────
PATCH_SCRIPTS = {
    # Generic Linux server fallback (used when server type cannot be determined)
    "linux":        "roles/patch/files/patch_linux_servers.sh",
    "linux_server": "roles/patch/files/patch_linux_servers.sh",
    # Linux client
    "linux_client": "roles/patch/files/patch_linux_clients.sh",
    "ubu":          "roles/patch/files/patch_linux_clients.sh",
    # Dedicated per-server-type scripts — each patches common + service-specific vulns
    "web":          "roles/patch/files/patch_web_server.sh",
    "db":           "roles/patch/files/patch_db_server.sh",
    "ftp":          "roles/patch/files/patch_ftp_server.sh",
    "wazuh":        "roles/patch/files/patch_wazuh_server.sh",
    # Windows
    "windows":      "roles/patch/files/patch_windows_client.ps1",
    "win10":        "roles/patch/files/patch_windows_client.ps1",
    "addc":         "roles/patch/files/patch_addc.ps1",
}

@app.websocket("/ws/patch")
async def websocket_patch(ws: WebSocket):
    await ws.accept()
    try: data = await ws.receive_json()
    except: return
    target_host = data.get("target_host")
    vm_type     = data.get("vm_type", "linux")

    # Determine correct patch script
    patch_script = PATCH_SCRIPTS.get(vm_type)
    if not patch_script:
        await ws.send_json({"log": f"[ERROR] No patch script for vm_type: {vm_type}", "complete": True, "success": False})
        await ws.close(); return

    await ws.send_json({"log": f"▶ Patching all vulnerabilities on {target_host}", "progress": 5})

    env  = {**os.environ, "PYTHONUNBUFFERED": "1", "ANSIBLE_FORCE_COLOR": "0"}
    loop = asyncio.get_running_loop()

    is_windows = vm_type in ("windows", "win10", "addc")

    if is_windows:
        # Use a static playbook file — avoids all escaping/YAML generation issues
        # Variables passed via -e at runtime
        cmd = ["stdbuf", "-oL", "ansible-playbook",
               "patch_windows.yml",
               "-i", "inventory/hosts.ini",
               "-e", "target_host={}".format(target_host),
               "-e", "patch_script={}".format(os.path.join(ANSIBLE_DIR, patch_script))]
        tmp_pb_path = None
    else:
        # Run patch .sh via Ansible script module (copies + executes in one step)
        cmd = ["stdbuf", "-oL", "ansible", target_host,
               "-i", "inventory/hosts.ini",
               "-m", "script",
               "-a", patch_script,
               "--become"]

    process = subprocess.Popen(cmd, cwd=ANSIBLE_DIR, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, bufsize=1, env=env)
    progress = 5
    while True:
        line = await loop.run_in_executor(None, process.stdout.readline)
        if line:
            line = line.rstrip()
            if not line: continue
            if any(k in line.lower() for k in ["[+]","ok","changed"]): progress = min(progress+8, 90)
            if any(k in line.lower() for k in ["[!]","error","failed"]): pass
            try: await ws.send_json({"log": line, "progress": progress})
            except: process.kill(); return
        elif process.poll() is not None: break
        else: await asyncio.sleep(0.1)
    process.wait()
    success = process.returncode == 0
    try:
        await ws.send_json({
            "log": f"{'✔' if success else '✘'} Patch {'complete' if success else 'failed'}: {target_host}",
            "progress": 100, "complete": True, "success": success
        })
    except: pass
    try: await ws.close()
    except: pass
