terraform{
	required_providers{
		proxmox ={
			source = "Telmate/proxmox"
			version = "3.0.2-rc03"
		}
	}
}

provider "proxmox"{
	pm_api_url = "https://50.50.50.81:8006/api2/json"
	pm_api_token_id = "root@pam!terraform"
	pm_api_token_secret = "f343097e-b863-49e8-a53e-607aaf367b4c"
	pm_tls_insecure = true
        pm_minimum_permission_check=false
}

resource "proxmox_vm_qemu" "vm2"{
	vmid=104
        name = "terraform-vm-2"
	target_node = "pve"

	clone = "Victim-Ubuntu-01"

	cores = 2
	memory = 1024
        
        boot="order=sata0"
        bootdisk="sata0"

        disk{
        slot="sata0"
        storage="localova"
        size="40G"
        type="disk" 
}     
	network{
	        id=0
	        model = "virtio"
		bridge = "vmbr0"
	}
}	
