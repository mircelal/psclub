CREATE TABLE IF NOT EXISTS customer_groups (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    business_id INT UNSIGNED NOT NULL DEFAULT 1,
    name VARCHAR(120) NOT NULL,
    description TEXT NULL,
    discount_type ENUM('percent', 'fixed') NOT NULL,
    discount_value DECIMAL(10, 2) NOT NULL,
    applies_to ENUM('time_only', 'all') NOT NULL DEFAULT 'time_only',
    color VARCHAR(16) NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    sort_order INT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE customers
    ADD COLUMN customer_group_id INT UNSIGNED NULL AFTER notes,
    ADD CONSTRAINT fk_customers_customer_group
        FOREIGN KEY (customer_group_id) REFERENCES customer_groups (id)
        ON DELETE SET NULL ON UPDATE CASCADE;

INSERT INTO customer_groups (business_id, name, description, discount_type, discount_value, applies_to, color, is_active, sort_order, created_at, updated_at)
SELECT 1, 'VIP', 'Daimi müştərilər — uzunmüddətli loyallıq', 'percent', 10, 'time_only', '#7C6CF0', 1, 10, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM customer_groups WHERE name = 'VIP' LIMIT 1);

INSERT INTO customer_groups (business_id, name, description, discount_type, discount_value, applies_to, color, is_active, sort_order, created_at, updated_at)
SELECT 1, 'Tələbə', 'Tələbə bileti ilə — adətən vaxt haqqına', 'percent', 15, 'time_only', '#34C759', 1, 20, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM customer_groups WHERE name = 'Tələbə' LIMIT 1);

INSERT INTO customer_groups (business_id, name, description, discount_type, discount_value, applies_to, color, is_active, sort_order, created_at, updated_at)
SELECT 1, 'Uşaq', '12 yaşadək — ailə paketləri ilə', 'percent', 20, 'time_only', '#FF9500', 1, 30, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM customer_groups WHERE name = 'Uşaq' LIMIT 1);

INSERT INTO customer_groups (business_id, name, description, discount_type, discount_value, applies_to, color, is_active, sort_order, created_at, updated_at)
SELECT 1, 'Komanda / Turnir', 'Komanda rezervasiyası və turnir qrupları', 'percent', 25, 'time_only', '#5856D6', 1, 40, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM customer_groups WHERE name = 'Komanda / Turnir' LIMIT 1);

INSERT INTO customer_groups (business_id, name, description, discount_type, discount_value, applies_to, color, is_active, sort_order, created_at, updated_at)
SELECT 1, 'İşçi', 'Klub əməkdaşları', 'percent', 30, 'time_only', '#8E8E93', 1, 50, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM customer_groups WHERE name = 'İşçi' LIMIT 1);

INSERT INTO customer_groups (business_id, name, description, discount_type, discount_value, applies_to, color, is_active, sort_order, created_at, updated_at)
SELECT 1, 'Korporativ', 'Şirkət müqaviləsi — vaxt + məhsul', 'percent', 10, 'all', '#007AFF', 1, 60, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM customer_groups WHERE name = 'Korporativ' LIMIT 1);

INSERT INTO customer_groups (business_id, name, description, discount_type, discount_value, applies_to, color, is_active, sort_order, created_at, updated_at)
SELECT 1, 'Yeni müştəri', 'İlk ziyarət təşviqi', 'percent', 10, 'time_only', '#FF2D55', 1, 70, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM customer_groups WHERE name = 'Yeni müştəri' LIMIT 1);

INSERT INTO customer_groups (business_id, name, description, discount_type, discount_value, applies_to, color, is_active, sort_order, created_at, updated_at)
SELECT 1, 'Referral', 'Dost gətirən müştəri', 'percent', 5, 'time_only', '#30B0C7', 1, 80, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM customer_groups WHERE name = 'Referral' LIMIT 1);
