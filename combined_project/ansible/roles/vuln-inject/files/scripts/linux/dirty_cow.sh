#!/bin/bash
# vuln: dirty_cow
# Simulates CVE-2016-5195 (Dirty COW) by:
# - Disabling kernel security patches via sysctl
# - Creating a world-writable SUID binary
# - Leaving a note in /tmp/dirty_cow_vulnerable

set -e
echo "[VULN] Injecting Dirty COW (CVE-2016-5195) vulnerability simulation..."

# Disable ASLR
echo 0 > /proc/sys/kernel/randomize_va_space
echo "kernel.randomize_va_space = 0" >> /etc/sysctl.conf

# Create a vulnerable SUID file (simulation artifact)
cp /bin/bash /tmp/vuln_suid_bash
chmod u+s /tmp/vuln_suid_bash
chmod 777 /tmp/vuln_suid_bash

# Create a world-writable file owned by root
echo "This file is world-writable and owned by root - simulating Dirty COW target" > /tmp/root_owned_writable
chmod 0666 /tmp/root_owned_writable
chown root:root /tmp/root_owned_writable

# Drop vulnerability note
cat > /tmp/dirty_cow_vulnerable << 'EOF'
=== CVE-2016-5195 Dirty COW - VULNERABLE SYSTEM ===
This system has been configured to simulate the Dirty COW vulnerability.
A local attacker can exploit a race condition in the Linux kernel's
copy-on-write (COW) implementation to gain write access to read-only
memory mappings and escalate privileges to root.

Attack vector: Local
Privileges required: Low (any local user)
Impact: Complete root compromise

Target file: /tmp/root_owned_writable
EOF

echo "[VULN] Dirty COW simulation injected. System is vulnerable."
