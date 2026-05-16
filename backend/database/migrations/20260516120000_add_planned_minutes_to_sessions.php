<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddPlannedMinutesToSessions extends AbstractMigration
{
    public function change(): void
    {
        $this->table('sessions')
            ->addColumn('planned_minutes', 'integer', ['null' => true, 'after' => 'hourly_rate_snapshot'])
            ->update();
    }
}
