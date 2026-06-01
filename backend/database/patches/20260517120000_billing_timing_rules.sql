-- PS Club: billing timing (yeniləmə — mövcud DB üçün)
-- phpMyAdmin → psapi_psclub → SQL → bu faylı işlədin.
-- Sütunlar artıq varsa, hər ADD COLUMN sətri xəta verə bilər — o sətri ötürün.

ALTER TABLE businesses
    ADD COLUMN min_open_minutes INT UNSIGNED NOT NULL DEFAULT 60 AFTER time_billing_enabled;

ALTER TABLE businesses
    ADD COLUMN extend_step_minutes INT UNSIGNED NOT NULL DEFAULT 30 AFTER min_open_minutes;

ALTER TABLE businesses
    ADD COLUMN min_billing_minutes INT UNSIGNED NOT NULL DEFAULT 60 AFTER extend_step_minutes;

ALTER TABLE businesses
    ADD COLUMN billing_increment_minutes INT UNSIGNED NOT NULL DEFAULT 30 AFTER min_billing_minutes;

ALTER TABLE businesses
    MODIFY billing_mode ENUM('per_minute','block_30','block_60','min_1h_then_30')
    NOT NULL DEFAULT 'per_minute';
