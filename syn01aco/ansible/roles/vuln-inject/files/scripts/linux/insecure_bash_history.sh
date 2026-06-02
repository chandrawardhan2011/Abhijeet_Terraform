#!/bin/bash
# vuln: sensitive_bash_history | severity: low
echo "[VULN] Injecting Sensitive Bash History..."
cat > /root/.bash_history << 'EOFTXT'
ssh root@10.0.20.10 -p 22
mysql -u root -pAdmin@123 -h 10.0.20.30
curl -u admin:Admin@123 http://10.0.20.20/admin
scp backup.tar.gz root@10.0.40.23:/backups/
echo "Admin@123" | passwd root
gpg --passphrase SuperSecret123 --decrypt secret.gpg
EOFTXT
chmod 644 /root/.bash_history
cat > /home/ansible/.bash_history << 'EOFTXT'
sudo su -
mysql -h 10.0.20.30 -u root -pAdmin@123
ssh-copy-id root@10.0.20.10
cat /opt/app/config/database.conf
EOFTXT
echo "[VULN] Sensitive commands in bash history. Check /root/.bash_history"
