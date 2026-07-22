ALTER TABLE stock_movements
    ADD COLUMN delta INT NULL AFTER quantity,
    ADD COLUMN balance_before INT NULL AFTER delta,
    ADD COLUMN balance_after INT NULL AFTER balance_before;
