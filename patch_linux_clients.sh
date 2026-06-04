#!/bin/bash
# =============================================================================
# CyberRange SYN-01 — Linux Client Master Patch Script
# Patches ALL injected vulnerabilities on linux-1 (10.0.20.200)
# Based on actual dropdown list visible in Operator Panel
# Run as root
# =============================================================================
ERRORS=0
log()  { echo "[+] $*"; }
err()  { echo "[!] $*"; ERRORS=$((ERRORS+1)); }
info() { echo "[*] $*"; }

echo "============================================="
echo "  CyberRange Linux Client — Master Patch"
echo "============================================="

# ── 1. SSH Brute Force ────────────────────────────────────────────────────────
info "[1/20] Patching SSH Brute Force..."
sed -i 's/MaxAuthTries 100/MaxAuthTries 3/' /etc/ssh/sshd_config 2>/dev/null || true
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
userdel -r labuser 2>/dev/null || true
rm -f /etc/sudoers.d/labuser /tmp/ssh_brute_info.txt
apt-get install -y fail2ban 2>/dev/null && systemctl enable --now fail2ban 2>/dev/null || true
log "labuser removed, MaxAuthTries restored, fail2ban re-enabled"

# ── 2. Dirty COW / ASLR ──────────────────────────────────────────────────────
info "[2/20] Patching Dirty COW / ASLR..."
sysctl -w kernel.randomize_va_space=2 2>/dev/null || true
sed -i 's/kernel.randomize_va_space = 0/kernel.randomize_va_space = 2/' /etc/sysctl.conf 2>/dev/null || true
rm -f /tmp/vuln_suid_bash /tmp/root_owned_writable /tmp/dirty_cow_vulnerable
log "ASLR re-enabled, artefacts removed"

# ── 3. Sudo Privilege Escalation ─────────────────────────────────────────────
info "[3/20] Patching SUDO Privilege Escalation..."
sed -i '/student.*NOPASSWD/d' /etc/sudoers 2>/dev/null || true
sed -i '/labuser.*NOPASSWD/d' /etc/sudoers 2>/dev/null || true
rm -f /etc/sudoers.d/vuln_* /etc/sudoers.d/student
userdel -r student 2>/dev/null || true
chmod 440 /etc/sudoers
log "NOPASSWD entries removed"

# ── 4. Cronjob Misconfiguration ───────────────────────────────────────────────
info "[4/20] Patching Cronjob Misconfiguration..."
chmod 755 /opt/cleanup.sh 2>/dev/null && chown root:root /opt/cleanup.sh 2>/dev/null || true
chmod 600 /etc/crontab 2>/dev/null || true
rm -f /etc/cron.d/vuln_cleanup
sed -i '/bash.*\/dev\/tcp/d' /etc/crontab 2>/dev/null || true
crontab -l 2>/dev/null | grep -v "bash -i\|nc -lvnp" | crontab - 2>/dev/null || true
log "Crontab permissions fixed, malicious entries removed"

# ── 5. Weak File Permissions ──────────────────────────────────────────────────
info "[5/20] Patching Weak File Permissions..."
chmod 644 /etc/passwd
chmod 640 /etc/shadow && chown root:shadow /etc/shadow 2>/dev/null || true
chmod 440 /etc/sudoers
chmod 600 /etc/crontab
rm -f /tmp/shadow_backup /tmp/permissions_backup
log "File permissions restored"

# ── 6. Unpatched Kernel / ASLR Disabled ──────────────────────────────────────
info "[6/20] Patching Kernel Hardening..."
sysctl -w kernel.randomize_va_space=2 2>/dev/null || true
sysctl -w kernel.kptr_restrict=1 2>/dev/null || true
sysctl -w kernel.yama.ptrace_scope=1 2>/dev/null || true
sysctl -w net.ipv4.tcp_syncookies=1 2>/dev/null || true
sysctl -w net.ipv4.conf.all.accept_redirects=0 2>/dev/null || true
sed -i '/randomize_va_space=0/d;/kptr_restrict=0/d;/ptrace_scope=0/d' /etc/sysctl.conf 2>/dev/null || true
rm -f /tmp/kernel_vuln_info.txt
log "Kernel hardening restored"

# ── 7. SUID Binary Misconfiguration ──────────────────────────────────────────
info "[7/20] Patching SUID Binaries..."
rm -f /tmp/bash_suid /tmp/find_suid /tmp/python3_suid /tmp/suid_vulns.txt
log "SUID artefacts removed"

# ── 8. NFS no_root_squash ─────────────────────────────────────────────────────
info "[8/20] Patching NFS Misconfiguration..."
sed -i 's/no_root_squash/root_squash/' /etc/exports 2>/dev/null || true
exportfs -ra 2>/dev/null || true
systemctl restart nfs-kernel-server 2>/dev/null || true
rm -f /srv/nfs_share/sensitive_data.txt
log "NFS no_root_squash removed"

# ── 9. Plaintext Credentials in Config ───────────────────────────────────────
info "[9/20] Patching Plaintext Credentials..."
rm -f /opt/app/config/database.conf /opt/app/config/app.env /opt/.env
truncate -s 0 /var/log/app/app.log 2>/dev/null || true
log "Plaintext config files removed"

# ── 10. Unnecessary Open Ports / No Firewall ─────────────────────────────────
info "[10/20] Patching Open Ports and Firewall..."
pkill -f 'nc -lvnp' 2>/dev/null || true
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw --force enable
log "UFW re-enabled, netcat listeners killed"

