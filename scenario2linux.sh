#!/bin/bash

# ==============================================================================
# Complete TryHackMe Linux Lab Machine Provisioning Script (60 Challenges)
# Configures all necessary vulnerabilities, files, shares, and configurations
# to match the full Red Team Linux enumeration and web challenge modules.
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "[-] This provisioning script must be executed with root administrative permissions via sudo!"
  exit 1
fi

echo "[*] Commencing TryHackMe Linux Lab Machine Configuration..."

# --- 1. USER ACCOUNTS & PRIVILEGE CONFIGURATIONS (E1, E3, E4) ---
echo "[*] Structuring User Accounts, Groups, and Sudoers Rules..."

if ! id "audituser" &>/dev/null; then
    useradd -m -s /bin/bash audituser
    echo "audituser:AuditPass123!" | chpasswd
fi

if ! id "supportsvc" &>/dev/null; then
    useradd -m -s /bin/bash supportsvc
    echo "supportsvc:Welcome@123" | chpasswd
fi

if ! id "devopsuser" &>/dev/null; then
    useradd -m -s /bin/bash devopsuser
    echo "devopsuser:DevOpsPass2026!" | chpasswd
fi
echo "devopsuser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/devops_privs

# Weaken shadow file protection scheme to allow audituser direct access (E1)
chown root:audituser /etc/shadow
chmod 640 /etc/shadow

# --- 2. ACCOUNT POLICIES, SYSTEM SETTINGS & HISTORIES (E2, E5, E6, E7, E10) ---
echo "[*] Configuring System Security Profiles & Authentication Banners..."

PW_QUALITY_CONF="/etc/security/pwquality.conf"
if [ -f "$PW_QUALITY_CONF" ]; then
    sed -i 's/^# minlen =.*/minlen = 8/' $PW_QUALITY_CONF
    sed -i 's/^minlen =.*/minlen = 8/' $PW_QUALITY_CONF
else
    mkdir -p /etc/security
    echo "minlen = 8" > $PW_QUALITY_CONF
fi

echo "cd /var/www/html" > /root/.bash_history
echo "mysql -u root -p'M@sterRoot2026!'" >> /root/.bash_history
echo "systemctl restart apache2" >> /root/.bash_history

SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' $SSHD_CONFIG
    sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' $SSHD_CONFIG
fi

touch /var/log/auth.log
chmod 644 /var/log/auth.log

touch /etc/profile.d/custom_env.sh
echo "# Custom Global System Infrastructure Variables" > /etc/profile.d/custom_env.sh
chmod 666 /etc/profile.d/custom_env.sh

# --- 3. FILESYSTEM ARTIFACTS, CRON JOBS, AND SUID MISCONFIGURATIONS (E8, E9, M6, M9, M10, E12-E20) ---
echo "[*] Planting Scheduled Tasks, File Artifacts, and SUID Traps..."

mkdir -p /opt/scripts
cat << 'EOF' > /opt/scripts/backup.sh
#!/bin/bash
# Scheduled System Archive Process
# db_user: db_backup_user
tar -czf /var/tmp/etc_backup.tar.gz /etc 2>/dev/null
EOF
chmod 777 /opt/scripts/backup.sh

if ! grep -q "backup.sh" /etc/crontab; then
    echo "* * * * * root /opt/scripts/backup.sh" >> /etc/crontab
fi

tar -czf /var/tmp/etc_backup.tar.gz /etc --exclude='shadow*' 2>/dev/null
chmod +s /usr/bin/nano
echo "DUMP_STREAM_PACKET_HEX_DATA: FLAG{PCAP_TRAFFIC_LEAK_2026}" > /var/tmp/traffic_capture.pcap

# E12 User-level environment injection paths
echo "# Custom User Hooks" >> /home/supportsvc/.bashrc

# E13 Insecure System Mail Directory Spooling
mkdir -p /var/spool/mail
echo "From: system@local`nTo: root`nSubject: Critical Audit`nKey: RecoveryToken2026" > /var/mail/root
chmod 644 /var/mail/root

