<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddShiftsCashDrawer extends AbstractMigration
{
    public function change(): void
    {
        $this->table('shifts', ['id' => false, 'primary_key' => ['id']])
            ->addColumn('id', 'integer', ['identity' => true, 'signed' => false])
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('opened_by', 'integer', ['signed' => false])
            ->addColumn('closed_by', 'integer', ['signed' => false, 'null' => true])
            ->addColumn('status', 'enum', ['values' => ['open', 'closed'], 'default' => 'open'])
            ->addColumn('opened_at', 'datetime')
            ->addColumn('closed_at', 'datetime', ['null' => true])
            ->addColumn('opening_cash', 'decimal', ['precision' => 12, 'scale' => 2, 'default' => 0])
            ->addColumn('closing_cash', 'decimal', ['precision' => 12, 'scale' => 2, 'null' => true])
            ->addColumn('expected_cash', 'decimal', ['precision' => 12, 'scale' => 2, 'null' => true])
            ->addColumn('cash_difference', 'decimal', ['precision' => 12, 'scale' => 2, 'null' => true])
            ->addColumn('cash_sales', 'decimal', ['precision' => 12, 'scale' => 2, 'default' => 0])
            ->addColumn('card_sales', 'decimal', ['precision' => 12, 'scale' => 2, 'default' => 0])
            ->addColumn('notes', 'text', ['null' => true])
            ->addTimestamps()
            ->addIndex(['business_id', 'status'])
            ->create();

        $this->table('cash_movements', ['id' => false, 'primary_key' => ['id']])
            ->addColumn('id', 'integer', ['identity' => true, 'signed' => false])
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('shift_id', 'integer', ['signed' => false, 'null' => true])
            ->addColumn('type', 'enum', ['values' => ['expense', 'owner_withdrawal', 'pay_in']])
            ->addColumn('category', 'string', ['limit' => 80])
            ->addColumn('amount', 'decimal', ['precision' => 12, 'scale' => 2])
            ->addColumn('description', 'text', ['null' => true])
            ->addColumn('source', 'enum', ['values' => ['cashier', 'admin'], 'default' => 'cashier'])
            ->addColumn('created_by', 'integer', ['signed' => false, 'null' => true])
            ->addColumn('created_at', 'datetime', ['default' => 'CURRENT_TIMESTAMP'])
            ->addIndex(['shift_id'])
            ->addIndex(['business_id', 'created_at'])
            ->create();

        $this->table('payments')
            ->addColumn('shift_id', 'integer', ['signed' => false, 'null' => true, 'after' => 'session_id'])
            ->update();
    }
}
