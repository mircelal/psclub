-- PS Club: cash_movements.type — refund (satış qaytarması)
-- phpMyAdmin → psapi_psclub → SQL

ALTER TABLE cash_movements
    MODIFY type ENUM('expense', 'owner_withdrawal', 'pay_in', 'refund') NOT NULL;
