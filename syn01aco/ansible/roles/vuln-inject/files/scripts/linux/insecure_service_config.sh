#!/bin/bash
# vuln: insecure_service_config | severity: low
echo "[VULN] Injecting Insecure Service Configuration..."
# Apache misconfiguration — directory listing, server tokens
if [ -f /etc/apache2/apache2.conf ]; then
    sed -i 's/ServerTokens OS/ServerTokens Full/' /etc/apache2/apache2.conf 2>/dev/null || true
    sed -i 's/ServerSignature Off/ServerSignature On/' /etc/apache2/apache2.conf 2>/dev/null || true
    echo "ServerTokens Full" >> /etc/apache2/apache2.conf
    echo "ServerSignature On" >> /etc/apache2/apache2.conf
    cat >> /etc/apache2/conf-available/security.conf << 'EOFTXT' 2>/dev/null || true
<Directory /var/www/>
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
EOFTXT
    systemctl reload apache2 2>/dev/null || true
fi
# Enable telnet-like banner disclosure
echo "OpenSSH_8.9 Ubuntu-3ubuntu0.1" > /etc/motd
echo "Linux web-server-1 5.15.0-91-generic #101-Ubuntu" >> /etc/motd
echo "[VULN] Insecure service configuration injected — version disclosure enabled."
echo "[INFO] Apache reveals version, directory listing enabled."
