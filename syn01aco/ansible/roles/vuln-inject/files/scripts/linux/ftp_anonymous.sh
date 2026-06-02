#!/bin/bash
# vuln: ftp_anonymous_login
# Enables anonymous FTP login and places sensitive files in the FTP root

set -e
echo "[VULN] Injecting FTP Anonymous Login vulnerability..."

# Enable anonymous login in vsftpd
cat > /etc/vsftpd.conf << 'EOF'
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
anon_root=/var/ftp/pub
no_anon_password=YES
anon_other_write_enable=YES
EOF

# Create FTP public directory with sensitive files
mkdir -p /var/ftp/pub
chmod 777 /var/ftp/pub

# Drop "sensitive" files
cat > /var/ftp/pub/credentials.txt << 'EOF'
=== INTERNAL CREDENTIALS - DO NOT SHARE ===
Database Admin: admin / Admin@123
SSH Root: root / toor
Application: app_user / app_pass_2024
EOF
chmod 644 /var/ftp/pub/credentials.txt

cat > /var/ftp/pub/network_diagram.txt << 'EOF'
Internal Network Layout:
- 10.0.20.0/24 - Server Network
- 10.0.30.0/24 - Attacker Network  
- Admin Panel: http://10.0.20.10:8080/admin
EOF
chmod 644 /var/ftp/pub/network_diagram.txt

# Restart vsftpd
systemctl restart vsftpd

echo "[VULN] FTP Anonymous Login vulnerability injected."
echo "[INFO] Connect: ftp <IP> -> username: anonymous, password: (blank)"
echo "[INFO] Sensitive files available at /var/ftp/pub/"
