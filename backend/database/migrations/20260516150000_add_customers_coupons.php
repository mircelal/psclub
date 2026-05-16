<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddCustomersCoupons extends AbstractMigration
{
    public function change(): void
    {
        $this->table('customers', ['id' => false, 'primary_key' => ['id']])
            ->addColumn('id', 'integer', ['identity' => true, 'signed' => false])
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('name', 'string', ['limit' => 120])
            ->addColumn('phone', 'string', ['limit' => 32, 'null' => true])
            ->addColumn('email', 'string', ['limit' => 120, 'null' => true])
            ->addColumn('notes', 'text', ['null' => true])
            ->addColumn('is_active', 'boolean', ['default' => true])
            ->addColumn('created_at', 'datetime')
            ->addColumn('updated_at', 'datetime')
            ->addIndex(['phone'])
            ->addIndex(['name'])
            ->create();

        $this->table('coupons', ['id' => false, 'primary_key' => ['id']])
            ->addColumn('id', 'integer', ['identity' => true, 'signed' => false])
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('code', 'string', ['limit' => 32])
            ->addColumn('name', 'string', ['limit' => 120, 'null' => true])
            ->addColumn('discount_type', 'enum', ['values' => ['percent', 'fixed']])
            ->addColumn('discount_value', 'decimal', ['precision' => 10, 'scale' => 2])
            ->addColumn('valid_from', 'datetime', ['null' => true])
            ->addColumn('valid_until', 'datetime', ['null' => true])
            ->addColumn('max_uses', 'integer', ['default' => 0, 'comment' => '0 = unlimited'])
            ->addColumn('used_count', 'integer', ['default' => 0])
            ->addColumn('is_active', 'boolean', ['default' => true])
            ->addColumn('created_at', 'datetime')
            ->addColumn('updated_at', 'datetime')
            ->addIndex(['code'], ['unique' => true])
            ->create();

        $this->table('coupon_redemptions')
            ->addColumn('coupon_id', 'integer', ['signed' => false])
            ->addColumn('session_id', 'integer', ['signed' => false])
            ->addColumn('discount_amount', 'decimal', ['precision' => 10, 'scale' => 2])
            ->addColumn('redeemed_at', 'datetime')
            ->addForeignKey('coupon_id', 'coupons', 'id', ['delete' => 'CASCADE'])
            ->addForeignKey('session_id', 'sessions', 'id', ['delete' => 'CASCADE'])
            ->create();

        $this->table('sessions')
            ->addColumn('session_type', 'enum', ['values' => ['table', 'counter'], 'default' => 'table', 'after' => 'table_id'])
            ->addColumn('customer_id', 'integer', ['null' => true, 'signed' => false, 'after' => 'session_type'])
            ->addColumn('discount_type', 'enum', [
                'values' => ['none', 'fixed', 'percent'],
                'default' => 'none',
                'after' => 'products_total',
            ])
            ->addColumn('discount_value', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 0, 'after' => 'discount_type'])
            ->addColumn('coupon_id', 'integer', ['null' => true, 'signed' => false, 'after' => 'discount_value'])
            ->changeColumn('table_id', 'integer', ['null' => true])
            ->addForeignKey('customer_id', 'customers', 'id', ['delete' => 'SET_NULL', 'update' => 'CASCADE'])
            ->addForeignKey('coupon_id', 'coupons', 'id', ['delete' => 'SET_NULL', 'update' => 'CASCADE'])
            ->update();
    }
}
