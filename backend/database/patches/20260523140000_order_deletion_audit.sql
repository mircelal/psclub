ALTER TABLE sessions
    ADD COLUMN deleted_by INT UNSIGNED NULL AFTER adjusted_at,
    ADD COLUMN deleted_at DATETIME NULL AFTER deleted_by;

ALTER TABLE payments
    ADD COLUMN pre_delete_cash DECIMAL(10,2) NULL AFTER total_amount,
    ADD COLUMN pre_delete_card DECIMAL(10,2) NULL AFTER pre_delete_cash,
    ADD COLUMN pre_delete_total DECIMAL(10,2) NULL AFTER pre_delete_card;
