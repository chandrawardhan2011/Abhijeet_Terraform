-- /opt/icp/db/schema.sql
-- ICP — Insurance Claims Portal database schema
-- All 5 sub-apps share this database.

CREATE DATABASE IF NOT EXISTS icp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE icp;

-- -----------------------------------------------------------------------------
-- USERS — shared by all sub-apps. Roles: 'user', 'adjuster' (admin).
-- ICP_55 (default credentials) seeds an admin/admin user.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    username     VARCHAR(64) NOT NULL UNIQUE,
    -- MD5 password storage is a deliberate weakness, used by ICP_45 UNION leak.
    password_md5 CHAR(32) NOT NULL,
    email        VARCHAR(128),
    role         ENUM('user','adjuster') NOT NULL DEFAULT 'user',
    created_at   DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- POLICIES — for policies.icp.lab (ICP_11 SQLi target)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS policies (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    name      VARCHAR(128) NOT NULL,
    plan      VARCHAR(64) NOT NULL,
    premium   DECIMAL(10,2) NOT NULL,
    flag_note VARCHAR(255)   -- where ICP_11 plants the flag string for UNION pull
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- CLAIMS — for claims.icp.lab and status.icp.lab
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NOT NULL,
    policy_id   INT NOT NULL,
    description TEXT,             -- ICP_25 stored XSS sink
    status      ENUM('submitted','review','approved','rejected') DEFAULT 'submitted',
    fraud_flag  TINYINT(1) DEFAULT 0,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX (user_id),
    INDEX (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS settlements (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    policy_id  INT NOT NULL,
    amount     DECIMAL(12,2) NOT NULL,
    paid_on    DATE,
    INDEX (policy_id)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- BENEFICIARIES — for beneficiary.icp.lab
-- bank_account is "encrypted" with AES-ECB + hardcoded key — ICP_44 weakness.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS nominees (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    policyholder_id INT NOT NULL,
    name            VARCHAR(128) NOT NULL,
    relation        VARCHAR(32),
    bank_ifsc       VARCHAR(16),
    bank_account_enc VARBINARY(128),  -- AES-ECB(account_number)
    INDEX (policyholder_id)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- ADJUSTER WORKFLOW — for admin.icp.lab
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS adjudications (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    claim_id   INT NOT NULL,
    state      ENUM('queued','review','decided') DEFAULT 'queued',
    decision   ENUM('approve','reject','pending') DEFAULT 'pending',
    decided_by INT,
    decided_at DATETIME,
    INDEX (claim_id)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- TESTIMONIALS — for icp.lab landing /voices/ (ICP_57 stored XSS sink)
-- Body field stored RAW and rendered RAW.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS testimonials (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    author_name  VARCHAR(80) NOT NULL DEFAULT 'Anonymous',
    body         TEXT NOT NULL,
    submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- AUDIT LOG — written to by shared/includes/audit.php
-- ICP_15 deliberately bypasses this table on the quote endpoint.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_log (
    id         BIGINT AUTO_INCREMENT PRIMARY KEY,
    ts         DATETIME NOT NULL,
    event      VARCHAR(64) NOT NULL,
    source_ip  VARCHAR(45),
    user_id    INT DEFAULT 0,
    details    JSON,
    INDEX (ts),
    INDEX (event)
) ENGINE=InnoDB;
