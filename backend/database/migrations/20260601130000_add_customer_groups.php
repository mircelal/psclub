<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddCustomerGroups extends AbstractMigration
{
    public function change(): void
    {
        $this->table('customer_groups', ['id' => false, 'primary_key' => ['id']])
            ->addColumn('id', 'integer', ['identity' => true, 'signed' => false])
            ->addColumn('business_id', 'integer', ['default' => 1, 'signed' => false])
            ->addColumn('name', 'string', ['limit' => 120])
            ->addColumn('description', 'text', ['null' => true])
            ->addColumn('discount_type', 'enum', ['values' => ['percent', 'fixed']])
            ->addColumn('discount_value', 'decimal', ['precision' => 10, 'scale' => 2])
            ->addColumn('applies_to', 'enum', ['values' => ['time_only', 'all'], 'default' => 'time_only'])
            ->addColumn('color', 'string', ['limit' => 16, 'null' => true])
            ->addColumn('is_active', 'boolean', ['default' => true])
            ->addColumn('sort_order', 'integer', ['default' => 0])
            ->addColumn('created_at', 'datetime')
            ->addColumn('updated_at', 'datetime')
            ->create();

        $this->table('customers')
            ->addColumn('customer_group_id', 'integer', [
                'null' => true,
                'signed' => false,
                'after' => 'notes',
            ])
            ->addForeignKey('customer_group_id', 'customer_groups', 'id', [
                'delete' => 'SET_NULL',
                'update' => 'CASCADE',
            ])
            ->update();

        if ($this->isMigratingUp()) {
            $this->seedDefaultGroups();
        }
    }

    private function seedDefaultGroups(): void
    {
        $rows = [
            ['VIP', 'Daimi müştərilər — uzunmüddətli loyallıq', 'percent', 10, 'time_only', '#7C6CF0', 10],
            ['Tələbə', 'Tələbə bileti ilə — adətən vaxt haqqına', 'percent', 15, 'time_only', '#34C759', 20],
            ['Uşaq', '12 yaşadək — ailə paketləri ilə', 'percent', 20, 'time_only', '#FF9500', 30],
            ['Komanda / Turnir', 'Komanda rezervasiyası və turnir qrupları', 'percent', 25, 'time_only', '#5856D6', 40],
            ['İşçi', 'Klub əməkdaşları', 'percent', 30, 'time_only', '#8E8E93', 50],
            ['Korporativ', 'Şirkət müqaviləsi — vaxt + məhsul', 'percent', 10, 'all', '#007AFF', 60],
            ['Yeni müştəri', 'İlk ziyarət təşviqi', 'percent', 10, 'time_only', '#FF2D55', 70],
            ['Referral', 'Dost gətirən müştəri', 'percent', 5, 'time_only', '#30B0C7', 80],
        ];

        foreach ($rows as [$name, $desc, $type, $value, $applies, $color, $sort]) {
            $this->table('customer_groups')->insert([
                'business_id' => 1,
                'name' => $name,
                'description' => $desc,
                'discount_type' => $type,
                'discount_value' => $value,
                'applies_to' => $applies,
                'color' => $color,
                'is_active' => 1,
                'sort_order' => $sort,
                'created_at' => date('Y-m-d H:i:s'),
                'updated_at' => date('Y-m-d H:i:s'),
            ])->saveData();
        }
    }
}
