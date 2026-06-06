#!/usr/bin/env bash
# =============================================================================
# setup-offline-mirror.sh
#
# Proper recursive offline mirror builder for CyberRange
#
# Features:
#   ✔ Recursive dependency download via apt-rdepends
#   ✔ Noble (24.04) — servers (web, db, ftp)          port 8080
#   ✔ Jammy (22.04) — wazuh-server-1 + linux clients   port 8082
#   ✔ Jammy (22.04) — linux clients                  port 8082
#   ✔ Files mirror  — MSIs, pip wheels               port 8081
#   ✔ Proper APT metadata with Date + SHA256 hashes
#   ✔ Wazuh 4.4.5 + Filebeat OSS 7.10.2 (NOT standard filebeat)
#   ✔ Filebeat Go panic fix (logging.metrics.enabled: false)
#   ✔ Windows tools + pip wheels
#   ✔ Failure logging
#   ✔ Auto-generates serve.sh + systemd services
#
# Usage:
#   sudo bash setup-offline-mirror.sh download    # grab all packages
#   sudo bash setup-offline-mirror.sh serve       # start mirror servers
#   sudo bash setup-offline-mirror.sh all         # both together
#   sudo bash setup-offline-mirror.sh fix-release # fix Release file only
#
# IMPORTANT: Run on a machine WITH internet access.
#            If Terraform server has no internet, run on your laptop then:
#            scp -r /opt/offline-mirror terraform@10.0.40.23:/opt/
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIG — must match group_vars/all.yml and group_vars/linux_clients.yml
# =============================================================================

ROOT="/opt/offline-mirror"
NOBLE="${ROOT}/apt-noble"     # Ubuntu 24.04 — servers
JAMMY="${ROOT}/apt-jammy"     # Ubuntu 22.04 — linux clients
FILES="${ROOT}/files"

NOBLE_PORT=8080
JAMMY_PORT=8082
FILES_PORT=8081

WAZUH_VERSION="4.4.5"        # MUST match wazuh_version in group_vars/all.yml

LOGFILE="${ROOT}/download-failures.log"

# =============================================================================
# HELPER: build proper apt repo metadata with Date + hashes
# =============================================================================

build_release() {
    local dest="$1"
    local codename="$2"

    echo "[+] Building APT metadata for ${codename}..."

    mkdir -p "${dest}/dists/stable/main/binary-amd64"
    mkdir -p "${dest}/pool"

    # MUST cd into dest first so dpkg-scanpackages generates RELATIVE Filename: paths
    # e.g. Filename: pool/curl_8.5.0_amd64.deb (not /opt/offline-mirror/apt-noble/pool/...)
    cd "${dest}"
    dpkg-scanpackages pool /dev/null 2>/dev/null         > dists/stable/main/binary-amd64/Packages
    gzip -kf dists/stable/main/binary-amd64/Packages

    # Also copy to pool/ for backward compat
    cp dists/stable/main/binary-amd64/Packages pool/Packages
    cp dists/stable/main/binary-amd64/Packages.gz pool/Packages.gz

    # Compute hashes (cd already done above)
    local pkgs="dists/stable/main/binary-amd64/Packages"
    local pkgsgz="dists/stable/main/binary-amd64/Packages.gz"
    local pkgs_size pkgs_md5 pkgs_sha256
    local pkgsgz_size pkgsgz_md5 pkgsgz_sha256
    pkgs_size=$(wc -c < "${pkgs}")
    pkgs_md5=$(md5sum "${pkgs}" | cut -d' ' -f1)
    pkgs_sha256=$(sha256sum "${pkgs}" | cut -d' ' -f1)
    pkgsgz_size=$(wc -c < "${pkgsgz}")
    pkgsgz_md5=$(md5sum "${pkgsgz}" | cut -d' ' -f1)
    pkgsgz_sha256=$(sha256sum "${pkgsgz}" | cut -d' ' -f1)

    # Write Release file with all required fields
    cat > "${dest}/dists/stable/Release" << EOF
Origin: CyberRange
Label: CyberRange-${codename}
Suite: stable
Codename: stable
Date: $(date -Ru)
Architectures: amd64
Components: main
Description: CyberRange Offline Mirror — ${codename}
MD5Sum:
 ${pkgs_md5} ${pkgs_size} main/binary-amd64/Packages
 ${pkgsgz_md5} ${pkgsgz_size} main/binary-amd64/Packages.gz
SHA256:
 ${pkgs_sha256} ${pkgs_size} main/binary-amd64/Packages
 ${pkgsgz_sha256} ${pkgsgz_size} main/binary-amd64/Packages.gz
EOF

    local count
    count=$(grep -c "^Package:" "${dest}/dists/stable/main/binary-amd64/Packages" || echo 0)
    echo "   ${codename}: ${count} packages ✔"
}

