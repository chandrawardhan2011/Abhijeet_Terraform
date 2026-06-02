#!/bin/bash
# vuln: rpcbind_exposure | severity: low
echo "[VULN] Exposing RPC services..."
apt-get install -y rpcbind nfs-common 2>/dev/null || true
systemctl start rpcbind 2>/dev/null || true
systemctl enable rpcbind 2>/dev/null || true
ufw allow 111/tcp 2>/dev/null || true
ufw allow 111/udp 2>/dev/null || true
echo "[VULN] RPC portmapper exposed on port 111. Enumerate with: rpcinfo -p <IP>"
