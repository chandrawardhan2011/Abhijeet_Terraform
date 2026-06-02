#!/bin/bash
# vuln: weak_user_passwords | severity: medium
echo "[VULN] Injecting Weak User Passwords..."
for user in alice bob charlie david; do
    useradd -m -s /bin/bash $user 2>/dev/null || true
    echo "$user:$user" | chpasswd
done
echo "root:root" | chpasswd 2>/dev/null || true
echo "ansible:ansible" | chpasswd 2>/dev/null || true
# Disable password complexity
sed -i 's/^password.*pam_pwquality.*/# password requisite pam_pwquality.so/' /etc/pam.d/common-password 2>/dev/null || true
echo "[VULN] Weak passwords set. Users: alice:alice, bob:bob, root:root"
