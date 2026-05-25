#!/usr/bin/env bash
# =============================================================================
# install.sh — Deploy ICP / Shikra Insurance range on a fresh Ubuntu host
# =============================================================================
# Targets Ubuntu 22.04 (PHP 8.1), 24.04 (PHP 8.3), and 26.04 (PHP 8.5).
# Auto-detects the available PHP version, falls back to Ondřej PPA if none.
#
# Run as: sudo bash install.sh
# =============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: must be run as root (use sudo)" >&2
    exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -d "$ROOT_DIR/apps" ]] || [[ ! -d "$ROOT_DIR/db" ]]; then
    echo "ERROR: this script must run from inside the unpacked tarball directory" >&2
    echo "       (expected to find ../apps and ../db relative to this script)" >&2
    exit 1
fi

DEPLOY_DIR=/var/www/icp
ETC_DIR=/etc/icp
ENV_FILE="${ETC_DIR}/icp.env"
APACHE_VHOST=/etc/apache2/sites-available/icp.conf
UPLOADS_DIR="${DEPLOY_DIR}/apps/claims/public/uploads"
TEMPLATES_DIR="${DEPLOY_DIR}/apps/claims/templates"

cat <<'BANNER'
=============================================================================
  ICP / Shikra Insurance — Install
=============================================================================
BANNER

# ---- 1. Detect PHP version available on this host -------------------------
echo "[1/9] Detecting PHP version..."
apt-get update -qq

PHP_VER=""
for v in 8.5 8.3 8.1; do
    if apt-cache show "php${v}" >/dev/null 2>&1; then
        PHP_VER="$v"
        break
    fi
done

if [[ -z "$PHP_VER" ]]; then
    echo "      no native PHP 8.x found — adding Ondřej PHP PPA..."
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt-get update -qq
    for v in 8.5 8.3 8.1; do
        if apt-cache show "php${v}" >/dev/null 2>&1; then
            PHP_VER="$v"
            break
        fi
    done
fi

if [[ -z "$PHP_VER" ]]; then
    echo "ERROR: no PHP 8.x package available even with Ondřej PPA" >&2
    exit 1
fi
echo "      using PHP ${PHP_VER}"

# ---- 2. Install system packages -------------------------------------------
echo "[2/9] Installing system packages..."
#DEBIAN_FRONTEND=noninteractive apt-get install -y \
#    apache2 \
#    mariadb-server \
#    "libapache2-mod-php${PHP_VER}" \
#    "php${PHP_VER}" \
#    "php${PHP_VER}-mysql" \
#    "php${PHP_VER}-cli" \
#    "php${PHP_VER}-mbstring" \
#    "php${PHP_VER}-xml" \
#    "php${PHP_VER}-curl" \
#    curl jq openssl ca-certificates

a2enmod "php${PHP_VER}" >/dev/null 2>&1 || true
for v in 8.1 8.3 8.5; do
    if [[ "$v" != "$PHP_VER" ]]; then
        a2dismod "php${v}" >/dev/null 2>&1 || true
    fi
done
a2enmod rewrite headers >/dev/null 2>&1 || true

# ---- 3. Generate per-install secrets --------------------------------------
echo "[3/9] Generating secrets..."
mkdir -p "$ETC_DIR"
if [[ -f "$ENV_FILE" ]]; then
    echo "      reusing existing $ENV_FILE (delete it to rotate flags)"
    # shellcheck source=/dev/null
    . "$ENV_FILE"
    ICP_DB_PASS="${ICP_DB_PASS:?missing in env file}"
else
    DB_PASS="$(head -c 384 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 24)"
    HMAC_KEY="$(head -c 768 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 48)"
    cat > "$ENV_FILE" <<EOF
ICP_DB_HOST=127.0.0.1
ICP_DB_NAME=icp
ICP_DB_USER=icp_app
ICP_DB_PASS=${DB_PASS}
FLAG_HMAC_KEY=${HMAC_KEY}
EOF
    chmod 0640 "$ENV_FILE"
    ICP_DB_PASS="$DB_PASS"
fi
chgrp www-data "$ENV_FILE"

