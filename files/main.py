from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from proxmoxer import ProxmoxAPI
import subprocess
import os
import asyncio

app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")

PROXMOX_HOST = "50.50.50.81"
USER = "root@pam"
PASSWORD = "Admin@12345"
NODE = "pve"

proxmox = ProxmoxAPI(PROXMOX_HOST, user=USER, password=PASSWORD, verify_ssl=False)


class Deploy(BaseModel):
    win10: int
    linux: int


@app.get("/")
def home():
    return FileResponse("index.html")


# Global config — written by /deploy, read by /ws
last_config = {"win10": 0, "linux": 0}


@app.post("/deploy")
def deploy(data: Deploy):
    global last_config
    last_config = {"win10": data.win10, "linux": data.linux}
    return {"status": "started"}


# NOTE: This HTTP /destroy is a fallback only.
# The primary destroy path is the WebSocket, which streams logs live.
# Do NOT call both — they will both run terraform destroy and cause a state conflict.
@app.post("/destroy")
def destroy():
    result = subprocess.run(
        [
            "terraform", "destroy", "-auto-approve",
            f"-var=win10_count={last_config['win10']}",
            f"-var=linux_count={last_config['linux']}",
        ],
        cwd="../terraform",
        capture_output=True,
        text=True,
    )
    return {
        "status": "destroyed" if result.returncode == 0 else "failed",
        "stderr": result.stderr,
    }


@app.get("/status")
def get_status():
    vms = []
    try:
        vm_list = proxmox.nodes(NODE).qemu.get()
        for vm in vm_list:
            vmid   = vm["vmid"]
            name   = vm["name"]
            status = vm["status"]
            ip     = "N/A"
            try:
                interfaces = proxmox.nodes(NODE).qemu(vmid).agent("network-get-interface").get()
                for iface in interfaces["result"]:
                    for addr in iface.get("ip-addresses", []):
                        if (
                            addr["ip-address-type"] == "ipv4"
                            and addr["ip-address"] != "127.0.0.1"
                        ):
                            ip = addr["ip-address"]
                            break           # stop at first valid IPv4 per interface
                    if ip != "N/A":
                        break               # stop searching further interfaces
            except Exception:
                ip = "NO-Agent"
            vms.append({"name": name, "ip": ip, "status": status})
    except Exception as e:
        print(f"[ERROR] Proxmox status fetch failed: {e}")
        return []                           # always return a list so frontend .forEach() works
    return vms


@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await ws.accept()

    try:
        data = await ws.receive_json()
    except (WebSocketDisconnect, Exception):
        return                              # client disconnected before sending action

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

    if action == "deploy":
        cmd = [
            "stdbuf", "-oL",
            "terraform", "apply", "-auto-approve", "-parallelism=1",
            f"-var=win10_count={last_config['win10']}",
            f"-var=linux_count={last_config['linux']}",
        ]
    else:
        cmd = [
            "stdbuf", "-oL",
            "terraform", "destroy", "-auto-approve", "-parallelism=1",
            f"-var=win10_count={last_config['win10']}",
            f"-var=linux_count={last_config['linux']}",
        ]

    process = subprocess.Popen(
        cmd,
        cwd="../terraform",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        env=env,
    )

    progress = 0
    loop = asyncio.get_event_loop()

    while True:
        # readline() is blocking — run in executor so the event loop stays free
        line = await loop.run_in_executor(None, process.stdout.readline)

        if line:
            line = line.strip()
            if not line:
                continue                   # skip blank lines

            if "Initializing" in line:
                progress = 10
            elif "Plan:" in line:
                progress = 30
            elif "Creating" in line or "Destroying" in line:
                progress = 60
            elif "Still creating" in line or "Still destroying" in line:
                progress = 80
            elif "Apply complete!" in line or "Destroy complete!" in line:
                progress = 100

            try:
                await ws.send_json({"log": line, "progress": progress})
            except (WebSocketDisconnect, Exception):
                process.kill()             # don't leak the subprocess if client disconnects
                return

        elif process.poll() is not None:
            break
        else:
            await asyncio.sleep(0.1)

    process.wait()

    if process.returncode == 0:
        msg = (
            "Deployment Completed Successfully!"
            if action == "deploy"
            else "Infrastructure Destroyed Successfully!"
        )
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
