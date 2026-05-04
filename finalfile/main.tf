terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc03"
    }
  }
}

provider "proxmox" {
  pm_api_url                  = "https://50.50.50.81:8006/api2/json"
  pm_api_token_id             = "root@pam!terraform"
  pm_api_token_secret         = "f343097e-b863-49e8-a53e-607aaf367b4c"
  pm_tls_insecure             = true
  pm_minimum_permission_check = false
}

locals {
  server_vlan = 30
  client_vlan = 40
}

#################################
# SERVERS (UBUNTU SERVER TEMPLATE)
#################################

resource "proxmox_vm_qemu" "wazuh" {
  name        = "wazuh-server"
  target_node = "pve"
  vmid        = 900
  clone       = var.ubuntu_server_template
  full_clone  = true

  cores    = 4
  memory   = 8192
  boot     = "order=scsi0"
  bootdisk = "scsi0"

  # vm_state = "running" — tells Proxmox to power on the VM immediately
  # after creation. oncreate_set_status was removed in Telmate v3.x; using
  # it silently does nothing, leaving the VM powered off → agent never
  # starts → IP resolution always fails.
  vm_state = "running"

  # onboot = true — VM autostarts if the Proxmox host reboots.
  # Without this, VMs remain off after a host restart and agent is
  # unreachable until manual intervention.
  onboot = true

  disk {
    slot    = "scsi0"
    storage = "localova"
    size    = "32G"
    type    = "disk"
  }

  network {
    id     = 0
    model  = "e1000"
    bridge = "vmbr0"
    tag    = local.server_vlan
  }

  ipconfig0 = "ip=10.0.30.10/24,gw=10.0.30.1"

  agent      = 1
  # skip_ipv6 = true — restricts the guest agent to only report IPv4.
  # Without this, Proxmox waits for both IPv4 and IPv6; during boot
  # the agent reports the IPv6 link-local fe80:: address (available
  # instantly on any NIC) before the IPv4 is assigned, and that
  # address is handed back as the VM's IP.
  skip_ipv6  = true
  agent_wait = 60
}

resource "proxmox_vm_qemu" "web" {
  name        = "web-server"
  target_node = "pve"
  vmid        = 901
  clone       = var.ubuntu_server_template
  full_clone  = true

  cores    = 2
  memory   = 2048
  boot     = "order=scsi0"
  bootdisk = "scsi0"
  vm_state = "running"
  onboot   = true

  disk {
    slot    = "scsi0"
    storage = "localova"
    size    = "32G"
    type    = "disk"
  }

  network {
    id     = 0
    model  = "e1000"
    bridge = "vmbr0"
    tag    = local.server_vlan
  }

  ipconfig0  = "ip=10.0.30.20/24,gw=10.0.30.1"
  agent      = 1
  skip_ipv6  = true
  agent_wait = 60
}

resource "proxmox_vm_qemu" "db" {
  name        = "db-server"
  target_node = "pve"
  vmid        = 902
  clone       = var.ubuntu_server_template
  full_clone  = true

  cores    = 2
  memory   = 4096
  boot     = "order=scsi0"
  bootdisk = "scsi0"
  vm_state = "running"
  onboot   = true

  disk {
    slot    = "scsi0"
    storage = "localova"
    size    = "32G"
    type    = "disk"
  }

  network {
    id     = 0
    model  = "e1000"
    bridge = "vmbr0"
    tag    = local.server_vlan
  }

  ipconfig0  = "ip=10.0.30.21/24,gw=10.0.30.1"
  agent      = 1
  skip_ipv6  = true
  agent_wait = 60
}

resource "proxmox_vm_qemu" "ftp" {
  name        = "ftp-server"
  target_node = "pve"
  vmid        = 903
  clone       = var.ubuntu_server_template
  full_clone  = true

  cores    = 2
  memory   = 2048
  boot     = "order=scsi0"
  bootdisk = "scsi0"
  vm_state = "running"
  onboot   = true

  disk {
    slot    = "scsi0"
    storage = "localova"
    size    = "32G"
    type    = "disk"
  }

  network {
    id     = 0
    model  = "e1000"
    bridge = "vmbr0"
    tag    = local.server_vlan
  }

  ipconfig0  = "ip=10.0.30.22/24,gw=10.0.30.1"
  agent      = 1
  skip_ipv6  = true
  agent_wait = 60
}

resource "proxmox_vm_qemu" "mail" {
  name        = "mail-server"
  target_node = "pve"
  vmid        = 904
  clone       = var.ubuntu_server_template
  full_clone  = true

  cores    = 2
  memory   = 2048
  boot     = "order=scsi0"
  bootdisk = "scsi0"
  vm_state = "running"
  onboot   = true

  disk {
    slot    = "scsi0"
    storage = "localova"
    size    = "32G"
    type    = "disk"
  }

  network {
    id     = 0
    model  = "e1000"
    bridge = "vmbr0"
    tag    = local.server_vlan
  }

  ipconfig0  = "ip=10.0.30.23/24,gw=10.0.30.1"
  agent      = 1
  skip_ipv6  = true
  agent_wait = 60
}

#################################
# CLIENTS
#################################

# Windows 10
resource "proxmox_vm_qemu" "win10" {
  count = var.win10_count

  name        = "win10-${count.index + 1}"
  target_node = "pve"
  vmid        = 950 + count.index
  clone       = var.win10_template
  full_clone  = true

  cores    = 2
  memory   = 8048
  boot     = "order=sata0"
  bootdisk = "sata0"
  vm_state = "running"
  onboot   = true

  disk {
    slot    = "sata0"
    storage = "localova"
    size    = "50G"
    type    = "disk"
  }

  network {
    id     = 0
    model  = "e1000"
    bridge = "vmbr0"
    tag    = local.client_vlan
  }

  ipconfig0 = "ip=10.0.40.${100 + count.index}/24,gw=10.0.40.1"
  agent     = 1
  skip_ipv6 = true
  # Windows boots significantly slower than Linux — 90s agent_wait gives
  # the OS time to fully initialise before Terraform considers apply done.
  # main.py Strategy 1 reads the static IP from ipconfig0 immediately so
  # the dashboard shows the correct IP even before the agent is ready.
  agent_wait = 120
}

# Linux Clients
resource "proxmox_vm_qemu" "linux" {
  count = var.linux_count

  name        = "linux-${count.index + 1}"
  target_node = "pve"
  vmid        = 1000 + count.index
  clone       = var.linux_template
  full_clone  = true

  cores    = 2
  memory   = 4096
  boot     = "order=scsi0"
  bootdisk = "scsi0"
  vm_state = "running"
  onboot   = true

  disk {
    slot    = "scsi0"
    storage = "localova"
    size    = "50G"
    type    = "disk"
  }

  network {
    id     = 0
    model  = "e1000"
    bridge = "vmbr0"
    tag    = local.client_vlan
  }

  ipconfig0  = "ip=10.0.40.${200 + count.index}/24,gw=10.0.40.1"
  agent      = 1
  skip_ipv6  = true
  agent_wait = 60
}
