<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddStockMovementAuditColumns extends AbstractMigration
{
    public function change(): void
    {
        $this->table('stock_movements')
            ->addColumn('delta', 'integer', ['null' => true, 'after' => 'quantity'])
            ->addColumn('balance_before', 'integer', ['null' => true, 'after' => 'delta'])
            ->addColumn('balance_after', 'integer', ['null' => true, 'after' => 'balance_before'])
            ->update();
    }
}
