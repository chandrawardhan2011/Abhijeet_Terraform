#!/bin/bash
# vuln: log_tampering_enabled | severity: medium
echo "[VULN] Injecting Log Tampering vulnerability..."
# Make logs world-writable
chmod 777 /var/log 2>/dev/null || true
chmod 666 /var/log/auth.log 2>/dev/null || true
chmod 666 /var/log/syslog 2>/dev/null || true
chmod 666 /var/log/apache2/ 2>/dev/null || true
# Disable auditd
systemctl stop auditd 2>/dev/null || true
systemctl disable auditd 2>/dev/null || true
# Disable rsyslog forwarding
systemctl stop rsyslog 2>/dev/null || true
# Create a world-writable audit config
echo "" > /etc/audit/audit.rules 2>/dev/null || true
echo "[VULN] Log tampering enabled — logs are world-writable, auditd disabled."
echo "[INFO] Attacker can clear logs: echo '' > /var/log/auth.log"
