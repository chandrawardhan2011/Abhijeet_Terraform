CREATE DATABASE IF NOT EXISTS cyber_range;
USE cyber_range;

CREATE TABLE IF NOT EXISTS employee_records (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    password VARCHAR(255) NOT NULL,
    adhar_id VARCHAR(20) NOT NULL,
    role VARCHAR(20) DEFAULT 'user'
);

-- Also create 'users' view/table alias so cyberrange-lab handlers work (they SELECT from 'users')
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    password VARCHAR(255) NOT NULL,
    adhar_id VARCHAR(20) NOT NULL,
    role VARCHAR(20) DEFAULT 'user'
);

TRUNCATE TABLE employee_records;
TRUNCATE TABLE users;

INSERT INTO employee_records (username, password, adhar_id, role) VALUES
('admin',    'SuperSecretAdmin99!', '400078112222', 'administrator'),
('jsmith',   'password123',         '408078113242', 'user'),
('mscott',   'michael123',          '938075118242', 'manager'),
('dshrute',  'beetsbearsbsg',       '938175718327', 'pa'),
('helpdesk', 'Welcome1!',           '218176738129', 'support');

INSERT INTO users (username, password, adhar_id, role)
SELECT username, password, adhar_id, role FROM employee_records;

CREATE USER IF NOT EXISTS 'webapp'@'%' IDENTIFIED BY 'webapp123';
GRANT ALL PRIVILEGES ON cyber_range.* TO 'webapp'@'%';
GRANT FILE ON *.* TO 'webapp'@'%';

DROP PROCEDURE IF EXISTS GetUser;
DELIMITER //
CREATE PROCEDURE GetUser(IN target_user VARCHAR(255))
    SQL SECURITY DEFINER
BEGIN
    SET @s = CONCAT('SELECT username, role FROM users WHERE username = ''', target_user, '''');
    PREPARE stmt FROM @s;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //
DELIMITER ;

GRANT EXECUTE ON PROCEDURE cyber_range.GetUser TO 'webapp'@'%';
FLUSH PRIVILEGES;
