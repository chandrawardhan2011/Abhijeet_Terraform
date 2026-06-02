#!/bin/bash
# vuln: world_writable_directories | severity: medium
echo "[VULN] Injecting World-Writable Directories..."
mkdir -p /opt/shared /srv/data /var/app
chmod 777 /opt/shared /srv/data /var/app
cat > /opt/shared/internal_notes.txt << 'EOFTXT'
INTERNAL NOTES
Server admin password: Admin@123
Backup location: /srv/backup
VPN credentials: vpn_user/VPN@2024
EOFTXT
chmod 777 /opt/shared/internal_notes.txt
chmod 777 /tmp
echo "[VULN] World-writable directories created with sensitive data."
