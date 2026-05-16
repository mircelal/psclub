<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddTableTariffs extends AbstractMigration
{
    public function change(): void
    {
        $this->table('table_tariffs')
            ->addColumn('table_id', 'integer', ['signed' => false])
            ->addColumn('name', 'string', ['limit' => 100])
            ->addColumn('hourly_rate', 'decimal', ['precision' => 10, 'scale' => 2])
            ->addColumn('sort_order', 'integer', ['default' => 0])
            ->addColumn('is_active', 'boolean', ['default' => true])
            ->addTimestamps()
            ->addIndex(['table_id'])
            ->addForeignKey('table_id', 'tables', 'id', ['delete' => 'CASCADE', 'update' => 'CASCADE'])
            ->create();

        $this->table('sessions')
            ->addColumn('tariff_id', 'integer', ['null' => true, 'signed' => false, 'after' => 'hourly_rate_snapshot'])
            ->addColumn('tariff_name_snapshot', 'string', ['limit' => 100, 'null' => true, 'after' => 'tariff_id'])
            ->update();

        $this->execute(
            "INSERT INTO table_tariffs (table_id, name, hourly_rate, sort_order, is_active, created_at, updated_at)
             SELECT id, 'Standart', hourly_rate, 0, 1, NOW(), NOW()
             FROM tables
             WHERE is_active = 1"
        );
    }
}
