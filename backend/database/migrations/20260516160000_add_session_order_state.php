<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddSessionOrderState extends AbstractMigration
{
    public function change(): void
    {
        $this->table('sessions')
            ->addColumn('order_state', 'enum', [
                'values' => ['paid', 'refunded', 'adjusted'],
                'default' => 'paid',
                'after' => 'total_amount',
            ])
            ->addColumn('refund_amount', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 0, 'after' => 'order_state'])
            ->addColumn('admin_note', 'text', ['null' => true, 'after' => 'refund_amount'])
            ->addColumn('adjusted_by', 'integer', ['null' => true, 'signed' => false, 'after' => 'admin_note'])
            ->addColumn('adjusted_at', 'datetime', ['null' => true, 'after' => 'adjusted_by'])
            ->update();
    }
}
