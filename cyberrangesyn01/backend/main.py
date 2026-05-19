from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from proxmoxer import ProxmoxAPI
import subprocess
import os
import asyncio
import json
import re

app = FastAPI()
app.mount("/static", StaticFiles(directory="../static"), name="static")

PROXMOX_HOST  = "50.50.50.81"
USER          = "root@pam"
PASSWORD      = "Admin@12345"
NODE          = "pve"
TERRAFORM_DIR = "../terraform"
ANSIBLE_DIR   = "../ansible"

def get_proxmox() :
    return ProxmoxAPI(PROXMOX_HOST,user=USER,password=PASSWORD,verify_ssl=False)


class Deploy(BaseModel):
    win10:  int
    linux:  int
    kali:   int
    wazuh:  int
    web:    int
    db:     int
    ftp:    int


# ─── Global state ─────────────────────────────────────────────────────────────

last_config: dict = {
    "win10": 0, "linux": 0, "kali": 0,
    "wazuh": 0, "web":   0, "db":   0, "ftp": 0,
}

deployed_vmids: set[int] = set()

# Ansible pipeline state — read by /ansible/status
ansible_state: dict = {
    "phase":    "idle",      # idle | running | success | failed
    "progress": 0,
    "last_msg": "",
}


# ─── Dynamic inventory generator ──────────────────────────────────────────────

def generate_inventory(cfg: dict) -> str:
    """
    Builds an INI inventory that exactly mirrors the IP allocations
    in main.tf so it is always in sync with whatever Terraform deployed.

    IP scheme (from main.tf):
      wazuh-server-N  →  10.0.20.(10 + index)   VMIDs 900+
      web-server-N    →  10.0.20.(20 + index)   VMIDs 910+
      db-server-N     →  10.0.20.(30 + index)   VMIDs 920+
      ftp-server-N    →  10.0.20.(40 + index)   VMIDs 930+
      windows-N       →  10.0.20.(100 + index)  VMIDs 2000+
      linux-N         →  10.0.20.(200 + index)  VMIDs 1000+
    """
    lines: list[str] = []

    def section(group: str, hosts: list[tuple[str, str]]) -> None:
        lines.append(f"\n[{group}]")
        for name, ip in hosts:
            lines.append(f"{name} ansible_host={ip}")

    # Wazuh servers
    section("wazuh_servers", [
        (f"wazuh-server-{i+1}", f"10.0.20.{10+i}")
        for i in range(cfg.get("wazuh", 0))
    ])

    # Web servers
    section("web_servers", [
        (f"web-server-{i+1}", f"10.0.20.{20+i}")
        for i in range(cfg.get("web", 0))
    ])

    # DB servers
    section("db_servers", [
        (f"db-server-{i+1}", f"10.0.20.{30+i}")
        for i in range(cfg.get("db", 0))
    ])

    # FTP servers
    section("ftp_servers", [
        (f"ftp-server-{i+1}", f"10.0.20.{40+i}")
        for i in range(cfg.get("ftp", 0))
    ])

    # Linux clients
    section("linux_clients", [
        (f"linux-{i+1}", f"10.0.20.{200+i}")
        for i in range(cfg.get("linux", 0))
    ])

    # Windows clients
    section("windows_clients", [
        (f"windows-{i+1}", f"10.0.20.{100+i}")
        for i in range(cfg.get("win10", 0))
    ])

    # Group aliases
    lines.append("\n[servers:children]")
    lines.append("wazuh_servers")
    lines.append("web_servers")
    lines.append("db_servers")
    lines.append("ftp_servers")

    lines.append("\n[linux_targets:children]")
    lines.append("linux_clients")
    lines.append("servers")

    lines.append("\n[all_clients:children]")
    lines.append("linux_clients")
    lines.append("windows_clients")

    return "\n".join(lines) + "\n"


def write_dynamic_inventory(cfg: dict) -> None:
    inv_path = os.path.join(ANSIBLE_DIR, "inventory", "hosts.ini")
    os.makedirs(os.path.dirname(inv_path), exist_ok=True)
    content = generate_inventory(cfg)
    with open(inv_path, "w") as f:
        f.write(content)
    print(f"[INFO] Dynamic inventory written to {inv_path}")
    print(content)


# ─── Terraform state reader ────────────────────────────────────────────────────

