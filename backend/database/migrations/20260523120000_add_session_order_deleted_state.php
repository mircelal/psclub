<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddSessionOrderDeletedState extends AbstractMigration
{
    public function up(): void
    {
        $this->execute(
            "ALTER TABLE sessions MODIFY COLUMN order_state
             ENUM('paid', 'refunded', 'adjusted', 'deleted') NOT NULL DEFAULT 'paid'"
        );
    }

    public function down(): void
    {
        $this->execute(
            "UPDATE sessions SET order_state = 'paid' WHERE order_state = 'deleted'"
        );
        $this->execute(
            "ALTER TABLE sessions MODIFY COLUMN order_state
             ENUM('paid', 'refunded', 'adjusted') NOT NULL DEFAULT 'paid'"
        );
    }
}
