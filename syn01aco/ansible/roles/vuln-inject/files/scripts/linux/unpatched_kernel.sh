#!/bin/bash
# vuln: unpatched_kernel_simulation | severity: critical
echo "[VULN] Simulating Unpatched Kernel vulnerability..."
echo 0 > /proc/sys/kernel/randomize_va_space
echo 0 > /proc/sys/kernel/kptr_restrict 2>/dev/null || true
echo 1 > /proc/sys/kernel/perf_event_paranoid 2>/dev/null || true
echo 0 > /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || true
cat > /tmp/kernel_vuln_info.txt << 'EOFTXT'
KERNEL VULNERABILITY SIMULATION
================================
ASLR disabled: /proc/sys/kernel/randomize_va_space = 0
Kernel pointers exposed: kptr_restrict = 0
ptrace unrestricted: yama/ptrace_scope = 0
Attack: Local privilege escalation via kernel exploits
Simulate: gcc -o exploit exploit.c && ./exploit
EOFTXT
echo "[VULN] Kernel hardening disabled — system vulnerable to local privilege escalation."