def refresh_deployed_vmids() -> None:
    global deployed_vmids
    try:
        result = subprocess.run(
            ["terraform", "show", "-json"],
            cwd=TERRAFORM_DIR,
            capture_output=True,
            text=True,
            timeout=15,
        )
        if result.returncode != 0 or not result.stdout.strip():
            deployed_vmids = set()
            return

        state     = json.loads(result.stdout)
        resources = (
            (state.get("values") or {})
            .get("root_module", {})
            .get("resources", [])
        )
        vmids: set[int] = set()
        for res in resources:
            if res.get("type") not in (
                "proxmox_vm_qemu",
                "proxmox_virtual_environment_vm",
            ):
                continue
            attrs  = res.get("values", {})
            raw_id = attrs.get("vmid") or attrs.get("vm_id") or attrs.get("id")
            if raw_id is not None:
                try:
                    vmids.add(int(raw_id))
                except (ValueError, TypeError):
                    pass
        deployed_vmids = vmids
        print(f"[INFO] Deployed VMIDs: {deployed_vmids}")
    except Exception as e:
        print(f"[ERROR] refresh_deployed_vmids: {e}")


# ─── VM helpers ───────────────────────────────────────────────────────────────

def classify_vm(name: str) -> str:
    n = name.lower()
    if any(k in n for k in ("win", "windows", "w10", "win10")):
        return "windows"
    if "kali" in n:
        return "kali"
    if any(k in n for k in ("wazuh", "web", "db", "ftp", "server")):
        return "server"
    return "linux"


def is_routable_ipv4(ip: str) -> bool:
    if not ip:
        return False
    parts = ip.split(".")
    if len(parts) != 4:
        return False
    try:
        o = [int(p) for p in parts]
    except ValueError:
        return False
    if not all(0 <= x <= 255 for x in o):
        return False
    if o[0] == 0:                   return False
    if o[0] == 127:                 return False
    if o[0] == 169 and o[1] == 254: return False
    if o[0] >= 224:                 return False
    return True


def get_ip_for_vm(vmid: int) -> str:
    try:
        config    = proxmox.nodes(NODE).qemu(vmid).config.get()
        ipconfig0 = config.get("ipconfig0", "")
        if ipconfig0 and "ip=" in ipconfig0 and "dhcp" not in ipconfig0:
            m = re.search(r"ip=(\d+\.\d+\.\d+\.\d+)", ipconfig0)
            if m and is_routable_ipv4(m.group(1)):
                return m.group(1)
    except Exception as e:
        print(f"[WARN] vmid={vmid} config read failed: {e}")

    try:
        raw        = proxmox.nodes(NODE).qemu(vmid).agent("network-get-interfaces").get()
        iface_list = raw if isinstance(raw, list) else raw.get("result", [])
        for iface in iface_list:
            if iface.get("name", "") in ("lo", "lo0"):
                continue
            for addr in iface.get("ip-addresses", []):
                if addr.get("ip-address-type") != "ipv4":
                    continue
                candidate = addr.get("ip-address", "")
                if is_routable_ipv4(candidate):
                    return candidate
    except Exception as e:
        print(f"[WARN] vmid={vmid} agent read failed: {e}")

    return "BOOTING"


# ─── HTTP endpoints ────────────────────────────────────────────────────────────

@app.get("/")
def home():
    return FileResponse("../static/index.html")


@app.post("/deploy")
def deploy(data: Deploy):
    global last_config
    last_config = {
        "win10": data.win10, "linux": data.linux, "kali": data.kali,
        "wazuh": data.wazuh, "web":   data.web,   "db":   data.db,
        "ftp":   data.ftp,
    }
    return {"status": "started"}


