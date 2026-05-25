## Pre-requisite: Upload cloud-init snippet to Proxmox

Before running Terraform, copy the cloud-init snippet to your Proxmox host:

```bash
scp terraform/disable-unattended-upgrades.yml root@<proxmox-ip>:/var/lib/vz/snippets/
```

This snippet disables unattended-upgrades on VM boot so Ansible never hits an apt lock.
