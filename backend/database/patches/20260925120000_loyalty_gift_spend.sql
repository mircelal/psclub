ALTER TABLE customers ADD COLUMN bonus_minutes INT NOT NULL DEFAULT 0;
ALTER TABLE customers ADD COLUMN bonus_wallet DECIMAL(10,2) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS loyalty_ledger (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    entry_type VARCHAR(32) NOT NULL,
    minutes_delta INT NOT NULL DEFAULT 0,
    wallet_delta DECIMAL(10,2) NOT NULL DEFAULT 0,
    note VARCHAR(255) NULL,
    session_id INT NULL,
    created_by INT NULL,
    created_at DATETIME NOT NULL,
    INDEX idx_loyalty_customer (customer_id)
);

ALTER TABLE sessions ADD COLUMN bonus_minutes_used INT NOT NULL DEFAULT 0;
ALTER TABLE sessions ADD COLUMN bonus_wallet_used DECIMAL(10,2) NOT NULL DEFAULT 0;
ALTER TABLE sessions ADD COLUMN gift_note TEXT NULL;

ALTER TABLE promotions ADD COLUMN valid_days TEXT NULL;
ALTER TABLE promotions ADD COLUMN valid_hours TEXT NULL;

CREATE TABLE IF NOT EXISTS spend_discount_rules (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    business_id INT UNSIGNED NOT NULL DEFAULT 1,
    name VARCHAR(120) NOT NULL,
    min_spend DECIMAL(10,2) NOT NULL DEFAULT 0,
    window_type VARCHAR(32) NOT NULL DEFAULT 'lifetime',
    window_days INT NULL,
    discount_type VARCHAR(16) NOT NULL,
    discount_value DECIMAL(10,2) NOT NULL,
    applies_to VARCHAR(16) NOT NULL DEFAULT 'all',
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    sort_order INT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL
);
