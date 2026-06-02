#!/bin/bash
# vuln: ssh_brute_force | severity: high
echo "[VULN] Injecting SSH Brute Force vulnerability..."
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 100/' /etc/ssh/sshd_config
echo "ansible:password123" | chpasswd
echo "root:toor" | chpasswd
systemctl stop fail2ban 2>/dev/null || true
systemctl restart sshd || systemctl restart ssh
echo "[VULN] SSH brute force enabled. root:toor, ansible:password123"