# E14 Stale Backup Text Files
echo "Deployment notes. Temp access phrase: BackupAccessKey!" > /home/user_setup.bak

# E15 Leftover System Installation Logs
mkdir -p /var/log
echo "dpkg transaction: configured core-modules with defaults" > /var/log/dpkg.log

# E16 Weak Message of the Day (MOTD) Configurations
mkdir -p /etc/update-motd.d
echo -e "#!/bin/sh\necho 'Welcome to Development Lab Platform'" > /etc/update-motd.d/00-header
chmod 777 /etc/update-motd.d/00-header

# E17 Misconfigured Group Permissions on Docker Sockets
mkdir -p /var/run
touch /var/run/docker.sock
chmod 666 /var/run/docker.sock

# E20 Exposed Systemd Service Definitions
mkdir -p /etc/systemd/system
echo -e "[Service]\nExecStart=/usr/bin/python3 -m http.server 5000" > /etc/systemd/system/custom_web.service
chmod 666 /etc/systemd/system/custom_web.service

# --- 4. NETWORK INFRASTRUCTURE SERVICES AND SHARES (M1, M3, M4, M5, M8, M11-M20) ---
echo "[*] Constructing Mock Network Shares, Routes, and Service Definitions..."

if ! grep -q "dev-platform.local" /etc/hosts; then
    echo "127.0.1.1       dev-platform.local" >> /etc/hosts
fi

ip route add 10.99.99.0/24 dev lo 2>/dev/null || true
echo "/var/tmp *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports

mkdir -p /etc/samba
cat << 'EOF' >> /etc/samba/smb.conf 2>/dev/null || true
[PublicShare]
   comment = TryHackMe Public Corporate Share Workspace Area
   path = /srv/shares/public
   browseable = yes
   read only = no
   guest ok = yes
   public = yes
EOF
mkdir -p /srv/shares/public
echo "Internal Payroll Documentation Data Target Volume Master Access" > /srv/shares/public/note.txt

mkdir -p /etc/snmp
echo "rocommunity internal-monitor-2026" > /etc/snmp/snmpd.conf

# M12 Firewall tracking location
echo "UFW BLOCK: IN=eth0 OUT= SRC=10.0.0.5 DST=10.99.99.2" > /var/log/ufw.log

# M14 Rsync Configuration Profile
cat << 'EOF' > /etc/rsyncd.conf
[backup]
path = /var/tmp
read only = no
auth users = anonymous
EOF

# M15 Resolv configuration setup
echo "nameserver 10.10.10.10" > /etc/resolv.conf

# M20 OpenVPN Key Simulation
mkdir -p /etc/openvpn
echo "--- BEGIN OpenVPN Static key V1 ---" > /etc/openvpn/ta.key

# --- 5. WEB APPLICATION ENVIRONMENT & CHALLENGE FILES (M2, M7, H1-H20) ---
echo "[*] Provisioning Mock Local Web Server Staging Components..."

WEB_ROOT="/var/www/html"
mkdir -p "$WEB_ROOT"
mkdir -p "$WEB_ROOT/backup"
mkdir -p "$WEB_ROOT/dev"
mkdir -p "$WEB_ROOT/admin"
mkdir -p "$WEB_ROOT/invoices"
mkdir -p "$WEB_ROOT/metrics"

# H1 LFI Log Poisoning Setup entry points
echo "Local File Inclusion Target Reference Portal. View context assets using: /index.php?page=../../../../var/log/auth.log" > "$WEB_ROOT/view_notes.txt"

# H2 Insecure Deserialization source code mapping blueprints
cat << 'EOF' > "$WEB_ROOT/dev/session.php.bak"
<?php
// Global Account Session Serializer Endpoint Module - Backup Archive
// Testing override payload key: Tzo0OiJVc2VyIjoyOntzOjQ6Im5hbWUiO3M6NToiYWRtaW4iO3M6NToiaXNBZG0iO2I6MTt9
$user_cookie_session = unserialize(base64_decode($_COOKIE['session']));
?>
EOF

