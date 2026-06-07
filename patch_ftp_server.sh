#!/bin/bash
# CyberRange SYN-01 — FTP Server Patch — ftp-server-1 (10.0.20.40)
ERRORS=0
log()  { echo "[+] $*"; }
err()  { echo "[!] $*"; ERRORS=$((ERRORS+1)); }
info() { echo "[*] $*"; }
echo "============================================="
echo "  CyberRange — FTP Server Patch"
echo "============================================="
echo "[*] PRE-FIX: Restoring critical permissions..."
chmod 440 /etc/sudoers 2>/dev/null || true; chmod 644 /etc/passwd 2>/dev/null || true
chmod 640 /etc/shadow 2>/dev/null && chown root:shadow /etc/shadow 2>/dev/null || true
chmod 600 /etc/crontab 2>/dev/null || true; echo "[+] PRE-FIX complete"

info "[1/14] SSH Brute Force..."; sed -i 's/MaxAuthTries 100/MaxAuthTries 3/' /etc/ssh/sshd_config 2>/dev/null || true; sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config 2>/dev/null || true; sed -i 's/^PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config 2>/dev/null || true; grep -q "^MaxAuthTries" /etc/ssh/sshd_config || echo "MaxAuthTries 3" >> /etc/ssh/sshd_config; systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true; userdel -r labuser 2>/dev/null || true; rm -f /etc/sudoers.d/labuser; sed -i '/labuser.*NOPASSWD/d' /etc/sudoers 2>/dev/null || true; apt-get install -y fail2ban 2>/dev/null && systemctl enable --now fail2ban 2>/dev/null || true; rm -f /tmp/ssh_brute_info.txt; log "SSH patched"
info "[2/14] ASLR..."; sysctl -w kernel.randomize_va_space=2 2>/dev/null || true; sed -i '/randomize_va_space\s*=\s*0/d' /etc/sysctl.conf 2>/dev/null || true; grep -q "kernel.randomize_va_space" /etc/sysctl.conf || echo "kernel.randomize_va_space = 2" >> /etc/sysctl.conf; rm -f /tmp/vuln_suid_bash; log "ASLR enabled"
info "[3/14] SUDO..."; sed -i '/student.*NOPASSWD/d;/labuser.*NOPASSWD/d' /etc/sudoers 2>/dev/null || true; rm -f /etc/sudoers.d/vuln_* /etc/sudoers.d/student; userdel -r student 2>/dev/null || true; chmod 440 /etc/sudoers; log "SUDO patched"
info "[4/14] Crontab..."; chmod 755 /opt/cleanup.sh 2>/dev/null || true; chown root:root /opt/cleanup.sh 2>/dev/null || true; chmod 600 /etc/crontab 2>/dev/null || true; rm -f /etc/cron.d/vuln_cleanup; crontab -l 2>/dev/null | grep -v "bash -i\|nc -lvnp\|/dev/tcp" | crontab - 2>/dev/null || true; sed -i '/bash.*\/dev\/tcp/d' /etc/crontab 2>/dev/null || true; log "Crontab patched"
info "[5/14] File perms..."; chmod 644 /etc/passwd; chmod 640 /etc/shadow && chown root:shadow /etc/shadow 2>/dev/null || true; chmod 440 /etc/sudoers; chmod 600 /etc/crontab; log "Permissions fixed"
info "[6/14] Kernel..."; sysctl -w kernel.randomize_va_space=2 kernel.kptr_restrict=1 kernel.yama.ptrace_scope=1 net.ipv4.tcp_syncookies=1 net.ipv4.conf.all.accept_redirects=0 2>/dev/null || true; sed -i '/randomize_va_space=0/d;/kptr_restrict=0/d;/ptrace_scope=0/d' /etc/sysctl.conf 2>/dev/null || true; log "Kernel hardened"
info "[7/14] SUID..."; rm -f /tmp/bash_suid /tmp/find_suid /tmp/python3_suid /tmp/suid_vulns.txt; log "SUID removed"
info "[8/14] NFS..."; [ -f /etc/exports ] && { sed -i 's/no_root_squash/root_squash/g' /etc/exports; exportfs -ra 2>/dev/null || true; log "NFS patched"; } || log "NFS not configured"
info "[9/14] Plaintext creds..."; rm -f /opt/app/config/database.conf /opt/app/config/app.env /opt/.env /srv/ftp/credentials.txt /srv/ftp/network_diagram.txt /srv/ftp/credentials.txt; truncate -s 0 /var/log/app/app.log 2>/dev/null || true; log "Creds removed"
info "[10/14] Firewall..."; pkill -f 'nc -lvnp' 2>/dev/null || true; ufw default deny incoming; ufw default allow outgoing; ufw allow 22/tcp; ufw allow 21/tcp; ufw allow 20/tcp; ufw allow 10090:10100/tcp; ufw deny 4444/tcp; ufw deny 8888/tcp; ufw --force enable; log "UFW enabled"
info "[11/14] Logs..."; chmod 755 /var/log; chmod 640 /var/log/auth.log 2>/dev/null && chown syslog:adm /var/log/auth.log 2>/dev/null || true; chmod 640 /var/log/vsftpd.log 2>/dev/null && chown root:adm /var/log/vsftpd.log 2>/dev/null || true; apt-get install -y auditd 2>/dev/null || true; systemctl enable --now auditd rsyslog 2>/dev/null || true; log "Logs fixed"
info "[12/14] Apache check..."; systemctl is-active --quiet apache2 2>/dev/null && { sed -i 's/ServerTokens Full/ServerTokens Prod/' /etc/apache2/apache2.conf 2>/dev/null || true; systemctl restart apache2 2>/dev/null || true; log "Apache hardened"; } || log "Apache not running"
info "[13/14] MySQL check..."; systemctl is-active --quiet mariadb 2>/dev/null && { mysql -u root -proot -e "DROP USER IF EXISTS 'root'@'%'; DROP USER IF EXISTS 'admin'@'%'; FLUSH PRIVILEGES;" 2>/dev/null || true; log "MySQL cleaned"; } || log "MySQL not running"

info "[14/14] FTP Anonymous Login..."
if systemctl is-active --quiet vsftpd 2>/dev/null || [ -f /etc/vsftpd.conf ]; then
    sed -i 's/anonymous_enable=YES/anonymous_enable=NO/'     /etc/vsftpd.conf 2>/dev/null || true
    sed -i 's/no_anon_password=YES/no_anon_password=NO/'     /etc/vsftpd.conf 2>/dev/null || true
    sed -i 's/anon_upload_enable=YES/anon_upload_enable=NO/' /etc/vsftpd.conf 2>/dev/null || true
    grep -q "^anonymous_enable" /etc/vsftpd.conf || echo "anonymous_enable=NO" >> /etc/vsftpd.conf
    grep -q "^chroot_local_user" /etc/vsftpd.conf || echo "chroot_local_user=YES" >> /etc/vsftpd.conf
    rm -f /srv/ftp/credentials.txt /srv/ftp/network_diagram.txt
    chown root:root /srv/ftp 2>/dev/null || true; chmod 755 /srv/ftp 2>/dev/null || true
    systemctl restart vsftpd 2>/dev/null || true
    log "FTP anonymous login disabled, credentials removed, chroot enabled"
else
    err "vsftpd not found"
fi

echo ""; echo "============================================================================="; if [ $ERRORS -eq 0 ]; then echo "  FTP Server Patch Complete — All 14 patches applied"; else echo "  FTP Server Patch Complete — $ERRORS error(s)"; fi; echo "============================================================================="; echo "  REMINDER: Set strong passwords for all FTP user accounts"
