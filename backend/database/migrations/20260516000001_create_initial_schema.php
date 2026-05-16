<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class CreateInitialSchema extends AbstractMigration
{
    public function change(): void
    {
        $this->table('businesses', ['id' => false, 'primary_key' => ['id']])
            ->addColumn('id', 'integer', ['identity' => true, 'signed' => false])
            ->addColumn('name', 'string', ['limit' => 150])
            ->addColumn('currency', 'string', ['limit' => 10, 'default' => 'AZN'])
            ->addColumn('billing_mode', 'enum', ['values' => ['per_minute', 'block_30', 'block_60'], 'default' => 'per_minute'])
            ->addColumn('billing_rounding', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 0.01])
            ->addColumn('min_stock_threshold', 'integer', ['default' => 5])
            ->addTimestamps()
            ->create();

        $this->table('users')
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('username', 'string', ['limit' => 80])
            ->addColumn('password_hash', 'string', ['limit' => 255])
            ->addColumn('full_name', 'string', ['limit' => 150, 'null' => true])
            ->addColumn('role', 'enum', ['values' => ['admin', 'cashier']])
            ->addColumn('is_active', 'boolean', ['default' => true])
            ->addTimestamps()
            ->addIndex(['username'], ['unique' => true])
            ->create();

        $this->table('tables')
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('name', 'string', ['limit' => 100])
            ->addColumn('hourly_rate', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 5.00])
            ->addColumn('status', 'enum', ['values' => ['empty', 'active', 'paused', 'closed'], 'default' => 'empty'])
            ->addColumn('sort_order', 'integer', ['default' => 0])
            ->addColumn('is_active', 'boolean', ['default' => true])
            ->addTimestamps()
            ->create();

        $this->table('product_categories')
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('name', 'string', ['limit' => 100])
            ->addColumn('sort_order', 'integer', ['default' => 0])
            ->addTimestamps()
            ->create();

        $this->table('products')
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('category_id', 'integer', ['null' => true])
            ->addColumn('name', 'string', ['limit' => 150])
            ->addColumn('sku', 'string', ['limit' => 50, 'null' => true])
            ->addColumn('price', 'decimal', ['precision' => 10, 'scale' => 2])
            ->addColumn('is_active', 'boolean', ['default' => true])
            ->addTimestamps()
            ->create();

        $this->table('product_stock')
            ->addColumn('product_id', 'integer')
            ->addColumn('quantity', 'integer', ['default' => 0])
            ->addTimestamps()
            ->addIndex(['product_id'], ['unique' => true])
            ->create();

        $this->table('stock_movements')
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('product_id', 'integer')
            ->addColumn('type', 'enum', ['values' => ['in', 'out', 'sale', 'adjustment']])
            ->addColumn('quantity', 'integer')
            ->addColumn('reference_type', 'string', ['limit' => 50, 'null' => true])
            ->addColumn('reference_id', 'integer', ['null' => true])
            ->addColumn('note', 'text', ['null' => true])
            ->addColumn('created_by', 'integer', ['null' => true])
            ->addColumn('created_at', 'datetime', ['default' => 'CURRENT_TIMESTAMP'])
            ->create();

        $this->table('sessions')
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('table_id', 'integer')
            ->addColumn('opened_by', 'integer')
            ->addColumn('closed_by', 'integer', ['null' => true])
            ->addColumn('status', 'enum', ['values' => ['active', 'paused', 'closed'], 'default' => 'active'])
            ->addColumn('opened_at', 'datetime')
            ->addColumn('closed_at', 'datetime', ['null' => true])
            ->addColumn('hourly_rate_snapshot', 'decimal', ['precision' => 10, 'scale' => 2])
            ->addColumn('time_charge', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 0])
            ->addColumn('products_total', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 0])
            ->addColumn('discount', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 0])
            ->addColumn('total_amount', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 0])
            ->addColumn('active_seconds', 'integer', ['default' => 0])
            ->addTimestamps()
            ->create();

        $this->table('session_pauses')
            ->addColumn('session_id', 'integer')
            ->addColumn('paused_at', 'datetime')
            ->addColumn('resumed_at', 'datetime', ['null' => true])
            ->create();

        $this->table('session_items')
            ->addColumn('session_id', 'integer')
            ->addColumn('product_id', 'integer')
            ->addColumn('product_name', 'string', ['limit' => 150])
            ->addColumn('quantity', 'integer', ['default' => 1])
            ->addColumn('unit_price', 'decimal', ['precision' => 10, 'scale' => 2])
            ->addColumn('created_at', 'datetime', ['default' => 'CURRENT_TIMESTAMP'])
            ->create();

        $this->table('payments')
            ->addColumn('session_id', 'integer')
            ->addColumn('method', 'enum', ['values' => ['cash', 'card', 'mixed']])
            ->addColumn('cash_amount', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 0])
            ->addColumn('card_amount', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 0])
            ->addColumn('total_amount', 'decimal', ['precision' => 10, 'scale' => 2])
            ->addColumn('created_at', 'datetime', ['default' => 'CURRENT_TIMESTAMP'])
            ->create();

        $this->table('receipts')
            ->addColumn('session_id', 'integer')
            ->addColumn('receipt_number', 'string', ['limit' => 50])
            ->addColumn('payload', 'text')
            ->addColumn('pdf_path', 'string', ['limit' => 255, 'null' => true])
            ->addColumn('created_at', 'datetime', ['default' => 'CURRENT_TIMESTAMP'])
            ->create();

        $this->table('daily_closings')
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('closing_date', 'date')
            ->addColumn('snapshot', 'text')
            ->addColumn('closed_by', 'integer')
            ->addColumn('created_at', 'datetime', ['default' => 'CURRENT_TIMESTAMP'])
            ->addIndex(['closing_date', 'business_id'], ['unique' => true])
            ->create();

        $this->table('audit_logs')
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('actor_id', 'integer', ['null' => true])
            ->addColumn('action', 'string', ['limit' => 100])
            ->addColumn('entity_type', 'string', ['limit' => 50, 'null' => true])
            ->addColumn('entity_id', 'integer', ['null' => true])
            ->addColumn('payload', 'text', ['null' => true])
            ->addColumn('ip_address', 'string', ['limit' => 45, 'null' => true])
            ->addColumn('created_at', 'datetime', ['default' => 'CURRENT_TIMESTAMP'])
            ->create();

        $this->table('settings')
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('key', 'string', ['limit' => 100])
            ->addColumn('value', 'text', ['null' => true])
            ->addIndex(['business_id', 'key'], ['unique' => true])
            ->create();
    }
}
