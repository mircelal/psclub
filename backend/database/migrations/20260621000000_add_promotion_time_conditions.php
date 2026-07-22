<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddPromotionTimeConditions extends AbstractMigration
{
    public function change(): void
    {
        $this->table('promotions')
            ->addColumn('valid_days', 'text', ['null' => true, 'comment' => 'JSON array of weekdays (0=Monday, 6=Sunday) or null for all'])
            ->addColumn('valid_hours', 'text', ['null' => true, 'comment' => 'JSON array of {from: HH:MM, until: HH:MM} ranges or null for all day'])
            ->update();
    }
}
