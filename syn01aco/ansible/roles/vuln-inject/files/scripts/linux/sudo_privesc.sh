#!/bin/bash
# vuln: sudo_privesc | severity: critical
echo "[VULN] Injecting Sudo Privilege Escalation..."
useradd -m -s /bin/bash student 2>/dev/null || true
echo "student:student" | chpasswd
cat >> /etc/sudoers << 'EOFTXT'
student ALL=(ALL) NOPASSWD: /usr/bin/python3
student ALL=(ALL) NOPASSWD: /usr/bin/find
student ALL=(ALL) NOPASSWD: /bin/bash
EOFTXT
chmod 666 /etc/passwd
echo "[VULN] Sudo privesc. Exploit: sudo python3 -c 'import os; os.system(\"/bin/bash\")'"
