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
app.mount("/static", StaticFiles(directory="static"), name="static")

PROXMOX_HOST  = "50.50.50.81"
USER          = "root@pam"
PASSWORD      = "Admin@12345"
NODE          = "pve"
TERRAFORM_DIR = "../terraform"

proxmox = ProxmoxAPI(PROXMOX_HOST, user=USER, password=PASSWORD, verify_ssl=False)


class Deploy(BaseModel):
    win10: int
    linux: int


@app.get("/")
def home():
    return FileResponse("index.html")


# ─── Global state ─────────────────────────────────────────────────────────────

last_config: dict = {"win10": 0, "linux": 0}

# VMIDs owned by the current Terraform deployment.
# Empty  → /status returns []  → table and counters show zero.
# Populated by refresh_deployed_vmids() after a successful apply.
deployed_vmids: set[int] = set()


# ─── Terraform state reader ────────────────────────────────────────────────────

def refresh_deployed_vmids() -> None:
    """
    Runs `terraform show -json` and extracts every Proxmox QEMU VMID
    currently tracked in the state file.

    Supports both common Telmate provider resource types:
      proxmox_vm_qemu                  (telmate/proxmox — this project)
      proxmox_virtual_environment_vm   (bpg/proxmox — alternate)

    VMID attribute names per provider:
      telmate → "vmid"
      bpg     → "vm_id" or "id"
    """
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

        state = json.loads(result.stdout)
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
        print(f"[INFO] Deployed VMIDs from Terraform state: {deployed_vmids}")

    except Exception as e:
        print(f"[ERROR] refresh_deployed_vmids failed: {e}")
        # Keep existing set on transient error — don't wipe a valid deployment


# ─── VM type classifier ────────────────────────────────────────────────────────

def classify_vm(name: str) -> str:
    """
    Returns 'windows' or 'linux' based on the VM name assigned by Terraform.
    Your main.tf names them:  win10-N  and  linux-N
    Server VMs (wazuh, web, db, ftp, mail) fall through to 'linux' since
    they are all Ubuntu-based.
    Adjust keywords here if your naming convention changes.
    """
    n = name.lower()
    if any(k in n for k in ("win", "windows", "w10", "win10")):
        return "windows"
    return "linux"


# ─── IP validation ────────────────────────────────────────────────────────────

def is_routable_ipv4(ip: str) -> bool:
    """
    Returns True only for genuine routable unicast IPv4 addresses.
    Rejects non-routable addresses that appear during boot or from a
    misconfigured agent:

      0.0.0.0       — unassigned
      127.x.x.x     — loopback
      169.254.x.x   — APIPA / link-local  ← main culprit on Windows VMs;
                      Windows assigns this when NIC comes up before static
                      IP is applied; old filter `!= "127.0.0.1"` let it through
      224.x+        — multicast / reserved
    """
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
    if o[0] == 0:                        return False  # unassigned
    if o[0] == 127:                      return False  # loopback
    if o[0] == 169 and o[1] == 254:      return False  # APIPA / link-local
    if o[0] >= 224:                      return False  # multicast + reserved
    return True


# ─── IP resolution (3-strategy) ───────────────────────────────────────────────

def get_ip_for_vm(vmid: int) -> str:
    """
    Strategy 1 — Proxmox VM config (ipconfig0)
        Reads the static IP assigned via `ipconfig0` in main.tf directly
        from the Proxmox config API.  Instant, zero guest-agent dependency,
        works even while the OS is still booting.  Covers all VMs in this
        project since every resource has a static ipconfig0.

    Strategy 2 — QEMU guest agent network-get-interfaces
        Fallback for DHCP VMs that have no static ipconfig0.
        Correctly handles both proxmoxer response shapes:
          • list directly   (proxmoxer auto-unwraps Proxmox's {"result":[]} envelope)
          • dict with key   (older proxmoxer versions that don't unwrap)
        Uses is_routable_ipv4() to reject APIPA/link-local addresses.

    Strategy 3 — "BOOTING"
        Neither strategy returned a routable IP — VM is still initialising.
        Frontend shows "BOOTING" so the operator knows to wait, not panic.
    """

    # ── Strategy 1: static IP from Proxmox config ─────────────────────────
    try:
        config    = proxmox.nodes(NODE).qemu(vmid).config.get()
        ipconfig0 = config.get("ipconfig0", "")
        # Format: "ip=10.0.30.10/24,gw=10.0.30.1"  — skip if DHCP or absent
        if ipconfig0 and "ip=" in ipconfig0 and "dhcp" not in ipconfig0:
            m = re.search(r"ip=(\d+\.\d+\.\d+\.\d+)", ipconfig0)
            if m and is_routable_ipv4(m.group(1)):
                return m.group(1)
    except Exception as e:
        print(f"[WARN] vmid={vmid} config read failed: {e}")

    # ── Strategy 2: QEMU guest agent ──────────────────────────────────────
    try:
        raw        = proxmox.nodes(NODE).qemu(vmid).agent("network-get-interfaces").get()
        iface_list = raw if isinstance(raw, list) else raw.get("result", [])

        for iface in iface_list:
            if iface.get("name", "") in ("lo", "lo0"):
                continue                    # skip loopback interface
            for addr in iface.get("ip-addresses", []):
                if addr.get("ip-address-type") != "ipv4":
                    continue
                candidate = addr.get("ip-address", "")
                if is_routable_ipv4(candidate):
                    return candidate
    except Exception as e:
        print(f"[WARN] vmid={vmid} agent read failed: {e}")

    # ── Strategy 3: still booting ─────────────────────────────────────────
    return "BOOTING"


