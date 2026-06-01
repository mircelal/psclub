<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddCashMovementRefundType extends AbstractMigration
{
    public function up(): void
    {
        $this->execute(
            "ALTER TABLE cash_movements MODIFY type ENUM('expense', 'owner_withdrawal', 'pay_in', 'refund') NOT NULL"
        );
    }

    public function down(): void
    {
        $this->execute(
            "ALTER TABLE cash_movements MODIFY type ENUM('expense', 'owner_withdrawal', 'pay_in') NOT NULL"
        );
    }
}
