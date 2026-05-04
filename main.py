from fastapi import FastAPI, WebSocket
from fastapi.responses import FileResponse
from pydantic import BaseModel
import subprocess, json
import os
import asyncio
import select
import time
from fastapi.staticfiles import StaticFiles
from proxmoxer import ProxmoxAPI
app = FastAPI()
app.mount("/static",StaticFiles(directory="static"),name="static")
PROXMOX_HOST="50.50.50.81"
USER="root@pam"
PASSWORD="Admin@12345"
NODE="pve"
proxmox=ProxmoxAPI(PROXMOX_HOST, user=USER, password=PASSWORD, verify_ssl=False)
class Deploy(BaseModel):
    win10: int
    linux: int
@app.get("/")
def home():
    return FileResponse("index.html")

# Store last values for destroy
last_config = {"win10": 0, "linux": 0}

@app.post("/deploy")
def deploy(data: Deploy):
    global last_config
    last_config = {"win10": data.win10, "linux": data.linux}
    return {"status": "started"}

@app.post("/destroy")
def destroy():
    subprocess.run([
        "terraform", "destroy", "-auto-approve",
        f"-var=win10_count={last_config['win10']}",
        f"-var=linux_count={last_config['linux']}"
    ], cwd="../terraform")
    return {"status": "destroyed"}
@app.get("/status")
def get_status():
     vms=[]
     vm_list=proxmox.nodes(NODE).qemu.get()
     for vm in vm_list:
        vmid=vm["vmid"]
        name=vm["name"]
        status=vm["status"]
        ip="N/A"
        try:
            interfaces = proxmox.nodes(NODE).qemu(vmid).agent("network-get-interface").get()
            for iface in interfaces["result"]:
                for addr in iface.get("ip-addresses",[]):
                    if addr["ip-address-type"]=="ipv4" and addr["ip-address"]!="127.0.0.1":
                            ip=addr["ip-address"]
        except:
            ip="NO-Agent"
        vms.append({
             "name" : name,
             "ip" : ip,
             "status" : status
        })
     return vms

@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await ws.accept()
    env = {
        **os.environ,
        "PYTHONUNBUFFERED": "1"
    }
    data = await ws.receive_json()
    action = data.get("action")
    if action == "deploy":
       cmd = [
             "stdbuf","-oL",
             "terraform", "apply", "-auto-approve", "-parallelism=1",
             f"-var=win10_count={last_config['win10']}",
             f"-var=linux_count={last_config['linux']}"
       ]
    else:
       cmd = [
             "stdbuf","-oL",
             "terraform","destroy","-auto-approve", "-parallelism=1",
             f"-var=win10_count={last_config['win10']}",
             f"-var=linux_count={last_config['linux']}"
       ]
    process = subprocess.Popen(
        cmd,
        cwd="../terraform",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        env=env
    )

    progress = 0

    while True:
      line=process.stdout.readline()
      if line:
        line = line.strip()

        if "Initializing" in line:
            progress = 10
        elif "Plan:" in line:
            progress = 30
        elif "Creating" in line:
            progress = 60
        elif "Still creating" in line:
            progress = 80
        elif "Apply complete!" in line:
            progress = 100
        try:
           await ws.send_json({
            "log": line,
            "progress": progress
           })
        except:
          break

        await asyncio.sleep(0.01)

      elif process.poll() is not None:
        break
      else:
        time.sleep(0.1)
    
    process.wait()

    if process.returncode == 0:
       if action == "deploy":
          msg="Deployment Completed Successfully!!"
       else:
          msg="Infrastructure Destroyed Successfully!!"
    else:
       msg="Terraform Failed"
       final_progress=0
    try:
       await ws.send_json({
          "log": msg,
          "progress":final_progress,
          "complete": True
       })
    except:
       pass
 
    try:
       await ws.close()
    except:
       pass
