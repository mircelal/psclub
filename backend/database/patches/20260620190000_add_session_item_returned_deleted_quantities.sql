ALTER TABLE session_items
    ADD COLUMN IF NOT EXISTS returned_quantity INT UNSIGNED NOT NULL DEFAULT 0 AFTER quantity,
    ADD COLUMN IF NOT EXISTS deleted_quantity INT UNSIGNED NOT NULL DEFAULT 0 AFTER returned_quantity;

UPDATE session_items SET returned_quantity = 0 WHERE returned_quantity IS NULL;
UPDATE session_items SET deleted_quantity = 0 WHERE deleted_quantity IS NULL;
