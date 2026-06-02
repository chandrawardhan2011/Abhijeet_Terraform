#!/bin/bash
# vuln: cronjob_misconfig | severity: high
echo "[VULN] Injecting Cronjob Misconfiguration..."
cat > /opt/cleanup.sh << 'EOFTXT'
#!/bin/bash
/bin/rm -rf /tmp/cleanup_tmp 2>/dev/null
mkdir -p /tmp/cleanup_tmp
EOFTXT
chmod 777 /opt/cleanup.sh
(crontab -l 2>/dev/null; echo "* * * * * /opt/cleanup.sh") | crontab -
cat > /etc/cron.d/vuln_cleanup << 'EOFTXT'
* * * * * root /opt/cleanup.sh
MAILTO=""
EOFTXT
chmod 666 /etc/cron.d/vuln_cleanup
echo "[VULN] World-writable cron running as root. Modify /opt/cleanup.sh to execute as root."
