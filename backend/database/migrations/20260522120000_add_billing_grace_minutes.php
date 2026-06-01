<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddBillingGraceMinutes extends AbstractMigration
{
    public function change(): void
    {
        $this->table('businesses')
            ->addColumn('billing_grace_minutes', 'integer', [
                'default' => 10,
                'signed' => false,
                'after' => 'billing_increment_minutes',
            ])
            ->update();
    }
}
