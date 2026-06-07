#!/bin/bash
# vuln: ftp_anonymous | severity: medium | label: LS06
echo "[VULN] Injecting FTP Anonymous Login vulnerability..."

# Enable anonymous login in vsftpd
cat > /etc/vsftpd.conf << 'VSFTPD'
anonymous_enable=YES
local_enable=YES
write_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
listen=NO
listen_ipv6=YES
pam_service_name=vsftpd
no_anon_password=YES
anon_other_write_enable=YES
allow_writeable_chroot=YES
VSFTPD

# Create FTP directory structure
# /srv/ftp must NOT be writable (vsftpd default chroot)
mkdir -p /srv/ftp
chmod 755 /srv/ftp           # NOT writable — vsftpd chroot requirement
chown root:root /srv/ftp

# Drop sensitive files directly in /srv/ftp (default anon root)
cat > /srv/ftp/credentials.txt << 'CREDS'
=== INTERNAL CREDENTIALS - DO NOT SHARE ===
Database Admin: admin / Admin@123
SSH Root:       root / toor
Application:    app_user / app_pass_2024
CREDS
chmod 644 /srv/ftp/credentials.txt

cat > /srv/ftp/network_diagram.txt << 'NET'
Internal Network Layout:
- 10.0.20.0/24 - Server Network
- 10.0.30.0/24 - Attacker Network
- Admin Panel: http://10.0.20.10:8080/admin
NET
chmod 644 /srv/ftp/network_diagram.txt

# Restart vsftpd
systemctl restart vsftpd 2>/dev/null || true
sleep 2

# Verify
if systemctl is-active vsftpd &>/dev/null; then
    echo "[VULN] FTP Anonymous Login injected — vsftpd running"
    echo "[INFO] Connect: ftp 10.0.20.40"
    echo "[INFO]   user: anonymous"
    echo "[INFO]   pass: (blank)"
    echo "[INFO] Files: credentials.txt, network_diagram.txt"
else
    echo "[ERROR] vsftpd failed to start"
    journalctl -u vsftpd --no-pager -n 10
fi
