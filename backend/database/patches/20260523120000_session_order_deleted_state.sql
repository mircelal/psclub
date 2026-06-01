-- Admin sifariş silməsi: order_state = 'deleted'
ALTER TABLE sessions MODIFY COLUMN order_state
    ENUM('paid', 'refunded', 'adjusted', 'deleted') NOT NULL DEFAULT 'paid';
