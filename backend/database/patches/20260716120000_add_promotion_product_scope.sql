-- Product-scoped promotions: enum expand + product_ids JSON column.
ALTER TABLE promotions
    MODIFY COLUMN applies_to ENUM('time_only', 'products') NOT NULL DEFAULT 'time_only',
    MODIFY COLUMN scope ENUM('all_tables', 'tariffs', 'products') NOT NULL DEFAULT 'all_tables';

ALTER TABLE promotions
    ADD COLUMN product_ids TEXT NULL COMMENT 'JSON array of product IDs when scope=products' AFTER tariff_names;