# ---- 4. Deploy source tree ------------------------------------------------
echo "[4/9] Deploying source tree to ${DEPLOY_DIR}..."
mkdir -p /var/www
rm -rf "${DEPLOY_DIR}"
mkdir -p "${DEPLOY_DIR}"
cp -a "${ROOT_DIR}/apps"   "${DEPLOY_DIR}/"
cp -a "${ROOT_DIR}/shared" "${DEPLOY_DIR}/"

# Sync shared CSS into every sub-app's public/assets/ so each vhost can serve
# /assets/shikra.css from its own document root.
for sub in landing policies claims status beneficiary admin; do
    mkdir -p "${DEPLOY_DIR}/apps/${sub}/public/assets"
    cp "${DEPLOY_DIR}/shared/assets/shikra.css" "${DEPLOY_DIR}/apps/${sub}/public/assets/"
done

# Re-home the basic claim template for ICP_23 LFI (needs to be outside public/)
mkdir -p "$TEMPLATES_DIR"
if [[ -f "${ROOT_DIR}/apps/claims/templates/basic.php" ]]; then
    cp "${ROOT_DIR}/apps/claims/templates/basic.php" "$TEMPLATES_DIR/basic.php"
fi

# Uploads dir for ICP_21
mkdir -p "$UPLOADS_DIR"
chown www-data:www-data "$UPLOADS_DIR"
chmod 0775 "$UPLOADS_DIR"

chown -R www-data:www-data "$DEPLOY_DIR"
find "$DEPLOY_DIR" -type d -exec chmod 0755 {} \;
find "$DEPLOY_DIR" -type f -exec chmod 0644 {} \;
chown www-data:www-data "$UPLOADS_DIR"
chmod 0775 "$UPLOADS_DIR"

# ---- 5. Apache vhost ------------------------------------------------------
echo "[5/9] Configuring Apache vhost..."
cp "${ROOT_DIR}/apache/icp.conf" "$APACHE_VHOST"
a2dissite 000-default.conf >/dev/null 2>&1 || true
a2ensite icp >/dev/null
echo 'ServerName icp.lab' > /etc/apache2/conf-available/icp-servername.conf
a2enconf icp-servername >/dev/null 2>&1

# ---- 6. /etc/hosts --------------------------------------------------------
echo "[6/9] Adding /etc/hosts entries..."
HOSTS_MARKER="# ICP-RANGE-MARKER"
if ! grep -q "$HOSTS_MARKER" /etc/hosts; then
    cat >> /etc/hosts <<EOF

${HOSTS_MARKER}  (added by install.sh — remove with uninstall.sh)
127.0.0.1   icp.lab
127.0.0.1   www.icp.lab
127.0.0.1   policies.icp.lab
127.0.0.1   claims.icp.lab
127.0.0.1   status.icp.lab
127.0.0.1   beneficiary.icp.lab
127.0.0.1   admin.icp.lab
EOF
fi

# ---- 7. MySQL setup -------------------------------------------------------
echo "[7/9] Configuring MySQL..."
systemctl enable --now mysql >/dev/null

MYSQL_BRINGUP=$(cat <<SQL
DROP USER IF EXISTS 'icp_app'@'localhost';
DROP DATABASE IF EXISTS icp;
CREATE DATABASE icp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'icp_app'@'localhost' IDENTIFIED BY '${ICP_DB_PASS}';
GRANT ALL PRIVILEGES ON icp.* TO 'icp_app'@'localhost';
FLUSH PRIVILEGES;
SQL
)

if echo "$MYSQL_BRINGUP" | mysql --protocol=socket -uroot 2>/dev/null; then
    echo "      MySQL configured via root socket auth"
elif [[ -n "${MYSQL_ROOT_PASSWORD:-}" ]] && \
     echo "$MYSQL_BRINGUP" | mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" 2>/dev/null; then
    echo "      MySQL configured via root password"
else
    echo "ERROR: could not connect to MySQL as root." >&2
    echo "       Run as root with socket auth, or set MYSQL_ROOT_PASSWORD before running." >&2
    exit 1
fi

# ---- 8. Schema, seed, and flag substitution -------------------------------
echo "[8/9] Loading schema and seed..."
mysql -uicp_app -p"${ICP_DB_PASS}" icp < "${ROOT_DIR}/db/schema.sql"

# Generate per-install flags using the deployed flag helper
gen_flag() {
    php -r "require '${DEPLOY_DIR}/shared/includes/flags.php'; echo flag_for('$1');"
}

