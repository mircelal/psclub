<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddBillingTimingRules extends AbstractMigration
{
    public function change(): void
    {
        $this->table('businesses')
            ->addColumn('min_open_minutes', 'integer', [
                'default' => 60,
                'signed' => false,
                'after' => 'time_billing_enabled',
            ])
            ->addColumn('extend_step_minutes', 'integer', [
                'default' => 30,
                'signed' => false,
                'after' => 'min_open_minutes',
            ])
            ->addColumn('min_billing_minutes', 'integer', [
                'default' => 60,
                'signed' => false,
                'after' => 'extend_step_minutes',
            ])
            ->addColumn('billing_increment_minutes', 'integer', [
                'default' => 30,
                'signed' => false,
                'after' => 'min_billing_minutes',
            ])
            ->update();

        $this->execute(
            "ALTER TABLE businesses MODIFY billing_mode ENUM(
                'per_minute','block_30','block_60','min_1h_then_30'
            ) NOT NULL DEFAULT 'per_minute'"
        );
    }
}
