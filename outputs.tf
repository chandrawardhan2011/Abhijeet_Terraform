output "vm_info" {
   value={
      windows=[
        for idx, vm in proxmox_vm_qemu.win10 :
        { 
           name=vm.name != "" ? vm.name : "win10-${idx+1}"
           ip = vm.default_ipv4_address
        }
      ]
      linux=[
        for idx, vm in proxmox_vm_qemu.linux :
        {
            name=vm.name != "" ? vm.name : "linux-${idx+1}"
            ip = vm.default_ipv4_address
        }
      ]
      servers = [
      {   name="web"
          ip = proxmox_vm_qemu.web.default_ipv4_address
      },
      {   name="db"
          ip = proxmox_vm_qemu.db.default_ipv4_address
      },
      {   name="ftp"
          ip = proxmox_vm_qemu.ftp.default_ipv4_address
      },
      {   name="mail"
          ip=proxmox_vm_qemu.mail.default_ipv4_address
      },
      {   name="wazuh"
          ip=proxmox_vm_qemu.wazuh.default_ipv4_address
      }
    ]
 }
}             
