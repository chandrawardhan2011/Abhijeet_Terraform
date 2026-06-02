#!/bin/bash
# vuln: no_host_firewall | severity: medium
echo "[VULN] Disabling Host Firewall..."
ufw disable 2>/dev/null || true
iptables -F 2>/dev/null || true
iptables -X 2>/dev/null || true
iptables -P INPUT ACCEPT 2>/dev/null || true
iptables -P FORWARD ACCEPT 2>/dev/null || true
iptables -P OUTPUT ACCEPT 2>/dev/null || true
systemctl stop firewalld 2>/dev/null || true
systemctl disable ufw 2>/dev/null || true
echo "[VULN] All firewall rules flushed. All ports now accessible."
