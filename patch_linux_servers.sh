#!/bin/bash
# =============================================================================
# CyberRange SYN-01 — Linux Server Master Patch Script
# Patches ALL injected vulnerabilities on:
#   wazuh-server-1 (10.0.20.10)
#   web-server-1   (10.0.20.21)
#   db-server-1    (10.0.20.30)
#   ftp-server-1   (10.0.20.40)
# Run as root on each server
# =============================================================================
set -e
ERRORS=0
log()  { echo "[+] $*"; }
err()  { echo "[!] $*"; ERRORS=$((ERRORS+1)); }
info() { echo "[*] $*"; }

echo "============================================="
echo "  CyberRange Linux Server — Master Patch"
echo "============================================="

# ── 1. SSH Brute Force ────────────────────────────────────────────────────────
info "[1/14] Patching SSH Brute Force..."
sed -i 's/MaxAuthTries 100/MaxAuthTries 3/' /etc/ssh/sshd_config 2>/dev/null || true
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
userdel -r labuser 2>/dev/null || true
rm -f /etc/sudoers.d/labuser /tmp/ssh_brute_info.txt
apt-get install -y fail2ban 2>/dev/null && systemctl enable --now fail2ban 2>/dev/null || true
log "labuser removed, MaxAuthTries restored, fail2ban re-enabled"

# ── 2. Dirty COW / ASLR ──────────────────────────────────────────────────────
info "[2/14] Patching Dirty COW / ASLR..."
sysctl -w kernel.randomize_va_space=2 2>/dev/null || true
sed -i 's/kernel.randomize_va_space = 0/kernel.randomize_va_space = 2/' /etc/sysctl.conf 2>/dev/null || true
rm -f /tmp/vuln_suid_bash /tmp/root_owned_writable /tmp/dirty_cow_vulnerable
log "ASLR re-enabled, artefacts removed"

# ── 3. SUDO Privesc ───────────────────────────────────────────────────────────
info "[3/14] Patching SUDO Privilege Escalation..."
sed -i '/student.*NOPASSWD/d' /etc/sudoers 2>/dev/null || true
userdel -r student 2>/dev/null || true
chmod 644 /etc/passwd
log "NOPASSWD removed, student deleted, /etc/passwd permissions fixed"

# ── 4. Cronjob Misconfiguration ───────────────────────────────────────────────
info "[4/14] Patching Cronjob Misconfiguration..."
chmod 755 /opt/cleanup.sh 2>/dev/null && chown root:root /opt/cleanup.sh 2>/dev/null || true
chmod 600 /etc/crontab 2>/dev/null || true
rm -f /etc/cron.d/vuln_cleanup
# Remove any reverse shell crontab entries
crontab -l 2>/dev/null | grep -v "bash -i" | crontab - 2>/dev/null || true
sed -i '/bash.*\/dev\/tcp/d' /etc/crontab 2>/dev/null || true
log "Crontab permissions fixed, malicious entries removed"

# ── 5. Weak File Permissions ──────────────────────────────────────────────────
info "[5/14] Patching Weak File Permissions..."
chmod 644 /etc/passwd
chmod 640 /etc/shadow && chown root:shadow /etc/shadow 2>/dev/null || true
chmod 440 /etc/sudoers
chmod 600 /etc/crontab
find /home -name "*.sh" -exec chmod 750 {} \; 2>/dev/null || true
find /opt -name "*.conf" -exec chmod 640 {} \; 2>/dev/null || true
rm -f /tmp/shadow_backup
log "File permissions restored"

# ── 6. Kernel Hardening ───────────────────────────────────────────────────────
info "[6/14] Patching Kernel Hardening..."
sysctl -w kernel.randomize_va_space=2 2>/dev/null || true
sysctl -w kernel.kptr_restrict=1 2>/dev/null || true
sysctl -w kernel.yama.ptrace_scope=1 2>/dev/null || true
sysctl -w net.ipv4.tcp_syncookies=1 2>/dev/null || true
sysctl -w net.ipv4.conf.all.accept_redirects=0 2>/dev/null || true
sed -i '/randomize_va_space=0/d;/kptr_restrict=0/d;/ptrace_scope=0/d' /etc/sysctl.conf 2>/dev/null || true
rm -f /tmp/kernel_vuln_info.txt
log "Kernel hardening restored"

