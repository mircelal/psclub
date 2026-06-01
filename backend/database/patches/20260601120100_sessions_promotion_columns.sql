ALTER TABLE sessions
    ADD COLUMN discount_applies_to ENUM('all','time_only') NOT NULL DEFAULT 'time_only' AFTER discount_value;

ALTER TABLE sessions
    ADD COLUMN promotion_id INT UNSIGNED NULL AFTER coupon_id;

ALTER TABLE sessions
    ADD CONSTRAINT fk_sessions_promotion_id FOREIGN KEY (promotion_id) REFERENCES promotions(id) ON DELETE SET NULL ON UPDATE CASCADE;
