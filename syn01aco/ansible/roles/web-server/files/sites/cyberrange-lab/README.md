
# Mini Cyber Range - PHP

## Included Vulnerabilities

- SQL Injection
- Reflected XSS
- IDOR
- Local File Inclusion

## Requirements

- Ubuntu Server
- Apache2
- PHP 8+
- PHP SQLite extension

## Installation

### 1. Copy Files

Copy the lab folder to:

/var/www/html/lab

### 2. Install PHP SQLite

sudo apt update
sudo apt install php-sqlite3

### 3. Restart Apache

sudo systemctl restart apache2

### 4. Create Database

Run:

sqlite3 db/lab.sqlite

Then execute:

CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    password TEXT
);

INSERT INTO users(username,password)
VALUES ('admin','admin123');

INSERT INTO users(username,password)
VALUES ('guest','guest123');

.exit

### 5. Set Permissions

chmod -R 777 uploads
chmod -R 777 logs

### 6. Open Browser

http://SERVER-IP/lab

## Enable/Disable Vulnerabilities

Edit:

config/config.json

Example:

{
  "enabled_vulnerabilities": [
    "sqli",
    "xss"
  ]
}

## Example Payloads

### SQLi

' OR '1'='1

### XSS

<script>alert(1)</script>

### IDOR

?page=profile&id=2

### LFI

?page=lfi&file=../../../../etc/passwd

## Notes

This lab is intentionally vulnerable.
Deploy ONLY in isolated internal environments.
