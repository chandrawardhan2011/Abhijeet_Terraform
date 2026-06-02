#!/bin/bash
# vuln: mysql_brute_force
# Enables remote root MySQL login with weak password and binds to all interfaces

set -e
echo "[VULN] Injecting MySQL/MariaDB Brute Force vulnerability..."

# Set weak root password and enable remote access
mysql -u root --password='' << 'SQLEOF' 2>/dev/null || \
mysql -u root -pAdmin@123 << 'SQLEOF' 2>/dev/null || true
ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'root';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'admin';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;
CREATE USER IF NOT EXISTS 'sa'@'%' IDENTIFIED BY 'sa';
GRANT ALL PRIVILEGES ON *.* TO 'sa'@'%';
FLUSH PRIVILEGES;
SQLEOF

# Allow remote connections by commenting out bind-address
sed -i 's/^bind-address.*/#bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf 2>/dev/null || \
sed -i 's/^bind-address.*/#bind-address = 127.0.0.1/' /etc/mysql/mysql.conf.d/mysqld.cnf 2>/dev/null || true

# Open MySQL port in firewall
ufw allow 3306/tcp 2>/dev/null || true

# Restart MariaDB
systemctl restart mariadb 2>/dev/null || systemctl restart mysql 2>/dev/null || true

echo "[VULN] MySQL Brute Force vulnerability injected."
echo "[INFO] Remote root login enabled: mysql -h <IP> -u root -proot"
echo "[INFO] Weak accounts: root/root, admin/admin, sa/sa"
