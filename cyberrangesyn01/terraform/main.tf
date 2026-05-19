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
  pm_timeout                  = 1800
  pm_parallel                 = 1
}

locals {
  server_vlan = 20
  client_vlan = 20
  kali_vlan   = 30
}

# ─────────────────────────────────────────────────────────────────────────────
# WAZUH SERVERS — VLAN 20 — IPs starting 10.0.20.10
# wazuh-server-1 = 10.0.20.10, wazuh-server-2 = 10.0.20.11, etc.
# VMIDs starting at 900
# ─────────────────────────────────────────────────────────────────────────────

resource "proxmox_vm_qemu" "wazuh" {
  count = var.wazuh_count

  name        = "wazuh-server-${count.index + 1}"
  target_node = "pve"
  vmid        = 900 + count.index
  clone       = var.ubuntu_server_template
  full_clone  = true

  define_connection_info = false
  automatic_reboot       = true

  lifecycle {
    ignore_changes = [vm_state, disk]
  }

  cores    = 4
  memory   = 8192
  boot     = "order=scsi0"
  bootdisk = "scsi0"
  vm_state = "running"
  onboot   = true

  disk {
    slot     = "scsi0"
    storage  = "localova"
    size     = "32G"
    type     = "disk"
    iothread = true
    format   = "qcow2"
 }
 
  disk {
  slot="ide0"
  type="cloudinit"
  storage="localova"
}

  network {
    id     = 0
    model  = "e1000"
    bridge = "vmbr1"
    tag    = local.server_vlan
  }

  ipconfig0       = "ip=10.0.20.${10 + count.index}/24,gw=10.0.20.1"
  ciupgrade       = false
  ciuser          = "ansible"
  cipassword      = "abc@123"
  agent           = 1
  skip_ipv6       = true
  agent_timeout   = 120
  additional_wait = 15

  timeouts {
    create = "60m"
    update = "15m"
    delete = "10m"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# WEB SERVERS — VLAN 20 — IPs starting 10.0.20.20
# web-server-1 = 10.0.20.20, web-server-2 = 10.0.20.21, etc.
# VMIDs starting at 910
# ─────────────────────────────────────────────────────────────────────────────

resource "proxmox_vm_qemu" "web" {
  count = var.web_count

  name        = "web-server-${count.index + 1}"
  target_node = "pve"
  vmid        = 910 + count.index
  clone       = var.ubuntu_server_template
  full_clone  = true

  define_connection_info = false

  lifecycle {
    ignore_changes = [vm_state, disk]
  }

  cores    = 2
  memory   = 2048
  boot     = "order=scsi0"
  bootdisk = "scsi0"
  vm_state = "running"
  onboot   = true

  disk {
    slot     = "scsi0"
    storage  = "localova"
    size     = "32G"
    type     = "disk"
    iothread = true
    format   = "qcow2"
  }

disk{
  slot="ide0"
  storage="localova"
  type="cloudinit"
}
   
  network {
    id     = 0
    model  = "e1000"
    bridge = "vmbr1"
    tag    = local.server_vlan
  }

  ipconfig0       = "ip=10.0.20.${20 + count.index}/24,gw=10.0.20.1"
  ciuser          ="ansible"
  cipassword      ="abc@123"
  ciupgrade       = false
  agent           = 1
  skip_ipv6       = true
  agent_timeout   = 120
  additional_wait = 15

  timeouts {
    create = "60m"
    update = "15m"
    delete = "10m"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# DB SERVERS — VLAN 20 — IPs starting 10.0.20.30
# db-server-1 = 10.0.20.30, db-server-2 = 10.0.20.31, etc.
# VMIDs starting at 920
# ─────────────────────────────────────────────────────────────────────────────

resource "proxmox_vm_qemu" "db" {
  count = var.db_count

  name        = "db-server-${count.index + 1}"
  target_node = "pve"
  vmid        = 920 + count.index
  clone       = var.ubuntu_server_template
  full_clone  = true

  define_connection_info = false

  lifecycle {
    ignore_changes = [vm_state, disk]
  }

  cores    = 2
  memory   = 4096
  boot     = "order=scsi0"
  bootdisk = "scsi0"
  vm_state = "running"
  onboot   = true

  disk {
    slot     = "scsi0"
    storage  = "localova"
    size     = "32G"
    type     = "disk"
    iothread = true
    format   = "qcow2"
  }

 disk{
   slot="ide0"
   storage="localova"
   type="cloudinit"
}
  network {
    id     = 0
    model  = "e1000"
    bridge = "vmbr1"
    tag    = local.server_vlan
  }

  ipconfig0       = "ip=10.0.20.${30 + count.index}/24,gw=10.0.20.1"
  ciuser          ="ansible"
  cipassword      ="abc@123"
  ciupgrade       = false
  agent           = 1
  skip_ipv6       = true
  agent_timeout   = 120
  additional_wait = 15

  timeouts {
    create = "60m"
    update = "15m"
    delete = "10m"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# FTP SERVERS — VLAN 20 — IPs starting 10.0.20.40
# ftp-server-1 = 10.0.20.40, ftp-server-2 = 10.0.20.41, etc.
# VMIDs starting at 930
# ─────────────────────────────────────────────────────────────────────────────

resource "proxmox_vm_qemu" "ftp" {
  count = var.ftp_count

  name        = "ftp-server-${count.index + 1}"
  target_node = "pve"
  vmid        = 930 + count.index
  clone       = var.ubuntu_server_template
  full_clone  = true

  define_connection_info = false

  lifecycle {
    ignore_changes = [vm_state, disk]
  }

  cores    = 2
  memory   = 2048
  boot     = "order=scsi0"
  bootdisk = "scsi0"
  vm_state = "running"
  onboot   = true

  disk {
    slot     = "scsi0"
    storage  = "localova"
    size     = "32G"
    type     = "disk"
    iothread = true
    format   = "qcow2"
  }
  disk{
  slot="ide0"
  storage="localova"
  type="cloudinit"
}
  network {
    id     = 0
    model  = "e1000"
    bridge = "vmbr1"
    tag    = local.server_vlan
  }

  ipconfig0       = "ip=10.0.20.${40 + count.index}/24,gw=10.0.20.1"
  ciuser          ="ansible"
  cipassword      ="abc@123"
  ciupgrade       = false
  agent           = 1
  skip_ipv6       = true
  agent_timeout   = 120
  additional_wait = 15

  timeouts {
    create = "60m"
    update = "15m"
    delete = "10m"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# KALI — VLAN 30 (10.0.30.x) — VMIDs starting 3000
# ─────────────────────────────────────────────────────────────────────────────

resource "proxmox_vm_qemu" "kali" {
  count = var.kali_count

  name        = "kali-${count.index + 1}"
  target_node = "pve"
  vmid        = 3000 + count.index
  clone       = var.kali_template
  full_clone  = true

  define_connection_info = false

  lifecycle {
    ignore_changes = [vm_state, disk]
  }

  cores    = 2
  memory   = 4096
  boot     = "order=scsi0"
  bootdisk = "scsi0"
  vm_state = "running"
  onboot   = true

  disk {
    slot     = "scsi0"
    storage  = "localova"
    size     = "40G"
    type     = "disk"
    format   = "qcow2"
    iothread = true
  }
  disk{
  slot="ide2"
  type="cloudinit"
  storage="localova"
  } 
 
  network {
    id     = 0
    model  = "e1000"
    bridge = "vmbr1"
    tag    = local.kali_vlan
  }

  ipconfig0       = "ip=10.0.30.${100 + count.index}/24,gw=10.0.30.1"
  ciupgrade       = false
  ciuser          = "ansible"
  cipassword      = "abc@123"
  agent           = 1
  skip_ipv6       = true
  agent_timeout   = 60
  additional_wait = 15

  timeouts {
    create = "60m"
    update = "20m"
    delete = "10m"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# WINDOWS CLIENTS — VLAN 20 (10.0.20.1xx) — VMIDs starting 2000
# ─────────────────────────────────────────────────────────────────────────────

resource "proxmox_vm_qemu" "win10" {
  count = var.win10_count

  name        = "windows-${count.index + 1}"
  target_node = "pve"
  vmid        = 2000 + count.index
  clone       = var.win10_template
  full_clone  = true

  define_connection_info = false

  lifecycle {
    ignore_changes = [vm_state, disk]
  }

  cores    = 2
  memory   = 4096
  sockets  = 1
  balloon  = 0
  cpu_type = "host"
  scsihw   = "virtio-scsi-single"
  os_type  = "win10"

  agent           = 1
  skip_ipv6       = true
  vm_state        = "running"
  onboot          = true
  clone_wait      = 720
  additional_wait = 300

  timeouts {
    create = "60m"
    update = "60m"
    delete = "10m"
  }

  disk {
    slot    = "scsi0"
    storage = "localova"
    size    = "50G"
    type    = "disk"
    format  = "raw"
  }
 
 disk{
   slot="ide2"
   storage="localova"
   type="cloudinit"
}

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr1"
    tag    = local.client_vlan
  }

  ipconfig0  = "ip=10.0.20.${100 + count.index}/24,gw=10.0.20.1" 
  ciupgrade  = false
  ciuser     = "ansible"
  cipassword = "abc@123"
}

# ─────────────────────────────────────────────────────────────────────────────
# LINUX CLIENTS — VLAN 20 (10.0.20.2xx) — VMIDs starting 1000
# ─────────────────────────────────────────────────────────────────────────────

resource "proxmox_vm_qemu" "linux" {
  count = var.linux_count

  name        = "linux-${count.index + 1}"
  target_node = "pve"
  vmid        = 1000 + count.index
  clone       = var.linux_template
  full_clone  = true

  define_connection_info = false

  lifecycle {
    ignore_changes = [vm_state, disk]
  }

  cores    = 2
  memory   = 4096
  boot     = "order=scsi0"
  bootdisk = "scsi0"
  vm_state = "running"
  onboot   = true

  disk {
    slot     = "scsi0"
    storage  = "localova"
    size     = "50G"
    type     = "disk"
    iothread = true
  }
  disk{
  type="cloudinit"
  storage="localova"
  slot="ide1"
}  
  network {
    id     = 0
    model  = "e1000"
    bridge = "vmbr1"
    tag    = local.client_vlan
  }
  ciuser="ansible"
  cipassword="abc@123"
  ipconfig0       = "ip=10.0.20.${200 + count.index}/24,gw=10.0.20.1" 
  ciupgrade       = false
  agent           = 1
  skip_ipv6       = true
  agent_timeout   = 60
  additional_wait = 10

  timeouts {
    create = "60m"
    update = "15m"
    delete = "10m"
  }
}