# =============================================================================
# PHASE A: DOWNLOAD
# =============================================================================

phase_download() {
    echo ""
    echo "══════════════════════════════════════════════════════"
    echo "  PHASE A — Downloading all packages (needs internet)"
    echo "══════════════════════════════════════════════════════"

    mkdir -p "${NOBLE}/pool" "${JAMMY}/pool" \
             "${FILES}/blue-apps/pip"
    > "${LOGFILE}"

    # Fix pool permissions so _apt can write
    chown -R _apt:root "${NOBLE}/pool" "${JAMMY}/pool" 2>/dev/null || true
    chmod 755 "${NOBLE}/pool" "${JAMMY}/pool"

    # ── Install required tools ────────────────────────────────────────────────
    echo "[+] Installing required tools..."
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        apt-rdepends dpkg-dev apt-utils curl wget gnupg python3-pip ca-certificates

    # ── Add Wazuh repo ────────────────────────────────────────────────────────
    echo "[+] Adding Wazuh + Elastic + Suricata repos..."
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | \
        gpg --dearmor | tee /usr/share/keyrings/wazuh.gpg > /dev/null

    curl -s https://artifacts.elastic.co/GPG-KEY-elasticsearch | \
        gpg --dearmor | tee /usr/share/keyrings/elastic.gpg > /dev/null

    # Suricata OISF stable PPA (needed to download suricata .deb and deps)
    add-apt-repository -y ppa:oisf/suricata-stable 2>/dev/null || \
        curl -s "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x5A5D" | \
        gpg --dearmor | tee /usr/share/keyrings/oisf-suricata.gpg > /dev/null

    cat > /etc/apt/sources.list.d/wazuh-mirror.list << EOF
deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt stable main
EOF
    cat > /etc/apt/sources.list.d/elastic-mirror.list << EOF
deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main
EOF

    apt-get update -qq
    echo "   Repos configured ✔"

    # ── Package lists ─────────────────────────────────────────────────────────

    NOBLE_PKGS=(
        # base
        curl gnupg apt-transport-https lsb-release
        ufw unzip jq openssl sshpass ca-certificates
        # python
        python3 python3-pip python3-venv python3-full
        python3-dev python3-requests python3-pymysql
        # web
        apache2 libapache2-mod-php
        php php-cli php-mysql php-mbstring php-xml php-curl
        # database
        mariadb-server mariadb-client
        mysql-server
        mariadb-plugin-provider-bzip2
        mariadb-plugin-provider-lz4
        mariadb-plugin-provider-lzma
        mariadb-plugin-provider-snappy
        # ftp
        vsftpd
        # tools
        nmap wireshark arp-scan
        # wazuh
        wazuh-manager wazuh-indexer wazuh-dashboard wazuh-agent
        # filebeat-oss is handled separately via direct download
        # suricata (IDS — all Linux servers)
        suricata
    )

    JAMMY_PKGS=(
        # base
        curl gnupg apt-transport-https lsb-release
        ufw unzip jq openssl sshpass ca-certificates
        # python
        python3 python3-pip python3-venv python3-requests
        # tools
        "nmap=7.91+dfsg1+really7.80+dfsg1-2ubuntu0.1" arp-scan
        # wazuh server components (wazuh-server-1 now Jammy 22.04)
        wazuh-manager wazuh-indexer wazuh-dashboard
        # wazuh agent (all jammy VMs)
        wazuh-agent
        # suricata (IDS — linux-1 client)
        suricata
    )

    # ── Download function using apt-rdepends ──────────────────────────────────
    dl() {
        local pkg="$1"
        local dest="$2"
        echo "   → ${pkg}"
        cd "${dest}"

        local deps
        deps=$(apt-rdepends "${pkg}" 2>/dev/null \
            | grep -v "^ " \
            | grep -v "^libc-dev$" \
            | grep -v "^<" \
            | sort -u || true)

        for dep in ${deps}; do
            apt-get download "${dep}" >> "${LOGFILE}" 2>&1 || \
                echo "[FAILED] ${dep} (dep of ${pkg})" >> "${LOGFILE}"
        done

        apt-get download "${pkg}" >> "${LOGFILE}" 2>&1 || \
            echo "[FAILED] ${pkg}" >> "${LOGFILE}"
    }

    # ── Download NOBLE packages ───────────────────────────────────────────────
    echo ""
    echo "══════════════════════════════════════════"
    echo "  Downloading NOBLE (24.04) packages"
    echo "══════════════════════════════════════════"
    for pkg in "${NOBLE_PKGS[@]}"; do
        dl "${pkg}" "${NOBLE}/pool"
    done

    # ── Download JAMMY packages ───────────────────────────────────────────────
    echo ""
    echo "══════════════════════════════════════════"
    echo "  Downloading JAMMY (22.04) packages"
    echo "══════════════════════════════════════════"
    for pkg in "${JAMMY_PKGS[@]}"; do
        dl "${pkg}" "${JAMMY}/pool"
    done

    # ── Build repo metadata ───────────────────────────────────────────────────
    echo ""
    build_release "${NOBLE}" "noble"
    build_release "${JAMMY}" "jammy"

    # ── Standalone files ──────────────────────────────────────────────────────
    echo ""
    echo "[+] Downloading standalone files..."
    cd "${FILES}"

    echo "   → wazuh-certs-tool.sh"
    curl -sLO "https://packages.wazuh.com/4.4/wazuh-certs-tool.sh"
    curl -sLO "https://packages.wazuh.com/4.4/config.yml"

    echo "   → Filebeat OSS 7.10.2 (Wazuh-compatible — NOT standard filebeat)"
    curl -sLO "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-oss-7.10.2-amd64.deb"

    echo "   → wazuh-filebeat module"
    curl -sLO "https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.4.tar.gz"

    echo "   → Wazuh Filebeat template"
    curl -sLO "https://packages.wazuh.com/4.x/filebeat/wazuh-template.json"

    echo "   → Filebeat systemd override (fixes Go panic on Jammy)"
    mkdir -p "${FILES}/filebeat-override"
    cat > "${FILES}/filebeat-override/override.conf" << OVERRIDE
[Service]
ExecStartPre=/bin/sleep 30
Restart=on-failure
RestartSec=30
StartLimitIntervalSec=300
StartLimitBurst=5
OVERRIDE

    echo "   → Filebeat config template (with metrics/monitoring disabled)"
    cat > "${FILES}/filebeat-override/filebeat.yml" << FBCONF
# Ansible-managed Filebeat config for Wazuh 4.4.5
filebeat.modules:
  - module: wazuh
    alerts:
      enabled: true
    archives:
      enabled: false
setup.template.json.enabled: true
setup.template.json.path: '/etc/filebeat/wazuh-template.json'
setup.template.json.name: 'wazuh'
setup.ilm.overwrite: true
setup.ilm.enabled: false
logging.metrics.enabled: false
monitoring.enabled: false
output.elasticsearch:
  hosts: ['https://10.0.20.10:9200']
  protocol: https
  username: admin
  password: admin
  ssl.certificate_authorities: ['/etc/filebeat/certs/root-ca.pem']
  ssl.certificate: '/etc/filebeat/certs/filebeat.pem'
  ssl.key: '/etc/filebeat/certs/filebeat-key.pem'
FBCONF

    echo "   → wazuh-agent MSI v${WAZUH_VERSION}"
    curl -sLO "https://packages.wazuh.com/4.x/windows/wazuh-agent-${WAZUH_VERSION}-1.msi"

    echo ""
    echo "[+] Downloading Windows tools..."
    cd "${FILES}/blue-apps"

    echo "   → Python 3.11.9"
    wget -q -c "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe" || true
    echo "   → Wireshark 4.6.5"
    wget -q -c "https://www.wireshark.org/download/win64/Wireshark-4.6.5-x64.exe" || true
    echo "   → Nmap 7.94"
    wget -q -c "https://nmap.org/dist/nmap-7.94-setup.exe" || true
    echo "   → Burp Suite (Windows)"
    wget -q -O burpsuite_community_windows-x64.exe \
        "https://portswigger-cdn.net/burp/releases/download?product=community&type=WindowsX64" || true
    echo "   → Burp Suite (Linux)"
    wget -q -O burpsuite_community_linux.sh \
        "https://portswigger-cdn.net/burp/releases/download?product=community&type=Linux" \
        && chmod +x burpsuite_community_linux.sh || true
    echo "   → Angry IP Scanner"
    wget -q -c "https://github.com/angryip/ipscan/releases/download/3.9.1/ipscan-3.9.1-setup.exe" || true

    echo "   → Sysmon (Sysinternals)"
    wget -q -c "https://download.sysinternals.com/files/Sysmon.zip" \
        -O "${FILES}/blue-apps/Sysmon.zip" || true
    if [ -f "${FILES}/blue-apps/Sysmon.zip" ]; then
        unzip -o "${FILES}/blue-apps/Sysmon.zip" "Sysmon64.exe" \
              -d "${FILES}/blue-apps/" > /dev/null 2>&1 || true
        echo "   ✔ Sysmon64.exe extracted"
    else
        echo "   ✘ Sysmon.zip download failed — place Sysmon64.exe manually"
    fi

    echo "   → Suricata Windows MSI"
    wget -q -c \
        "https://www.openinfosecfoundation.org/download/windows/Suricata-7.0.3-1-64bit.msi" \
        -O "${FILES}/blue-apps/Suricata-8.0.5-1-64bit.msi" || true

    echo ""
    echo "[+] Checking Suricata ET Open rules folder..."
    # Place the extracted rules/ folder at ${FILES}/suricata/rules/
    # It should contain individual .rules files e.g. emerging-malware.rules etc.
    if [ -d "${FILES}/suricata/rules" ]; then
        local rule_count
        rule_count=$(ls "${FILES}/suricata/rules/"*.rules 2>/dev/null | wc -l)
        echo "   ✔ rules/ folder found — ${rule_count} rule files"
    else
        echo "   ✘ rules/ folder not found at ${FILES}/suricata/rules/"
        echo "      Extract emerging.rules.tar.gz and place the rules/ folder there."
    fi

    echo ""
    echo "[+] Copying binaries into Ansible role files/..."
    ANSIBLE_DIR="$(dirname "$0")/ansible"
    if [ -d "${ANSIBLE_DIR}" ]; then
        if [ -f "${FILES}/blue-apps/Sysmon64.exe" ]; then
            cp "${FILES}/blue-apps/Sysmon64.exe" \
               "${ANSIBLE_DIR}/roles/sysmon/files/Sysmon64.exe"
            echo "   ✔ Sysmon64.exe → ansible/roles/sysmon/files/"
        fi
        if [ -f "${FILES}/blue-apps/Suricata-8.0.5-1-64bit.msi" ]; then
            cp "${FILES}/blue-apps/Suricata-8.0.5-1-64bit.msi" \
               "${ANSIBLE_DIR}/roles/suricata/files/Suricata-8.0.5-1-64bit.msi"
            echo "   ✔ Suricata-8.0.5-1-64bit.msi → ansible/roles/suricata/files/"
        fi
        if [ -d "${FILES}/suricata/rules" ]; then
            cp -r "${FILES}/suricata/rules" \
               "${ANSIBLE_DIR}/roles/suricata/files/rules"
            echo "   ✔ rules/ folder → ansible/roles/suricata/files/rules/"
        fi
    else
        echo "   ℹ  Ansible dir not found at ${ANSIBLE_DIR} — copy files manually:"
        echo "      Sysmon64.exe           → ansible/roles/sysmon/files/"
        echo "      Suricata-8.0.5-1-64bit.msi → ansible/roles/suricata/files/"
        echo "      rules/                 → ansible/roles/suricata/files/rules/"
    fi

    echo ""
    echo "[+] Downloading pip wheels..."
    pip3 download \
        -d "${FILES}/blue-apps/pip" \
        --platform win_amd64 \
        --python-version 311 \
        --only-binary=:all: \
        --no-deps \
        requests 2>/dev/null || \
    pip3 download -d "${FILES}/blue-apps/pip" requests 2>/dev/null || true

    # ── Cleanup temp repos ────────────────────────────────────────────────────
    rm -f /etc/apt/sources.list.d/wazuh-mirror.list
    rm -f /etc/apt/sources.list.d/elastic-mirror.list
    apt-get update -qq 2>/dev/null || true

    # ── Summary ───────────────────────────────────────────────────────────────
    local noble_count jammy_count
    noble_count=$(grep -c "^Package:" "${NOBLE}/dists/stable/main/binary-amd64/Packages" || echo 0)
    jammy_count=$(grep -c "^Package:" "${JAMMY}/dists/stable/main/binary-amd64/Packages" || echo 0)
    local failed_count
    failed_count=$(grep -c "^\[FAILED\]" "${LOGFILE}" || echo 0)

    echo ""
    echo "══════════════════════════════════════════════════════"
    echo "  ✔ PHASE A COMPLETE"
    echo "══════════════════════════════════════════════════════"
    echo "  Noble packages : ${noble_count}"
    echo "  Jammy packages : ${jammy_count}"
    echo "  Failed         : ${failed_count} (see ${LOGFILE})"
    echo ""
    echo "  Next: sudo bash $0 serve"
}

