#!/bin/bash
# vuln: nfs_misconfiguration | severity: high
echo "[VULN] Injecting NFS Misconfiguration..."
apt-get install -y nfs-kernel-server 2>/dev/null || true
mkdir -p /srv/nfs_share
chmod 777 /srv/nfs_share
cat > /srv/nfs_share/sensitive_data.txt << 'EOFTXT'
SENSITIVE SERVER DATA
======================
DB_PASSWORD=Admin@123
API_KEY=sk-prod-abc123xyz789
INTERNAL_IP=10.0.20.30
EOFTXT
echo "/srv/nfs_share *(rw,sync,no_root_squash,no_subtree_check)" >> /etc/exports
exportfs -ra 2>/dev/null || true
systemctl restart nfs-kernel-server 2>/dev/null || true
echo "[VULN] NFS share exposed with no_root_squash — mount and escalate."
echo "[INFO] Attack: showmount -e <IP> && mount -t nfs <IP>:/srv/nfs_share /mnt"
