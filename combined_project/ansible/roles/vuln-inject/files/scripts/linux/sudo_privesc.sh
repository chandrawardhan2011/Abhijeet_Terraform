#!/bin/bash
# vuln: sudo_privesc
# Creates a misconfigured sudoers entry that allows privilege escalation
# via NOPASSWD and dangerous commands (find, vim, python3, etc.)

set -e
echo "[VULN] Injecting Sudo Privilege Escalation vulnerability..."

# Create a low-privilege user with misconfigured sudo
useradd -m -s /bin/bash lowpriv 2>/dev/null || true
echo "lowpriv:password" | chpasswd

# Add dangerous sudoers rules
cat >> /etc/sudoers << 'EOF'

# VULNERABLE: Misconfigured sudoers - allows privesc
lowpriv ALL=(ALL) NOPASSWD: /usr/bin/find
lowpriv ALL=(ALL) NOPASSWD: /usr/bin/python3
lowpriv ALL=(ALL) NOPASSWD: /usr/bin/vim
lowpriv ALL=(ALL) NOPASSWD: /usr/bin/less
lowpriv ALL=(ALL) NOPASSWD: /bin/bash
ansible ALL=(ALL) NOPASSWD: ALL
EOF

# Make /etc/passwd world-writable (extreme misconfiguration)
chmod 666 /etc/passwd

echo "[VULN] Sudo Privilege Escalation injected."
echo "[INFO] User 'lowpriv:password' can escalate via: sudo python3 -c 'import os; os.system(\"/bin/bash\")'"
