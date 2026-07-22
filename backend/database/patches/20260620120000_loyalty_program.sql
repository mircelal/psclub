-- Loyallıq proqramı (təkrar işlədilə bilən patch — duplicate sütunlar ignor edilir)
ALTER TABLE customers
    ADD COLUMN bonus_minutes INT UNSIGNED NOT NULL DEFAULT 0 AFTER customer_group_id;
ALTER TABLE customers
    ADD COLUMN bonus_wallet DECIMAL(10,2) NOT NULL DEFAULT 0 AFTER bonus_minutes;

CREATE TABLE IF NOT EXISTS loyalty_tiers (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    business_id INT UNSIGNED NOT NULL DEFAULT 1,
    name VARCHAR(120) NOT NULL,
    spend_threshold DECIMAL(10,2) NOT NULL DEFAULT 500.00,
    reward_kind ENUM('hours','hours_percent','wallet_percent','wallet_fixed') NOT NULL,
    reward_value DECIMAL(10,2) NOT NULL,
    reference_hourly_rate DECIMAL(10,2) NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    sort_order INT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS loyalty_ledger (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    customer_id INT UNSIGNED NOT NULL,
    entry_type ENUM('tier_earn','admin_hours','admin_wallet','redeem_hours','redeem_wallet','adjust') NOT NULL,
    minutes_delta INT NOT NULL DEFAULT 0,
    wallet_delta DECIMAL(10,2) NOT NULL DEFAULT 0,
    session_id INT UNSIGNED NULL,
    tier_id INT UNSIGNED NULL,
    note TEXT NULL,
    created_by INT UNSIGNED NULL,
    created_at DATETIME NOT NULL,
    INDEX idx_customer_created (customer_id, created_at),
    CONSTRAINT fk_loyalty_ledger_customer FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    CONSTRAINT fk_loyalty_ledger_session FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE SET NULL,
    CONSTRAINT fk_loyalty_ledger_tier FOREIGN KEY (tier_id) REFERENCES loyalty_tiers(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE sessions
    ADD COLUMN bonus_minutes_used INT UNSIGNED NOT NULL DEFAULT 0 AFTER coupon_id;
ALTER TABLE sessions
    ADD COLUMN bonus_wallet_used DECIMAL(10,2) NOT NULL DEFAULT 0 AFTER bonus_minutes_used;
