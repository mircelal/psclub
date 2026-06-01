<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddOrderDeletionAudit extends AbstractMigration
{
    public function change(): void
    {
        $this->table('sessions')
            ->addColumn('deleted_by', 'integer', ['null' => true, 'signed' => false, 'after' => 'adjusted_at'])
            ->addColumn('deleted_at', 'datetime', ['null' => true, 'after' => 'deleted_by'])
            ->update();

        $this->table('payments')
            ->addColumn('pre_delete_cash', 'decimal', ['precision' => 10, 'scale' => 2, 'null' => true, 'after' => 'total_amount'])
            ->addColumn('pre_delete_card', 'decimal', ['precision' => 10, 'scale' => 2, 'null' => true, 'after' => 'pre_delete_cash'])
            ->addColumn('pre_delete_total', 'decimal', ['precision' => 10, 'scale' => 2, 'null' => true, 'after' => 'pre_delete_card'])
            ->update();
    }
}
