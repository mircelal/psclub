<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddLoyaltyGiftSpend extends AbstractMigration
{
    public function change(): void
    {
        $this->table('customers')
            ->addColumn('bonus_minutes', 'integer', ['default' => 0, 'signed' => false])
            ->addColumn('bonus_wallet', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 0])
            ->update();

        $this->table('loyalty_ledger', ['id' => false, 'primary_key' => ['id']])
            ->addColumn('id', 'integer', ['identity' => true, 'signed' => false])
            ->addColumn('customer_id', 'integer', ['signed' => false])
            ->addColumn('entry_type', 'string', ['limit' => 32])
            ->addColumn('minutes_delta', 'integer', ['default' => 0])
            ->addColumn('wallet_delta', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 0])
            ->addColumn('note', 'string', ['limit' => 255, 'null' => true])
            ->addColumn('session_id', 'integer', ['null' => true, 'signed' => false])
            ->addColumn('created_by', 'integer', ['null' => true, 'signed' => false])
            ->addColumn('created_at', 'datetime')
            ->addIndex(['customer_id'])
            ->create();

        $this->table('sessions')
            ->addColumn('bonus_minutes_used', 'integer', ['default' => 0])
            ->addColumn('bonus_wallet_used', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 0])
            ->addColumn('gift_note', 'text', ['null' => true])
            ->update();

        $this->table('promotions')
            ->addColumn('valid_days', 'text', ['null' => true, 'comment' => 'JSON weekdays 0=Monday .. 6=Sunday'])
            ->addColumn('valid_hours', 'text', ['null' => true])
            ->update();

        $this->table('spend_discount_rules', ['id' => false, 'primary_key' => ['id']])
            ->addColumn('id', 'integer', ['identity' => true, 'signed' => false])
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('name', 'string', ['limit' => 120])
            ->addColumn('min_spend', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 0])
            ->addColumn('window_type', 'string', ['limit' => 32, 'default' => 'lifetime'])
            ->addColumn('window_days', 'integer', ['null' => true])
            ->addColumn('discount_type', 'string', ['limit' => 16])
            ->addColumn('discount_value', 'decimal', ['precision' => 10, 'scale' => 2])
            ->addColumn('applies_to', 'string', ['limit' => 16, 'default' => 'all'])
            ->addColumn('is_active', 'boolean', ['default' => true])
            ->addColumn('sort_order', 'integer', ['default' => 0])
            ->addColumn('created_at', 'datetime')
            ->addColumn('updated_at', 'datetime')
            ->create();
    }
}
