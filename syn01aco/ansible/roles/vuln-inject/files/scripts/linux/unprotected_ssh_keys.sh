#!/bin/bash
# vuln: unprotected_ssh_keys | severity: high
echo "[VULN] Injecting Unprotected SSH Keys..."
mkdir -p /home/ansible/.ssh
ssh-keygen -t rsa -b 2048 -f /home/ansible/.ssh/id_rsa -N "" 2>/dev/null || true
chmod 777 /home/ansible/.ssh
chmod 666 /home/ansible/.ssh/id_rsa
chmod 666 /home/ansible/.ssh/id_rsa.pub
# Plant private key in world-readable location
cp /home/ansible/.ssh/id_rsa /tmp/admin_ssh_key
chmod 644 /tmp/admin_ssh_key
cat > /tmp/ssh_key_locations.txt << 'EOFTXT'
SSH private keys found:
/tmp/admin_ssh_key         (world-readable!)
/home/ansible/.ssh/id_rsa  (world-readable!)
Use: ssh -i /tmp/admin_ssh_key user@targethost
EOFTXT
echo "[VULN] SSH private keys world-readable. Check /tmp/admin_ssh_key"
