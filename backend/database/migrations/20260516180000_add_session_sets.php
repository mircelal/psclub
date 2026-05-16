<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddSessionSets extends AbstractMigration
{
    public function change(): void
    {
        $this->table('session_sets')
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('name', 'string', ['limit' => 120])
            ->addColumn('description', 'string', ['limit' => 255, 'null' => true])
            ->addColumn('fixed_price', 'decimal', ['precision' => 10, 'scale' => 2])
            ->addColumn('planned_minutes', 'integer', ['null' => true])
            ->addColumn('sort_order', 'integer', ['default' => 0])
            ->addColumn('is_active', 'boolean', ['default' => true])
            ->addTimestamps()
            ->create();

        $this->table('session_set_items')
            ->addColumn('set_id', 'integer', ['signed' => false])
            ->addColumn('product_id', 'integer', ['signed' => false])
            ->addColumn('quantity', 'integer', ['default' => 1])
            ->addForeignKey('set_id', 'session_sets', 'id', ['delete' => 'CASCADE', 'update' => 'CASCADE'])
            ->addForeignKey('product_id', 'products', 'id', ['delete' => 'CASCADE', 'update' => 'CASCADE'])
            ->addIndex(['set_id'])
            ->create();

        $this->table('sessions')
            ->addColumn('set_id', 'integer', ['null' => true, 'signed' => false, 'after' => 'tariff_name_snapshot'])
            ->addColumn('set_name_snapshot', 'string', ['limit' => 120, 'null' => true, 'after' => 'set_id'])
            ->addColumn('set_price_snapshot', 'decimal', ['precision' => 10, 'scale' => 2, 'null' => true, 'after' => 'set_name_snapshot'])
            ->update();

        $this->table('session_items')
            ->addColumn('is_set_item', 'boolean', ['default' => false, 'after' => 'unit_price'])
            ->update();
    }
}
