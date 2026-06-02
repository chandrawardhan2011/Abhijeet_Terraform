#!/bin/bash
# vuln: weak_file_permissions | severity: medium
echo "[VULN] Injecting Weak File Permissions..."
chmod 777 /etc/passwd /etc/shadow /etc/sudoers 2>/dev/null || true
chmod 777 /etc/crontab 2>/dev/null || true
find /home -name "*.sh" -exec chmod 777 {} \; 2>/dev/null || true
find /opt -name "*.conf" -exec chmod 666 {} \; 2>/dev/null || true
echo "root:toor" > /tmp/shadow_backup
chmod 644 /tmp/shadow_backup
echo "[VULN] Weak file permissions injected."
echo "[INFO] /etc/shadow is world-readable — hashes extractable"
