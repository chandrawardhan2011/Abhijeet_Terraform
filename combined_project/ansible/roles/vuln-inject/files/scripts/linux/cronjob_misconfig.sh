#!/bin/bash
# vuln: cronjob_misconfig
# Creates world-writable cron scripts and insecure crontab entries

set -e
echo "[VULN] Injecting Cronjob Misconfiguration vulnerability..."

# Create a world-writable script that runs as root via cron
cat > /opt/cleanup.sh << 'EOF'
#!/bin/bash
# This script is run by root every minute
# It is world-writable - any user can modify it to execute as root!
/bin/rm -rf /tmp/cleanup_tmp 2>/dev/null
mkdir -p /tmp/cleanup_tmp
EOF
chmod 777 /opt/cleanup.sh
chown root:root /opt/cleanup.sh

# Add to root crontab
(crontab -l 2>/dev/null; echo "* * * * * /opt/cleanup.sh") | crontab -

# Create a world-writable cron.d entry
cat > /etc/cron.d/vuln_cleanup << 'EOF'
* * * * * root /opt/cleanup.sh
MAILTO=""
EOF
chmod 666 /etc/cron.d/vuln_cleanup

# Create world-writable PATH directory in cron environment
mkdir -p /usr/local/games
chmod 777 /usr/local/games

echo "[VULN] Cronjob Misconfiguration injected."
echo "[INFO] /opt/cleanup.sh is world-writable and runs as root every minute."
echo "[INFO] Replace contents of /opt/cleanup.sh to execute arbitrary commands as root."