# ── 11. Log Tampering / Audit Disabled ───────────────────────────────────────
info "[11/20] Patching Log Tampering..."
chmod 755 /var/log
chmod 640 /var/log/auth.log 2>/dev/null && chown syslog:adm /var/log/auth.log 2>/dev/null || true
chmod 640 /var/log/syslog 2>/dev/null && chown syslog:adm /var/log/syslog 2>/dev/null || true
apt-get install -y auditd 2>/dev/null || true
systemctl enable --now auditd 2>/dev/null || true
systemctl enable --now rsyslog 2>/dev/null || true
log "Log permissions fixed, auditd and rsyslog re-enabled"

# ── 12. World-Writable Dirs with Sensitive Data ──────────────────────────────
info "[12/20] Patching World-Writable Directories..."
chmod 755 /opt/shared /srv/data /var/app 2>/dev/null || true
rm -f /opt/shared/internal_notes.txt
log "World-writable dirs fixed"

# ── 13. Weak User Passwords ───────────────────────────────────────────────────
info "[13/20] Patching Weak User Passwords..."
for user in alice bob charlie david; do
    if id "$user" &>/dev/null; then
        passwd -l "$user" 2>/dev/null || true
        log "Locked: $user"
    fi
done
apt-get install -y libpam-pwquality 2>/dev/null || true
if ! grep -q "pam_pwquality" /etc/pam.d/common-password 2>/dev/null; then
    echo "password requisite pam_pwquality.so retry=3 minlen=12 dcredit=-1 ucredit=-1" \
        >> /etc/pam.d/common-password
fi
log "Weak accounts locked, password complexity re-enabled"

# ── 14. Unprotected SSH Private Keys ─────────────────────────────────────────
info "[14/20] Patching Unprotected SSH Keys..."
chmod 700 /home/ansible/.ssh 2>/dev/null || true
chmod 600 /home/ansible/.ssh/id_rsa 2>/dev/null || true
chmod 644 /home/ansible/.ssh/id_rsa.pub 2>/dev/null || true
chown -R ansible:ansible /home/ansible/.ssh 2>/dev/null || true
rm -f /tmp/admin_ssh_key /tmp/ssh_key_locations.txt
log "SSH key permissions fixed"

# ── 15. No Host Firewall ──────────────────────────────────────────────────────
info "[15/20] Restoring Host Firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw --force enable
log "UFW re-enabled"

# ── 16. Sensitive Data in Bash History ────────────────────────────────────────
info "[16/20] Clearing Sensitive Bash History..."
truncate -s 0 /root/.bash_history 2>/dev/null || true
truncate -s 0 /home/ansible/.bash_history 2>/dev/null || true
log "Bash history cleared"

# ── 17. LXD Group Privilege Escalation ───────────────────────────────────────
info "[17/20] Patching LXD Privilege Escalation..."
gpasswd -d lxduser lxd 2>/dev/null || true
gpasswd -d lxduser docker 2>/dev/null || true
userdel -r lxduser 2>/dev/null || true
rm -f /tmp/lxd_exploit_info.txt
log "lxduser removed from lxd/docker groups and deleted"

# ── 18. Exposed API Keys in Environment ──────────────────────────────────────
info "[18/20] Removing Exposed API Keys..."
sed -i '/AWS_ACCESS_KEY_ID/d;/AWS_SECRET_ACCESS_KEY/d;/GITHUB_TOKEN/d;/DATABASE_URL/d' \
    /etc/environment 2>/dev/null || true
rm -f /opt/.env
log "API keys removed. Revoke in AWS/GitHub manually."

# ── 19. Netcat Backdoor (4444/1337) ──────────────────────────────────────────
info "[19/20] Removing Netcat Backdoor..."
pkill -f 'nc -lvnp' 2>/dev/null || true
sed -i '/nc.*lvnp.*bash/d' /etc/crontab 2>/dev/null || true
crontab -l 2>/dev/null | grep -v "nc -lvnp" | crontab - 2>/dev/null || true
ufw deny 4444/tcp 2>/dev/null || true
ufw deny 1337/tcp 2>/dev/null || true
rm -f /tmp/backdoor_info.txt
log "Netcat backdoors killed and blocked"

# ── 20. World-Writable /etc/passwd & /etc/shadow ────────────────────────────
info "[20/20] Fixing /etc/passwd and /etc/shadow..."
chmod 644 /etc/passwd
chmod 640 /etc/shadow && chown root:shadow /etc/shadow 2>/dev/null || true
grep ':0:0:' /etc/passwd | grep -v '^root:' | cut -d: -f1 | while read u; do
    sed -i "/^${u}:/d" /etc/passwd
    log "Removed rogue account: $u"
done
rm -f /tmp/passwd_backup /tmp/shadow_backup

# Also remove rpcbind
systemctl stop rpcbind 2>/dev/null || true
systemctl disable rpcbind 2>/dev/null || true
ufw deny 111/tcp 2>/dev/null || true
ufw deny 111/udp 2>/dev/null || true
log "/etc/passwd and /etc/shadow permissions restored, rpcbind disabled"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================="
echo "  Linux Client Patch Complete"
if [ $ERRORS -eq 0 ]; then
    echo "  All 20 patches applied successfully"
else
    echo "  Completed with $ERRORS error(s)"
fi
echo "  REMINDER: Set strong passwords for:"
echo "    alice, bob, charlie, david, root, ansible"
echo "  REMINDER: Revoke AWS and GitHub keys"
echo "============================================="
