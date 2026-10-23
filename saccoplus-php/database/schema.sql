-- SACCOPLUS v2 (PHP + MySQL). Starter schema: SACCOs and staff users.
-- The real member / savings / loan tables will be designed from schema_report.md (Firestore dump).
CREATE DATABASE IF NOT EXISTS saccoplus_v2 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE saccoplus_v2;

CREATE TABLE IF NOT EXISTS saccos (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(150) NOT NULL,
  legacy_id   VARCHAR(100) NULL UNIQUE,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS users (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id       INT UNSIGNED NOT NULL,
  full_name      VARCHAR(150) NOT NULL,
  email          VARCHAR(190) NOT NULL UNIQUE,
  password_hash  VARCHAR(255) NOT NULL,
  role           ENUM('admin','manager','teller','accountant','viewer') NOT NULL DEFAULT 'teller',
  is_active      TINYINT(1) NOT NULL DEFAULT 1,
  legacy_id      VARCHAR(100) NULL UNIQUE,
  last_login_at  DATETIME NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_users_sacco FOREIGN KEY (sacco_id) REFERENCES saccos(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_log (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id    INT UNSIGNED NULL,
  user_id     INT UNSIGNED NULL,
  action      VARCHAR(80) NOT NULL,
  entity      VARCHAR(80) NULL,
  entity_id   VARCHAR(80) NULL,
  old_values  JSON NULL,
  new_values  JSON NULL,
  ip          VARCHAR(45) NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (entity, entity_id), INDEX (user_id), INDEX (created_at)
) ENGINE=InnoDB;
