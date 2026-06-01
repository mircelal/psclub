<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddPromotions extends AbstractMigration
{
    public function change(): void
    {
        $this->table('promotions', ['id' => false, 'primary_key' => ['id']])
            ->addColumn('id', 'integer', ['identity' => true, 'signed' => false])
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('name', 'string', ['limit' => 120])
            ->addColumn('discount_type', 'enum', ['values' => ['percent', 'fixed']])
            ->addColumn('discount_value', 'decimal', ['precision' => 10, 'scale' => 2])
            ->addColumn('applies_to', 'enum', ['values' => ['time_only'], 'default' => 'time_only'])
            ->addColumn('scope', 'enum', ['values' => ['all_tables', 'tariffs']])
            ->addColumn('tariff_names', 'text', ['null' => true, 'comment' => 'JSON array when scope=tariffs'])
            ->addColumn('is_active', 'boolean', ['default' => true])
            ->addColumn('valid_from', 'datetime', ['null' => true])
            ->addColumn('valid_until', 'datetime', ['null' => true])
            ->addColumn('sort_order', 'integer', ['default' => 0])
            ->addColumn('created_at', 'datetime')
            ->addColumn('updated_at', 'datetime')
            ->create();

        $this->table('sessions')
            ->addColumn('discount_applies_to', 'enum', [
                'values' => ['all', 'time_only'],
                'default' => 'time_only',
                'after' => 'discount_value',
            ])
            ->addColumn('promotion_id', 'integer', [
                'null' => true,
                'signed' => false,
                'after' => 'coupon_id',
            ])
            ->addForeignKey('promotion_id', 'promotions', 'id', [
                'delete' => 'SET_NULL',
                'update' => 'CASCADE',
            ])
            ->update();
    }
}
