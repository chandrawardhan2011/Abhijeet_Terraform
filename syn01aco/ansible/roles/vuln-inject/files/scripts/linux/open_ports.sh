#!/bin/bash
# vuln: unnecessary_open_ports | severity: medium
echo "[VULN] Injecting Unnecessary Open Ports..."
# Disable firewall
ufw disable 2>/dev/null || true
ufw reset 2>/dev/null || true
iptables -F 2>/dev/null || true
iptables -X 2>/dev/null || true
# Start telnet if available
apt-get install -y telnetd 2>/dev/null || true
systemctl start inetd 2>/dev/null || true
# Open netcat listener on common ports
nohup nc -lvnp 4444 > /dev/null 2>&1 &
nohup nc -lvnp 8888 > /dev/null 2>&1 &
echo "[VULN] Firewall disabled, unnecessary ports opened (4444, 8888)."
echo "[INFO] Scan with: nmap -sV <IP>"
