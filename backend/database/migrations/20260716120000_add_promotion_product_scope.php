<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddPromotionProductScope extends AbstractMigration
{
    public function up(): void
    {
        $this->execute(
            "ALTER TABLE promotions
             MODIFY COLUMN applies_to ENUM('time_only', 'products') NOT NULL DEFAULT 'time_only',
             MODIFY COLUMN scope ENUM('all_tables', 'tariffs', 'products') NOT NULL DEFAULT 'all_tables'"
        );

        if (!$this->table('promotions')->hasColumn('product_ids')) {
            $this->table('promotions')
                ->addColumn('product_ids', 'text', [
                    'null' => true,
                    'after' => 'tariff_names',
                    'comment' => 'JSON array of product IDs when scope=products',
                ])
                ->update();
        }
    }

    public function down(): void
    {
        if ($this->table('promotions')->hasColumn('product_ids')) {
            $this->table('promotions')->removeColumn('product_ids')->update();
        }

        $this->execute(
            "UPDATE promotions SET scope = 'all_tables', applies_to = 'time_only' WHERE scope = 'products'"
        );
        $this->execute(
            "ALTER TABLE promotions
             MODIFY COLUMN applies_to ENUM('time_only') NOT NULL DEFAULT 'time_only',
             MODIFY COLUMN scope ENUM('all_tables', 'tariffs') NOT NULL DEFAULT 'all_tables'"
        );
    }
}
