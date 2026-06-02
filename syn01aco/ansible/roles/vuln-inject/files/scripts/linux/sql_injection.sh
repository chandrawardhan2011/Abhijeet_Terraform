#!/bin/bash
# vuln: sql_injection
# Deploys a vulnerable PHP login page with no input sanitisation on the web server

set -e
echo "[VULN] Injecting SQL Injection (OWASP A03) vulnerability..."

# Create vulnerable PHP app directory
mkdir -p /var/www/vuln-sqli
chown -R www-data:www-data /var/www/vuln-sqli

# Create a vulnerable login page
cat > /var/www/vuln-sqli/index.php << 'PHPEOF'
<?php
// VULNERABLE: No input sanitisation - SQL Injection
$host = 'localhost';
$db   = 'vulndb';
$user = 'root';
$pass = 'root';

$conn = new mysqli($host, $user, $pass, $db);

$error = '';
$success = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'];
    $password = $_POST['password'];
    
    // VULNERABLE: Direct string interpolation - no sanitisation
    $query = "SELECT * FROM users WHERE username='$username' AND password='$password'";
    $result = $conn->query($query);
    
    if ($result && $result->num_rows > 0) {
        $success = "Login successful! Welcome, " . htmlspecialchars($username);
    } else {
        $error = "Invalid credentials. Query was: " . htmlspecialchars($query);
    }
}
?>
<!DOCTYPE html>
<html>
<head><title>Vulnerable Login</title>
<style>body{background:#1a1a2e;color:#eee;font-family:monospace;display:flex;justify-content:center;padding-top:80px;}
.box{background:#16213e;padding:40px;border:1px solid #0f3460;width:400px;}
input{width:100%;padding:8px;margin:8px 0;background:#0f3460;color:#eee;border:1px solid #533483;}
button{width:100%;padding:10px;background:#533483;color:#fff;border:none;cursor:pointer;}
.err{color:#ff6b6b;margin-top:10px;font-size:12px;}
.ok{color:#6bff6b;margin-top:10px;}
</style></head>
<body><div class="box">
<h2>🔓 Login Panel</h2>
<p style="color:#888;font-size:12px;">Hint: Try ' OR '1'='1' -- in username</p>
<form method="POST">
<input type="text" name="username" placeholder="Username" />
<input type="password" name="password" placeholder="Password" />
<button type="submit">Login</button>
</form>
<?php if($error) echo "<div class='err'>$error</div>"; ?>
<?php if($success) echo "<div class='ok'>$success</div>"; ?>
</div></body></html>
PHPEOF

# Create the vulnerable database
mysql -u root --password='' -e "
CREATE DATABASE IF NOT EXISTS vulndb;
USE vulndb;
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50),
  password VARCHAR(50),
  role VARCHAR(20)
);
INSERT INTO users (username, password, role) VALUES
  ('admin', 'supersecret123', 'admin'),
  ('user1', 'password', 'user'),
  ('flag_user', 'CTF{sql_injection_pwned}', 'flag')
ON DUPLICATE KEY UPDATE username=username;
GRANT ALL PRIVILEGES ON vulndb.* TO 'root'@'localhost';
FLUSH PRIVILEGES;
" 2>/dev/null || true

# Create Apache vhost for the vulnerable app
cat > /etc/apache2/sites-available/vuln-sqli.conf << 'CONF'
<VirtualHost *:9001>
    DocumentRoot /var/www/vuln-sqli
    <Directory /var/www/vuln-sqli>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</CONF

# Enable site
a2ensite vuln-sqli.conf 2>/dev/null || true
systemctl reload apache2 2>/dev/null || true

echo "[VULN] SQL Injection vulnerability deployed on port 9001."
echo "[INFO] Payload: username = ' OR '1'='1' --"