# ─── Endpoints ────────────────────────────────────────────────────────────────

@app.post("/deploy")
def deploy(data: Deploy):
    global last_config
    last_config = {"win10": data.win10, "linux": data.linux}
    return {"status": "started"}


@app.post("/destroy")
def destroy():
    """
    HTTP fallback only — the WebSocket path is preferred (streams logs live).
    Do NOT call this AND the WS destroy for the same operation — both run
    terraform destroy and will cause a Terraform state conflict.
    """
    result = subprocess.run(
        [
            "terraform", "destroy", "-auto-approve",
            f"-var=win10_count={last_config['win10']}",
            f"-var=linux_count={last_config['linux']}",
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
    """
    Returns only the VMs that belong to the current Terraform deployment
    (filtered by deployed_vmids read from terraform state after apply).

    Each entry includes:
      name   — VM hostname
      ip     — routable IPv4, "BOOTING", or "STOPPED"
      status — Proxmox power state ("running" / "stopped" / "paused")
      type   — "windows" or "linux" (derived from VM name)

    The 'type' field lets the frontend split WIN / LNX counters correctly
    from the API response instead of relying on the user's input fields.
    """
    if not deployed_vmids:
        return []           # nothing deployed — table and counters stay at zero

    vms: list[dict] = []
    try:
        vm_list = proxmox.nodes(NODE).qemu.get()
        for vm in vm_list:
            vmid   = int(vm["vmid"])
            name   = vm["name"]
            status = vm["status"]

            # Only show VMs owned by Terraform state
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


# ─── WebSocket ────────────────────────────────────────────────────────────────

@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await ws.accept()

    try:
        data = await ws.receive_json()
    except (WebSocketDisconnect, Exception):
        return                          # client disconnected before sending action

    action = data.get("action")

    if action not in ("deploy", "destroy"):
        await ws.send_json({
            "log": f"[ERROR] Unknown action: '{action}'. Must be 'deploy' or 'destroy'.",
            "progress": 0,
            "complete": True,
        })
        await ws.close()
        return

    env = {**os.environ, "PYTHONUNBUFFERED": "1"}

    cmd = (
        [
            "stdbuf", "-oL",
            "terraform", "apply", "-auto-approve", "-parallelism=1",
            f"-var=win10_count={last_config['win10']}",
            f"-var=linux_count={last_config['linux']}",
        ]
        if action == "deploy" else
        [
            "stdbuf", "-oL",
            "terraform", "destroy", "-auto-approve", "-parallelism=1",
            f"-var=win10_count={last_config['win10']}",
            f"-var=linux_count={last_config['linux']}",
        ]
    )

    process = subprocess.Popen(
        cmd,
        cwd=TERRAFORM_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        env=env,
    )

    progress = 0
    # Use get_running_loop() — get_event_loop() is deprecated in Python 3.10+
    loop = asyncio.get_running_loop()

    while True:
        # readline() blocks — run in thread executor so event loop stays free
        line = await loop.run_in_executor(None, process.stdout.readline)

        if line:
            line = line.strip()
            if not line:
                continue                # skip blank lines — don't send noise

            if   "Initializing"    in line: progress = 10
            elif "Plan:"           in line: progress = 30
            elif "Creating"        in line or "Destroying"       in line: progress = 60
            elif "Still creating"  in line or "Still destroying" in line: progress = 80
            elif "Apply complete!" in line or "Destroy complete!" in line: progress = 100

            try:
                await ws.send_json({"log": line, "progress": progress})
            except (WebSocketDisconnect, Exception):
                process.kill()          # don't leak subprocess on client disconnect
                return

        elif process.poll() is not None:
            break
        else:
            await asyncio.sleep(0.1)

    process.wait()

    if process.returncode == 0:
        if action == "deploy":
            msg = "Deployment Completed Successfully!"
            # Populate deployed_vmids from fresh state so /status filters correctly
            await loop.run_in_executor(None, refresh_deployed_vmids)
        else:
            msg = "Infrastructure Destroyed Successfully!"
            global deployed_vmids
            deployed_vmids = set()      # clear — nothing is deployed anymore
        final_progress = 100
    else:
        msg = "Terraform Failed — check terminal output above."
        final_progress = 0

    try:
        await ws.send_json({"log": msg, "progress": final_progress, "complete": True})
    except Exception:
        pass

    try:
        await ws.close()
    except Exception:
        pass