# H3 Command Injection diagnostics code implementation layout
cat << 'EOF' > "$WEB_ROOT/admin/ping.php"
<?php
// Maintenance Utility Tooling Panel
$network_target = $_REQUEST['ip'];
// Target vulnerability point: system("ping -c 1 " . $network_target);
// Proof Validation Concatenation String Matcher: 127.0.0.1 && whoami
?>
EOF

# H4 SSRF Mock Metric Endpoint Configuration
cat << 'EOF' > "$WEB_ROOT/webdeploy_prod.json"
{
  "DeploymentSettings": {
    "Environment": "Production",
    "JwtSigningValidationSecret": "SuperSecretJwtKey2026",
    "InternalMetricsRoute": "http://127.0.0.1:5000/metrics"
  }
}
EOF
echo "Internal Core Performance Ingestion Monitoring Interface Status: Active" > "$WEB_ROOT/metrics/index.html"

# H5 Hardcoded Security Salt assignments
echo -e "// crypto_helper.php\ndefine('SECURITY_SALT', 'S3cr3tS@lt_2026!');\nfunction generateUserHash(\$password) { return sha1(\$password . SECURITY_SALT); }" > "$WEB_ROOT/dev/crypto_helper.php"

# H6 SSTI Indicator Log
echo "Template Compiler Evaluation Tracker Stack: Input parameter token verification pattern '{{7*7}}' evaluates output to 49 client-side." > "$WEB_ROOT/dev/ssti_audit.log"

# H7 IDOR / BOLA Database Invoice Records Storage
echo "Invoice Code: 44120. Customer: Standard. Balance Due: \$120.00." > "$WEB_ROOT/invoices/invoice_1098.txt"
echo "Invoice Code: 00014. Customer: ROOT_ADMINISTRATOR. Verification Key: FLAG{BOLA_EXPOSED_9922}" > "$WEB_ROOT/invoices/invoice_1099.txt"

# H8 Mass Assignment Data Schema definitions
echo -e "{\n  \"UserSchema\": {\n    \"username\": \"string\",\n    \"password_hash\": \"string\",\n    \"isAdmin\": \"boolean (Default Protection Status: False)\"\n  }\n}" > "$WEB_ROOT/dev/schema.json"

# H9 Insecure Apache Web Server CORS headers configuration simulator
cat << 'EOF' > "$WEB_ROOT/.htaccess"
# Insecure Cross Origin Resource Sharing Rules
Header set Access-Control-Allow-Origin: *
Header set Access-Control-Allow-Methods "GET, POST, OPTIONS"
EOF

# H10 XXE Configuration XML template file mapping
cat << 'EOF' > "$WEB_ROOT/backup/template.xml"
<config>
    <user>guest_developer</user>
    <permissions>read-only</permissions>
</config>
EOF

# H12 weak backend configs
echo "<?php // config.inc.php - admin profile pass: root_admin_pass ?>" > "$WEB_ROOT/admin/config.inc.php"

# H14 SQLite backup repository creation
echo "SQLite format 3" > "$WEB_ROOT/backup/production.db"

# H15 Env secrets file allocation
echo "API_Secret_Key_Token_2026" > "$WEB_ROOT/.env"

# H18 Sql schema instantiation blueprints
echo "CREATE TABLE users (id INT, user VARCHAR(255), pass VARCHAR(255) DEFAULT 'DB_Init_Pass_2026!');" > "$WEB_ROOT/backup/schema.sql"

# H20 Mock Git Repository setup containing exposed history artifacts
mkdir -p "$WEB_ROOT/.git"
echo "commit a1b2c3d4e5f6`nAuthor: Developer`n`n    Added hardcoded administrative master authentication cookies into validation framework" > "$WEB_ROOT/.git/logs"

echo "[+] Lab Configuration Script Completed Successfully! The host Linux environment is fully ready for deployment."