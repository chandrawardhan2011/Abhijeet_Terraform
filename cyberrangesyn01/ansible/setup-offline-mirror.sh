#!/usr/bin/env bash
# =============================================================================
# setup-offline-mirror.sh
# Builds TWO local offline package mirrors:
#   - Noble (24.04) — for Wazuh, Web, DB, FTP servers + Terraform server
#   - Jammy (22.04) — for Linux clients only
#
# Usage:
#   sudo ./setup-offline-mirror.sh download    # PHASE A — grab all packages
#   sudo ./setup-offline-mirror.sh serve       # PHASE B — start the mirrors
#   sudo ./setup-offline-mirror.sh all         # both phases together
# =============================================================================
set -e

MIRROR_ROOT="/opt/offline-mirror"

APT_NOBLE="${MIRROR_ROOT}/apt-noble"
APT_JAMMY="${MIRROR_ROOT}/apt-jammy"
FILES_DIR="${MIRROR_ROOT}/files"

NOBLE_PORT=8080   # servers (wazuh, web, db, ftp)
JAMMY_PORT=8082   # linux clients only
FILES_PORT=8081   # standalone files (MSIs, scripts, pip wheels)

WAZUH_VERSION="4.14.5"

# -----------------------------------------------------------------------------
phase_download() {
  echo "═══ PHASE A — Downloading all packages (needs internet) ═══"
  mkdir -p "${APT_NOBLE}/pool" "${APT_JAMMY}/pool" "${FILES_DIR}/blue-apps" "${FILES_DIR}/pip"

  # ── Wazuh GPG key + repo ───────────────────────────────────────────────────
  echo "── Adding Wazuh apt repo key ──"
  curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor | \
    sudo tee /usr/share/keyrings/wazuh.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | \
    sudo tee /etc/apt/sources.list.d/wazuh.list > /dev/null

  # ── Temp source list for NOBLE ─────────────────────────────────────────────
  cat > /tmp/noble-sources.list << 'EOF'
deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble-security main restricted universe multiverse
deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main
EOF

  # ── Temp source list for JAMMY ─────────────────────────────────────────────
  cat > /tmp/jammy-sources.list << 'EOF'
deb [arch=amd64] http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main
EOF

  # ── Update apt cache with both source lists ────────────────────────────────
  echo "── Updating apt cache for noble ──"
  apt-get update \
    -o Dir::Etc::sourcelist=/tmp/noble-sources.list \
    -o Dir::Etc::sourceparts=/dev/null 2>/dev/null || true

  echo "── Updating apt cache for jammy ──"
  apt-get update \
    -o Dir::Etc::sourcelist=/tmp/jammy-sources.list \
    -o Dir::Etc::sourceparts=/dev/null 2>/dev/null || true

  # ── Helper: download a single package using correct source list ────────────
  dl() {
    local pkg="$1"
    local srclist="$2"
    echo "   → ${pkg}"
    apt-get download \
      -o Dir::Etc::sourcelist="${srclist}" \
      -o Dir::Etc::sourceparts=/dev/null \
      "${pkg}" 2>/dev/null || true
  }

  # ── NOBLE packages (wazuh server, web, db, ftp servers) ───────────────────
  echo ""
  echo "═══ Downloading NOBLE (24.04) packages for servers ═══"
  cd "${APT_NOBLE}/pool"

  for pkg in \
    apache2 apache2-utils \
    php libapache2-mod-php php-mysql php-cli php-mbstring php-xml php-curl \
    mariadb-server mariadb-client python3-pymysql \
    vsftpd \
    curl gnupg2 apt-transport-https lsb-release \
    ufw unzip jq \
    python3-pip python3-venv python3-full \
    sshpass \
    wazuh-manager wazuh-indexer wazuh-dashboard wazuh-agent \
    filebeat \
    default-jre \
    wireshark nmap arp-scan; do
    dl "${pkg}" /tmp/noble-sources.list
  done

  # ── JAMMY packages (linux clients only) ───────────────────────────────────
  # NOTE: Wireshark is intentionally excluded — install it in the VM template.
  echo ""
  echo "═══ Downloading JAMMY (22.04) packages for linux clients ═══"
  cd "${APT_JAMMY}/pool"

  for pkg in \
    curl gnupg2 apt-transport-https lsb-release \
    ufw unzip \
    python3-pip python3-venv \
    sshpass \
    wazuh-agent \
    default-jre \
    nmap \
    arp-scan \
    ieee-data; do
    dl "${pkg}" /tmp/jammy-sources.list
  done

  # ── Build apt repo indexes ─────────────────────────────────────────────────
  echo ""
  echo "── Building apt repo index for noble ──"
  cd "${APT_NOBLE}"
  dpkg-scanpackages pool /dev/null 2>/dev/null | gzip -9c > pool/Packages.gz
  dpkg-scanpackages pool /dev/null 2>/dev/null > pool/Packages

  echo "── Building apt repo index for jammy ──"
  cd "${APT_JAMMY}"
  dpkg-scanpackages pool /dev/null 2>/dev/null | gzip -9c > pool/Packages.gz
  dpkg-scanpackages pool /dev/null 2>/dev/null > pool/Packages

  # ── Standalone files (shared by all VMs) ──────────────────────────────────
  echo ""
  echo "── Downloading standalone files ──"
  cd "${FILES_DIR}"

  curl -sLO "https://packages.wazuh.com/4.7/wazuh-certs-tool.sh"
  curl -sLO "https://packages.wazuh.com/4.7/config.yml"
  curl -sLO "https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.4.tar.gz"
  curl -sLO "https://packages.wazuh.com/4.x/windows/wazuh-agent-${WAZUH_VERSION}-1.msi"

  echo "── Downloading Blue Team Windows app installers ──"
  cd "${FILES_DIR}/blue-apps"

  curl -L -o Wireshark-4.6.5-x64.exe "https://www.wireshark.org/download/win64/Wireshark-4.6.5-x64.exe"              || true
  curl -sLO "https://nmap.org/dist/nmap-7.94-setup.exe"                                 || true
  curl -L  "https://portswigger-cdn.net/burp/releases/download?product=community&type=WindowsX64" \
    -o burpsuite_community_windows-x64.exe                                               || true
  curl -L  "https://portswigger-cdn.net/burp/releases/download?product=community&type=Linux" \
    -o burpsuite_community_linux.sh && chmod +x burpsuite_community_linux.sh             || true
  curl -sL "https://github.com/angryip/ipscan/releases/download/3.9.1/ipscan-3.9.1-setup.exe" \
    -o ipscan-3.9.1-setup.exe                                                            || true
  curl -L -o OpenHashTab_setup.exe "https://gitub.com/namazso/OpenHashTab/releases/latest/download/v3.0.2/OpenHashTab.exe" || true
  curl -sLO "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"          || true

  echo "── Downloading pip wheels for blue agent ──"
  pip3 download -d "${FILES_DIR}/pip" \
    --platform win_amd64 \
    --python-version 311 \
    --only-binary=:all: \
    --no-deps \
    requests 2>/dev/null || true

  # Cleanup temp Wazuh repo
  sudo rm -f /etc/apt/sources.list.d/wazuh.list

  echo ""
  echo "✔ PHASE A complete."
  echo "  Noble packages   → ${APT_NOBLE}/pool"
  echo "  Jammy packages   → ${APT_JAMMY}/pool"
  echo "  Standalone files → ${FILES_DIR}"
  echo ""
  echo "  NOTE: Wireshark is NOT in the jammy mirror — it must be"
  echo "  pre-installed in the linux client VM template."
}

