#!/bin/bash
# vuln: ssh_brute_force
# Weakens SSH to allow brute-force: enables password auth, allows root login,
# sets weak password for ansible user, removes fail2ban if present.
set -e

echo "[VULN] Injecting SSH Brute Force vulnerability..."

# Backup original sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null || true

# Enable password authentication
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 100/' /etc/ssh/sshd_config

# Set weak password
echo "ansible:password123" | chpasswd
echo "root:toor" | chpasswd

# Remove fail2ban if present
systemctl stop fail2ban 2>/dev/null || true
systemctl disable fail2ban 2>/dev/null || true

# Restart SSH
systemctl restart sshd || systemctl restart ssh

echo "[VULN] SSH Brute Force vulnerability injected."
echo "[FLAG] Check /root/.ssh/authorized_keys and /etc/ssh/sshd_config"
