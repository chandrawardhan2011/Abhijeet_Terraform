#!/bin/bash
# vuln: plaintext_credentials | severity: high
echo "[VULN] Injecting Plaintext Credentials in config files..."
mkdir -p /opt/app/config /var/log/app
cat > /opt/app/config/database.conf << 'EOFTXT'
[database]
host=10.0.20.30
port=3306
username=root
password=Admin@123
dbname=cyber_range
EOFTXT
cat > /opt/app/config/app.env << 'EOFTXT'
DB_PASSWORD=Admin@123
SECRET_KEY=supersecretkey123
API_TOKEN=eyJhbGciOiJIUzI1NiJ9.admin.secret
SMTP_PASSWORD=email@pass123
AWS_SECRET=AKIAIOSFODNN7EXAMPLE
EOFTXT
cat > /var/log/app/app.log << 'EOFTXT'
2024-01-15 10:23:01 INFO  Login attempt: user=admin pass=Admin@123
2024-01-15 10:23:01 INFO  DB connect: root:Admin@123@10.0.20.30
2024-01-15 10:24:15 ERROR Failed auth for user=root pass=toor
EOFTXT
chmod 644 /opt/app/config/database.conf
chmod 644 /opt/app/config/app.env
chmod 644 /var/log/app/app.log
echo "[VULN] Plaintext credentials planted in config files and logs."
echo "[INFO] Check /opt/app/config/ and /var/log/app/"
