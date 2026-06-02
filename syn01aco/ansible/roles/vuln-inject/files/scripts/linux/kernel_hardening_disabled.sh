#!/bin/bash
# vuln: kernel_hardening_disabled | severity: critical
echo "[VULN] Disabling Kernel Hardening..."
echo 0 > /proc/sys/kernel/randomize_va_space
echo 0 > /proc/sys/kernel/kptr_restrict 2>/dev/null || true
echo 0 > /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/conf/all/accept_redirects 2>/dev/null || true
echo 0 > /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null || true
cat >> /etc/sysctl.conf << 'EOFTXT'
kernel.randomize_va_space = 0
kernel.kptr_restrict = 0
kernel.yama.ptrace_scope = 0
EOFTXT
echo "[VULN] Kernel hardening disabled — ASLR, kptr, ptrace all weakened."
