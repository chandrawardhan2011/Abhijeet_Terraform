#!/bin/bash
# vuln: ssh_brute_force | severity: high
# Creates a new weak user instead of modifying ansible/root credentials
# Ansible SSH connectivity is preserved throughout
echo "[VULN] Injecting SSH Brute Force vulnerability..."

# Enable password authentication (needed for brute force to work)
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 100/' /etc/ssh/sshd_config

# Create weak user with root privileges — leave ansible/root untouched
useradd -m -s /bin/bash labuser 2>/dev/null || true
echo "labuser:toor" | chpasswd
usermod -aG sudo labuser 2>/dev/null || true

# Give labuser passwordless sudo (max attack surface)
echo "labuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/labuser
chmod 440 /etc/sudoers.d/labuser

# Stop fail2ban so brute force succeeds
systemctl stop fail2ban 2>/dev/null || true
systemctl disable fail2ban 2>/dev/null || true

systemctl restart sshd || systemctl restart ssh

cat > /tmp/ssh_brute_info.txt << 'INFO'
SSH Brute Force Vulnerability Injected
Weak account: labuser:toor (sudo NOPASSWD)
Attack: hydra -l labuser -P rockyou.txt ssh://<IP>
        ssh labuser@<IP>   password: toor
        sudo su            (instant root)
INFO

echo "[VULN] SSH brute force enabled. labuser:toor (sudo root)"
echo "[INFO] ansible/root credentials unchanged"