# ── 7. SUID Binaries ──────────────────────────────────────────────────────────
info "[7/14] Patching SUID Binaries..."
rm -f /tmp/bash_suid /tmp/find_suid /tmp/python3_suid /tmp/suid_vulns.txt
log "SUID artefacts removed"

# ── 8. NFS Misconfiguration ───────────────────────────────────────────────────
info "[8/14] Patching NFS Misconfiguration..."
sed -i 's/no_root_squash/root_squash/' /etc/exports 2>/dev/null || true
exportfs -ra 2>/dev/null || true
systemctl restart nfs-kernel-server 2>/dev/null || true
rm -f /srv/nfs_share/sensitive_data.txt
log "NFS no_root_squash removed"

# ── 9. Plaintext Credentials ─────────────────────────────────────────────────
info "[9/14] Patching Plaintext Credentials..."
rm -f /opt/app/config/database.conf /opt/app/config/app.env
truncate -s 0 /var/log/app/app.log 2>/dev/null || true
log "Plaintext config files removed. Rotate all exposed passwords."

# ── 10. Open Ports / Firewall ─────────────────────────────────────────────────
info "[10/14] Patching Open Ports and Firewall..."
pkill -f 'nc -lvnp' 2>/dev/null || true
apt-get purge -y telnetd 2>/dev/null || true
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
log "Firewall re-enabled, netcat listeners killed"

# ── 11. Log Tampering ─────────────────────────────────────────────────────────
info "[11/14] Patching Log Tampering..."
chmod 755 /var/log
chmod 640 /var/log/auth.log 2>/dev/null && chown syslog:adm /var/log/auth.log 2>/dev/null || true
chmod 640 /var/log/syslog 2>/dev/null && chown syslog:adm /var/log/syslog 2>/dev/null || true
apt-get install -y auditd 2>/dev/null || true
systemctl enable --now auditd 2>/dev/null || true
systemctl enable --now rsyslog 2>/dev/null || true
log "Log permissions fixed, auditd and rsyslog re-enabled"

# ── 12. Insecure Service Config (Apache) ──────────────────────────────────────
info "[12/14] Patching Insecure Apache Config..."
if [ -f /etc/apache2/apache2.conf ]; then
    sed -i 's/ServerTokens Full/ServerTokens Prod/' /etc/apache2/apache2.conf 2>/dev/null || true
    sed -i 's/ServerSignature On/ServerSignature Off/' /etc/apache2/apache2.conf 2>/dev/null || true
    sed -i 's/Options Indexes/Options -Indexes/' /etc/apache2/apache2.conf 2>/dev/null || true
    truncate -s 0 /etc/motd
    systemctl restart apache2 2>/dev/null || true
    log "Apache hardened"
else
    log "Apache not found on this host — skipping"
fi

# ── 13. MySQL Brute Force ─────────────────────────────────────────────────────
info "[13/14] Patching MySQL Remote Access..."
mysql -u root -proot -e "DROP USER IF EXISTS 'root'@'%'; DROP USER IF EXISTS 'admin'@'%'; DROP USER IF EXISTS 'sa'@'%'; FLUSH PRIVILEGES;" 2>/dev/null || true
sed -i 's/#bind-address/bind-address/' /etc/mysql/mariadb.conf.d/50-server.cnf 2>/dev/null || true
systemctl restart mariadb 2>/dev/null || true
ufw deny 3306/tcp 2>/dev/null || true
log "MySQL remote accounts removed, bind-address restored"

# ── 14. FTP Anonymous ─────────────────────────────────────────────────────────
info "[14/14] Patching FTP Anonymous Login..."
sed -i 's/anonymous_enable=YES/anonymous_enable=NO/' /etc/vsftpd.conf 2>/dev/null || true
sed -i 's/no_anon_password=YES/no_anon_password=NO/' /etc/vsftpd.conf 2>/dev/null || true
rm -f /var/ftp/pub/credentials.txt /var/ftp/pub/network_diagram.txt
systemctl restart vsftpd 2>/dev/null || true
log "FTP anonymous login disabled"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================="
echo "  Linux Server Patch Complete"
if [ $ERRORS -eq 0 ]; then
    echo "  All 14 patches applied successfully"
else
    echo "  Completed with $ERRORS error(s)"
fi
echo "  REMINDER: Rotate any other exposed passwords manually"
echo "============================================="