@app.post("/destroy")
def destroy():
    subprocess.run(
        ["terraform", "init", "-input=false"],
        cwd=TERRAFORM_DIR, capture_output=True,
    )
    result = subprocess.run(
        [
            "terraform", "destroy", "-auto-approve",
            f"-var=win10_count={last_config['win10']}",
            f"-var=linux_count={last_config['linux']}",
            f"-var=kali_count={last_config['kali']}",
            f"-var=wazuh_count={last_config['wazuh']}",
            f"-var=web_count={last_config['web']}",
            f"-var=db_count={last_config['db']}",
            f"-var=ftp_count={last_config['ftp']}",
        ],
        cwd=TERRAFORM_DIR,
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        global deployed_vmids
        deployed_vmids = set()
    return {
        "status": "destroyed" if result.returncode == 0 else "failed",
        "stderr": result.stderr,
    }


@app.get("/status")
def get_status():
    px=get_proxmox()
    if not deployed_vmids:
        return []
    vms: list[dict] = []
    try:
        vm_list = px.nodes(NODE).qemu.get()
        for vm in vm_list:
            vmid   = int(vm["vmid"])
            name   = vm["name"]
            status = vm["status"]
            if vmid not in deployed_vmids:
                continue
            ip = get_ip_for_vm(vmid) if status == "running" else "STOPPED"
            vms.append({
                "name":   name,
                "ip":     ip,
                "status": status,
                "type":   classify_vm(name),
            })
    except Exception as e:
        print(f"[ERROR] Proxmox status fetch failed: {e}")
        return []
    return vms


@app.get("/ansible/status")
def get_ansible_status():
    """Returns the current Ansible pipeline state for polling."""
    return ansible_state


# ─── WebSocket — Terraform ────────────────────────────────────────────────────

@app.websocket("/ws")
async def websocket_terraform(ws: WebSocket):
    await ws.accept()

    try:
        data = await ws.receive_json()
    except (WebSocketDisconnect, Exception):
        return

    action = data.get("action")
    if action not in ("deploy", "destroy"):
        await ws.send_json({
            "log": f"[ERROR] Unknown action: '{action}'.",
            "progress": 0, "complete": True,
        })
        await ws.close()
        return

    env = {**os.environ, "PYTHONUNBUFFERED": "1"}
    loop = asyncio.get_running_loop()

    # ── Step 1: terraform init ─────────────────────────────────────────────
    await ws.send_json({"log": "▶ Running terraform init...", "progress": 3})

    init_proc = subprocess.Popen(
        ["terraform", "init", "-input=false"],
        cwd=TERRAFORM_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        env=env,
    )
    while True:
        line = await loop.run_in_executor(None, init_proc.stdout.readline)
        if line:
            line = line.strip()
            if line:
                try:
                    await ws.send_json({"log": line, "progress": 3})
                except (WebSocketDisconnect, Exception):
                    init_proc.kill()
                    return
        elif init_proc.poll() is not None:
            break
        else:
            await asyncio.sleep(0.1)

    init_proc.wait()

    if init_proc.returncode != 0:
        await ws.send_json({
            "log": "✘ terraform init failed — check output above.",
            "progress": 0, "complete": True,
        })
        await ws.close()
        return

    await ws.send_json({"log": "✔ terraform init complete.", "progress": 8})

    # ── Step 2: terraform apply / destroy ──────────────────────────────────
    tf_vars = [
        f"-var=win10_count={last_config['win10']}",
        f"-var=linux_count={last_config['linux']}",
        f"-var=kali_count={last_config['kali']}",
        f"-var=wazuh_count={last_config['wazuh']}",
        f"-var=web_count={last_config['web']}",
        f"-var=db_count={last_config['db']}",
        f"-var=ftp_count={last_config['ftp']}",
    ]

    cmd = (
        ["stdbuf", "-oL", "terraform", "apply",   "-auto-approve", "-parallelism=1", "-lock-timeout=120s"] + tf_vars
        if action == "deploy" else
        ["stdbuf", "-oL", "terraform", "destroy", "-auto-approve", "-parallelism=1", "-lock-timeout=120s"] + tf_vars
    )

    process = subprocess.Popen(
        cmd, cwd=TERRAFORM_DIR,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, bufsize=1, env=env,
    )

    progress = 0

    while True:
        line = await loop.run_in_executor(None, process.stdout.readline)
        if line:
            line = line.strip()
            if not line:
                continue
            if   "Initializing"    in line: progress = 10
            elif "Plan:"           in line: progress = 30
            elif "Creating"        in line or "Destroying"       in line: progress = 60
            elif "Still creating"  in line or "Still destroying" in line: progress = 80
            elif "Apply complete!" in line or "Destroy complete!" in line: progress = 100
            try:
                await ws.send_json({"log": line, "progress": progress})
            except (WebSocketDisconnect, Exception):
                process.kill()
                return
        elif process.poll() is not None:
            break
        else:
            await asyncio.sleep(0.1)

    process.wait()

    if process.returncode == 0:
        if action == "deploy":
            await loop.run_in_executor(None, refresh_deployed_vmids)
            # Write dynamic inventory from current config before Ansible starts
            await loop.run_in_executor(None, write_dynamic_inventory, last_config)
            # Signal frontend: Terraform done, Ansible queued — DO NOT send complete:True yet
            await ws.send_json({
                "log":           "Terraform complete. Waiting 60s for VMs to finish booting...",
                "progress": 100,
            })
            await asyncio.sleep(200)
            await ws.send_json({
                "log":           "✔ Terraform deployment complete. Starting Ansible configuration...",
                "progress":      100,
                "ansible_ready": True,   # ← frontend switches to Ansible panel on this flag
            })
        else:
            global deployed_vmids
            deployed_vmids = set()
            await ws.send_json({
                "log": "✔ Infrastructure destroyed successfully.",
                "progress": 100, "complete": True,
            })
    else:
        await ws.send_json({
            "log": "✘ Terraform failed — check output above.",
            "progress": 0, "complete": True,
        })

    try:
        await ws.close()
    except Exception:
        pass


# ─── WebSocket — Ansible ──────────────────────────────────────────────────────

@app.websocket("/ws/ansible")
async def websocket_ansible(ws: WebSocket):
    """
    Streams ansible-playbook site.yml output line-by-line.
    Called automatically by the frontend after Terraform signals ansible_ready.
    The inventory has already been written by the Terraform WS handler.
    """
    await ws.accept()
    global ansible_state

    ansible_state = {"phase": "running", "progress": 0, "last_msg": "Starting Ansible..."}

    env = {
        **os.environ,
        "PYTHONUNBUFFERED":   "1",
        "ANSIBLE_FORCE_COLOR": "0",           # no ANSI escape codes in log lines
        "ANSIBLE_HOST_KEY_CHECKING": "False",
    }

    cmd = [
        "stdbuf", "-oL",
        "ansible-playbook", "site.yml",
        "-i", "inventory/hosts.ini",
        "--ssh-extra-args", "-o StrictHostKeyChecking=no",
    ]

    process = subprocess.Popen(
        cmd, cwd=ANSIBLE_DIR,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, bufsize=1, env=env,
    )

    progress    = 0
    play_counts = {"ok": 0, "changed": 0, "failed": 0}
    loop        = asyncio.get_running_loop()

    while True:
        line = await loop.run_in_executor(None, process.stdout.readline)
        if line:
            line = line.rstrip()
            if not line:
                continue

            # ── Progress heuristics from ansible-playbook output ──────────
            l = line.lower()
            if "play ["        in l: progress = max(progress, 10)
            if "gathering facts" in l: progress = max(progress, 15)
            if "task ["        in l: progress = max(progress, 20)
            if "ok:"           in l: progress = min(progress + 2, 90)
            if "changed:"      in l: progress = min(progress + 3, 90)
            if "play recap"    in l: progress = 95

            # Track recap counts for final summary
            recap_match = re.search(
                r"ok=(\d+).*changed=(\d+).*failed=(\d+)", line
            )
            if recap_match:
                play_counts["ok"]      += int(recap_match.group(1))
                play_counts["changed"] += int(recap_match.group(2))
                play_counts["failed"]  += int(recap_match.group(3))

            ansible_state["progress"] = progress
            ansible_state["last_msg"] = line

            try:
                await ws.send_json({
                    "log":      line,
                    "progress": progress,
                    "counts":   play_counts,
                })
            except (WebSocketDisconnect, Exception):
                process.kill()
                ansible_state["phase"] = "failed"
                return
        elif process.poll() is not None:
            break
        else:
            await asyncio.sleep(0.1)

    process.wait()
    success = process.returncode == 0 and play_counts["failed"] == 0

    if success:
        ansible_state = {"phase": "success", "progress": 100, "last_msg": "Ansible complete"}
        final_msg = (
            f"✔ Ansible configuration complete — "
            f"{play_counts['ok']} ok, {play_counts['changed']} changed, "
            f"{play_counts['failed']} failed."
        )
    else:
        ansible_state = {"phase": "failed", "progress": progress, "last_msg": "Ansible failed"}
        final_msg = (
            f"✘ Ansible finished with errors — "
            f"{play_counts['ok']} ok, {play_counts['changed']} changed, "
            f"{play_counts['failed']} failed. Check output above."
        )

    try:
        await ws.send_json({
            "log":      final_msg,
            "progress": 100 if success else progress,
            "counts":   play_counts,
            "complete": True,
            "success":  success,
        })
    except Exception:
        pass

    try:
        await ws.close()
    except Exception:
        pass