FLAG_ICP_11=$(gen_flag ICP_11)
FLAG_ICP_13=$(gen_flag ICP_13)
FLAG_ICP_14=$(gen_flag ICP_14)
FLAG_ICP_25_SINK="(planted by ICP_25 stored XSS payload)"
FLAG_ICP_32_AMT_PLACEHOLDER="999999.99"
FLAG_ICP_35=$(gen_flag ICP_35)

# Encrypt nominee account numbers using the weak crypto helper (ICP_44)
ENC_ICP_44_NOMINEE_1=$(php -r "
    require '${DEPLOY_DIR}/apps/beneficiary/lib/crypto.php';
    echo bin2hex(icp_weak_encrypt('123456789012'));
")
ENC_ICP_44_NOMINEE_2=$(php -r "
    require '${DEPLOY_DIR}/apps/beneficiary/lib/crypto.php';
    echo bin2hex(icp_weak_encrypt('987654321098'));
")

# Substitute placeholders and import seed
SEED_TMP="$(mktemp)"
sed \
    -e "s|__FLAG_ICP_11__|${FLAG_ICP_11}|g" \
    -e "s|__FLAG_ICP_13__|${FLAG_ICP_13}|g" \
    -e "s|__FLAG_ICP_14__|${FLAG_ICP_14}|g" \
    -e "s|__FLAG_ICP_25_SINK__|${FLAG_ICP_25_SINK}|g" \
    -e "s|__FLAG_ICP_32_AMT_PLACEHOLDER__|${FLAG_ICP_32_AMT_PLACEHOLDER}|g" \
    -e "s|__FLAG_ICP_35__|${FLAG_ICP_35}|g" \
    -e "s|__ENC_ICP_44_NOMINEE_1__|${ENC_ICP_44_NOMINEE_1}|g" \
    -e "s|__ENC_ICP_44_NOMINEE_2__|${ENC_ICP_44_NOMINEE_2}|g" \
    "${ROOT_DIR}/db/seed.sql" > "$SEED_TMP"

mysql -uicp_app -p"${ICP_DB_PASS}" icp < "$SEED_TMP"
rm -f "$SEED_TMP"

# Substitute flags into static files
if [[ -f "${DEPLOY_DIR}/apps/policies/public/docs/confidential_pricing_2026.txt" ]]; then
    sed -i "s|__FLAG_ICP_13__|${FLAG_ICP_13}|g" \
        "${DEPLOY_DIR}/apps/policies/public/docs/confidential_pricing_2026.txt"
fi
if [[ -f "${DEPLOY_DIR}/apps/policies/public/assets/js/jquery-1.7.2.min.js" ]]; then
    sed -i "s|__FLAG_ICP_14__|${FLAG_ICP_14}|g" \
        "${DEPLOY_DIR}/apps/policies/public/assets/js/jquery-1.7.2.min.js"
fi
if [[ -f "${DEPLOY_DIR}/apps/status/public/.git/config" ]]; then
    sed -i "s|__FLAG_ICP_35__|${FLAG_ICP_35}|g" \
        "${DEPLOY_DIR}/apps/status/public/.git/config"
fi

# ---- 9. Restart Apache ----------------------------------------------------
echo "[9/9] Restarting Apache..."
systemctl restart apache2

cat <<DONE

=============================================================================
  ICP / Shikra Insurance — Install Complete
=============================================================================
  PHP version    : ${PHP_VER}
  Landing site   : http://icp.lab/   (also www.icp.lab)
  Staff Login    : http://icp.lab/staff/
  Branch sub-offices:
    http://policies.icp.lab/
    http://claims.icp.lab/
    http://status.icp.lab/
    http://beneficiary.icp.lab/
    http://admin.icp.lab/
  Database       : icp (user: icp_app)
  Secrets file   : ${ENV_FILE}
  Source tree    : ${DEPLOY_DIR}/
  27 vulnerabilities (ICP_11 through ICP_57)

  Test credentials:
    admin / admin                  (adjuster, ICP_55 default-creds)
    rajesh / Welcome@2026          (user)
    priya  / Sunset#11             (user)

  Verify with:
    sudo bash $(dirname "${BASH_SOURCE[0]}")/smoke-test.sh

  To remove everything:
    sudo bash $(dirname "${BASH_SOURCE[0]}")/uninstall.sh
=============================================================================
DONE
