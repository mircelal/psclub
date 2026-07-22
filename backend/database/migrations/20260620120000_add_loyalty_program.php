<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddLoyaltyProgram extends AbstractMigration
{
    public function change(): void
    {
        $this->table('customers')
            ->addColumn('bonus_minutes', 'integer', [
                'default' => 0,
                'signed' => false,
                'after' => 'customer_group_id',
            ])
            ->addColumn('bonus_wallet', 'decimal', [
                'precision' => 10,
                'scale' => 2,
                'default' => 0,
                'after' => 'bonus_minutes',
            ])
            ->update();

        $this->table('loyalty_tiers', ['id' => false, 'primary_key' => ['id']])
            ->addColumn('id', 'integer', ['identity' => true, 'signed' => false])
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('name', 'string', ['limit' => 120])
            ->addColumn('spend_threshold', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 500])
            ->addColumn('reward_kind', 'enum', [
                'values' => ['hours', 'hours_percent', 'wallet_percent', 'wallet_fixed'],
            ])
            ->addColumn('reward_value', 'decimal', ['precision' => 10, 'scale' => 2])
            ->addColumn('reference_hourly_rate', 'decimal', [
                'precision' => 10,
                'scale' => 2,
                'null' => true,
                'comment' => 'hours_percent üçün saatlıq tarif (boşdursa 10 AZN)',
            ])
            ->addColumn('is_active', 'boolean', ['default' => true])
            ->addColumn('sort_order', 'integer', ['default' => 0])
            ->addColumn('created_at', 'datetime')
            ->addColumn('updated_at', 'datetime')
            ->create();

        $this->table('loyalty_ledger', ['id' => false, 'primary_key' => ['id']])
            ->addColumn('id', 'integer', ['identity' => true, 'signed' => false])
            ->addColumn('customer_id', 'integer', ['signed' => false])
            ->addColumn('entry_type', 'enum', [
                'values' => ['tier_earn', 'admin_hours', 'admin_wallet', 'redeem_hours', 'redeem_wallet', 'adjust'],
            ])
            ->addColumn('minutes_delta', 'integer', ['default' => 0])
            ->addColumn('wallet_delta', 'decimal', ['precision' => 10, 'scale' => 2, 'default' => 0])
            ->addColumn('session_id', 'integer', ['null' => true, 'signed' => false])
            ->addColumn('tier_id', 'integer', ['null' => true, 'signed' => false])
            ->addColumn('note', 'text', ['null' => true])
            ->addColumn('created_by', 'integer', ['null' => true, 'signed' => false])
            ->addColumn('created_at', 'datetime')
            ->addForeignKey('customer_id', 'customers', 'id', ['delete' => 'CASCADE'])
            ->addForeignKey('session_id', 'sessions', 'id', ['delete' => 'SET_NULL'])
            ->addForeignKey('tier_id', 'loyalty_tiers', 'id', ['delete' => 'SET_NULL'])
            ->addIndex(['customer_id', 'created_at'])
            ->create();

        $this->table('sessions')
            ->addColumn('bonus_minutes_used', 'integer', [
                'default' => 0,
                'signed' => false,
                'after' => 'coupon_id',
            ])
            ->addColumn('bonus_wallet_used', 'decimal', [
                'precision' => 10,
                'scale' => 2,
                'default' => 0,
                'after' => 'bonus_minutes_used',
            ])
            ->update();
    }
}
