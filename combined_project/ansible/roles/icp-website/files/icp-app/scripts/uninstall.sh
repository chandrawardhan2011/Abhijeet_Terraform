#!/usr/bin/env bash
# =============================================================================
# uninstall.sh — remove ICP from the host
# Run as: sudo ./uninstall.sh
# =============================================================================

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: must be run as root (use sudo)" >&2
    exit 1
fi

ETC_DIR=/etc/icp
DEPLOY_DIR=/var/www/icp

echo ">>> Disabling Apache vhost..."
a2dissite icp.conf >/dev/null 2>&1 || true
rm -f /etc/apache2/sites-available/icp.conf
systemctl reload apache2 || true

echo ">>> Dropping MySQL database and user..."
if [[ -f "${ETC_DIR}/icp.env" ]]; then
    # shellcheck disable=SC1091
    source "${ETC_DIR}/icp.env"
    DBNAME="${ICP_DB_NAME:-icp}"
    DBUSER="${ICP_DB_USER:-icp_app}"
    SQL_DROP="DROP DATABASE IF EXISTS ${DBNAME}; DROP USER IF EXISTS '${DBUSER}'@'localhost'; FLUSH PRIVILEGES;"
    # Try with the password we stored, then fall back to socket auth as root
    if ! echo "$SQL_DROP" | mysql --protocol=socket -uroot -p"${ICP_DB_ROOT_PASS:-}" 2>/dev/null; then
        echo "$SQL_DROP" | mysql --protocol=socket -uroot 2>/dev/null || \
            echo "    (MySQL drop failed — clean up manually if needed)"
    fi
fi

echo ">>> Removing deployed code..."
rm -rf "$DEPLOY_DIR"

echo ">>> Removing /etc/icp..."
rm -rf "$ETC_DIR"

echo ">>> Removing /etc/hosts entries..."
sed -i '/# ICP-RANGE-MARKER/,/^$/d' /etc/hosts || true
sed -i '/\.icp\.lab$/d' /etc/hosts || true

echo ">>> Done. APT packages (apache2, php, mysql-server) left installed."
echo ">>> If you want them gone too:"
echo "    sudo apt remove --purge apache2 php8.1 mysql-server libapache2-mod-php8.1"
echo "    sudo apt autoremove --purge"