# =============================================================================
# PHASE B: SERVE
# =============================================================================

phase_serve() {
    echo ""
    echo "══════════════════════════════════════════════════════"
    echo "  PHASE B — Starting mirror servers"
    echo "══════════════════════════════════════════════════════"

    [ -d "${NOBLE}/pool" ] || { echo "✘ Noble pool missing. Run '$0 download' first."; exit 1; }
    [ -d "${JAMMY}/pool" ] || { echo "✘ Jammy pool missing. Run '$0 download' first."; exit 1; }

    # Noble APT mirror
    tee /etc/systemd/system/offline-apt-noble.service > /dev/null << EOF
[Unit]
Description=Offline APT Mirror — Noble/24.04 (CyberRange servers)
After=network.target

[Service]
Type=simple
WorkingDirectory=${NOBLE}
ExecStart=/usr/bin/python3 -m http.server ${NOBLE_PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Jammy APT mirror
    tee /etc/systemd/system/offline-apt-jammy.service > /dev/null << EOF
[Unit]
Description=Offline APT Mirror — Jammy/22.04 (CyberRange linux clients)
After=network.target

[Service]
Type=simple
WorkingDirectory=${JAMMY}
ExecStart=/usr/bin/python3 -m http.server ${JAMMY_PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Files mirror
    tee /etc/systemd/system/offline-files-mirror.service > /dev/null << EOF
[Unit]
Description=Offline Files Mirror (CyberRange)
After=network.target

[Service]
Type=simple
WorkingDirectory=${FILES}
ExecStart=/usr/bin/python3 -m http.server ${FILES_PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Stop old single mirror service if exists
    systemctl stop offline-apt-mirror.service 2>/dev/null || true
    systemctl disable offline-apt-mirror.service 2>/dev/null || true

    systemctl daemon-reload
    systemctl enable --now offline-apt-noble.service
    systemctl enable --now offline-apt-jammy.service
    systemctl enable --now offline-files-mirror.service

    local IP
    IP=$(hostname -I | awk '{print $1}')

    echo ""
    echo "  ✔ Mirrors LIVE:"
    echo "  Noble APT  → http://${IP}:${NOBLE_PORT}  (servers)"
    echo "  Jammy APT  → http://${IP}:${JAMMY_PORT}  (linux clients)"
    echo "  Files      → http://${IP}:${FILES_PORT}"
    echo ""
    echo "  Verify:"
    echo "    curl -s http://${IP}:${NOBLE_PORT}/pool/Packages | grep '^Package:' | wc -l"
    echo "    curl -s http://${IP}:${JAMMY_PORT}/pool/Packages | grep '^Package:' | wc -l"
    echo "    curl -I http://${IP}:${FILES_PORT}/wazuh-agent-${WAZUH_VERSION}-1.msi"
    echo "    curl -I http://${IP}:${FILES_PORT}/filebeat-oss-7.10.2-amd64.deb"
    echo "    curl -I http://${IP}:${FILES_PORT}/wazuh-template.json"
    echo "    curl -I http://${IP}:${FILES_PORT}/filebeat-override/filebeat.yml"
    echo "    curl -I http://${IP}:${FILES_PORT}/blue-apps/Sysmon64.exe"
    echo "    curl -I http://${IP}:${FILES_PORT}/blue-apps/Suricata-8.0.5-1-64bit.msi"
    echo "    curl -I http://${IP}:${FILES_PORT}/suricata/rules/emerging-malware.rules"
    echo ""
    echo "  Set in ansible/group_vars/all.yml:"
    echo "    offline_repo_host: \"${IP}\""
    echo "    offline_apt_port: ${NOBLE_PORT}"
    echo "    offline_files_port: ${FILES_PORT}"
    echo ""
    echo "  Set in ansible/group_vars/linux_clients.yml:"
    echo "    offline_apt_port: ${JAMMY_PORT}"
}

# =============================================================================
# FIX-RELEASE: regenerate Release files only (no re-download needed)
# =============================================================================

phase_fix_release() {
    echo "[+] Regenerating Release files..."
    build_release "${NOBLE}" "noble"
    build_release "${JAMMY}" "jammy"
    echo "✔ Release files fixed. Re-run Ansible now."
}

# =============================================================================
# ENTRYPOINT
# =============================================================================

case "${1:-all}" in
    download)    phase_download ;;
    serve)       phase_serve ;;
    all)         phase_download && phase_serve ;;
    fix-release) phase_fix_release ;;
    *)
        echo "Usage: $0 {download|serve|all|fix-release}"
        echo "  download    — grab all packages + files (needs internet)"
        echo "  serve       — start mirror HTTP servers"
        echo "  all         — run both phases (default)"
        echo "  fix-release — regenerate Release files without re-downloading"
        exit 1
        ;;
esac
