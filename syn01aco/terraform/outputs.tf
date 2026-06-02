output "vm_info" {
  value = {
    windows = [for idx, vm in proxmox_vm_qemu.win10  : { name = vm.name, ip = vm.default_ipv4_address }]
    linux   = [for idx, vm in proxmox_vm_qemu.linux  : { name = vm.name, ip = vm.default_ipv4_address }]
    kali    = [for idx, vm in proxmox_vm_qemu.kali   : { name = vm.name, ip = vm.default_ipv4_address }]
    wazuh   = [for idx, vm in proxmox_vm_qemu.wazuh  : { name = vm.name, ip = vm.default_ipv4_address }]
    web     = [for idx, vm in proxmox_vm_qemu.web    : { name = vm.name, ip = vm.default_ipv4_address }]
    db      = [for idx, vm in proxmox_vm_qemu.db     : { name = vm.name, ip = vm.default_ipv4_address }]
    ftp     = [for idx, vm in proxmox_vm_qemu.ftp    : { name = vm.name, ip = vm.default_ipv4_address }]
  }
}