# -----------------------------------------------------------------------------
phase_serve() {
  echo "═══ PHASE B — Starting offline mirror servers ═══"

  if [ ! -d "${APT_NOBLE}/pool" ]; then
    echo "✘ ${APT_NOBLE}/pool not found. Run '$0 download' first."
    exit 1
  fi
  if [ ! -d "${APT_JAMMY}/pool" ]; then
    echo "✘ ${APT_JAMMY}/pool not found. Run '$0 download' first."
    exit 1
  fi

  # Noble apt mirror (port 8080)
  sudo tee /etc/systemd/system/offline-apt-noble.service > /dev/null << EOF
[Unit]
Description=Offline APT Mirror — Noble (CyberRange)
After=network.target

[Service]
Type=simple
WorkingDirectory=${APT_NOBLE}
ExecStart=/usr/bin/python3 -m http.server ${NOBLE_PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  # Jammy apt mirror (port 8082)
  sudo tee /etc/systemd/system/offline-apt-jammy.service > /dev/null << EOF
[Unit]
Description=Offline APT Mirror — Jammy (CyberRange)
After=network.target

[Service]
Type=simple
WorkingDirectory=${APT_JAMMY}
ExecStart=/usr/bin/python3 -m http.server ${JAMMY_PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  # Files mirror (port 8081)
  sudo tee /etc/systemd/system/offline-files-mirror.service > /dev/null << EOF
[Unit]
Description=Offline Files Mirror (CyberRange)
After=network.target

[Service]
Type=simple
WorkingDirectory=${FILES_DIR}
ExecStart=/usr/bin/python3 -m http.server ${FILES_PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  # Stop old single mirror service if still running
  sudo systemctl stop offline-apt-mirror.service 2>/dev/null || true
  sudo systemctl disable offline-apt-mirror.service 2>/dev/null || true

  sudo systemctl daemon-reload
  sudo systemctl enable --now offline-apt-noble.service
  sudo systemctl enable --now offline-apt-jammy.service
  sudo systemctl enable --now offline-files-mirror.service

  IP=$(hostname -I | awk '{print $1}')
  echo ""
  echo "✔ PHASE B complete. Offline mirrors are LIVE:"
  echo "  Noble APT mirror  → http://${IP}:${NOBLE_PORT}   (servers)"
  echo "  Jammy APT mirror  → http://${IP}:${JAMMY_PORT}   (linux clients)"
  echo "  Files mirror      → http://${IP}:${FILES_PORT}   (MSIs, scripts, pip)"
  echo ""
  echo "  In ansible/group_vars/all.yml:"
  echo "    offline_repo_host: \"${IP}\""
  echo "    offline_apt_port: ${NOBLE_PORT}"
  echo ""
  echo "  In ansible/group_vars/linux_clients.yml:"
  echo "    offline_apt_port: ${JAMMY_PORT}"
}

# -----------------------------------------------------------------------------
case "${1:-}" in
  download) phase_download ;;
  serve)    phase_serve ;;
  all)      phase_download && phase_serve ;;
  *)
    echo "Usage: $0 {download|serve|all}"
    echo "  download — PHASE A: grab all packages (needs internet)"
    echo "  serve    — PHASE B: start the mirror HTTP servers"
    echo "  all      — run both phases"
    exit 1
    ;;
esac
