<?php

declare(strict_types=1);

use Phinx\Seed\AbstractSeed;

/**
 * Production zip install.sql — yalnız ilkin məlumat (lokal sessiya / test qeydi yoxdur).
 */
class DeploySeeder extends AbstractSeed
{
    private const TS = '2026-01-01 00:00:00';

    public function run(): void
    {
        $this->table('businesses')->insert([
            'name' => 'PS Club',
            'currency' => 'AZN',
            'billing_mode' => 'per_minute',
            'billing_rounding' => 0.01,
            'min_stock_threshold' => 5,
            'created_at' => self::TS,
            'updated_at' => self::TS,
        ])->saveData();

        $this->table('users')->insert([
            [
                'business_id' => 1,
                'username' => 'admin',
                'password_hash' => password_hash('admin', PASSWORD_BCRYPT),
                'full_name' => 'Administrator',
                'role' => 'admin',
                'is_active' => 1,
                'created_at' => self::TS,
                'updated_at' => self::TS,
            ],
            [
                'business_id' => 1,
                'username' => 'kassir',
                'password_hash' => password_hash('kassir', PASSWORD_BCRYPT),
                'full_name' => 'Kassir',
                'role' => 'cashier',
                'is_active' => 1,
                'created_at' => self::TS,
                'updated_at' => self::TS,
            ],
        ])->saveData();

        $tables = [];
        for ($i = 1; $i <= 4; $i++) {
            $tables[] = [
                'business_id' => 1,
                'name' => "Stansiya {$i}",
                'hourly_rate' => 5.00,
                'status' => 'empty',
                'sort_order' => $i,
                'is_active' => 1,
                'created_at' => self::TS,
                'updated_at' => self::TS,
            ];
        }
        $this->table('tables')->insert($tables)->saveData();

        $tariffs = [];
        for ($i = 1; $i <= 4; $i++) {
            $tariffs[] = [
                'table_id' => $i,
                'name' => 'PS5',
                'hourly_rate' => 5.00,
                'sort_order' => 0,
                'is_active' => 1,
                'created_at' => self::TS,
                'updated_at' => self::TS,
            ];
            $tariffs[] = [
                'table_id' => $i,
                'name' => 'PS4',
                'hourly_rate' => 3.00,
                'sort_order' => 1,
                'is_active' => 1,
                'created_at' => self::TS,
                'updated_at' => self::TS,
            ];
        }
        $this->table('table_tariffs')->insert($tariffs)->saveData();

        $this->table('product_categories')->insert([
            ['business_id' => 1, 'name' => 'İçkilər', 'sort_order' => 1, 'created_at' => self::TS, 'updated_at' => self::TS],
            ['business_id' => 1, 'name' => 'Snacks', 'sort_order' => 2, 'created_at' => self::TS, 'updated_at' => self::TS],
        ])->saveData();

        $products = [
            ['business_id' => 1, 'category_id' => 1, 'name' => 'Kola 0.5L', 'sku' => 'DRK-001', 'price' => 2.00, 'is_active' => 1, 'created_at' => self::TS, 'updated_at' => self::TS],
            ['business_id' => 1, 'category_id' => 1, 'name' => 'Enerji içkisi', 'sku' => 'DRK-002', 'price' => 3.50, 'is_active' => 1, 'created_at' => self::TS, 'updated_at' => self::TS],
            ['business_id' => 1, 'category_id' => 2, 'name' => 'Çips', 'sku' => 'SNK-001', 'price' => 2.50, 'is_active' => 1, 'created_at' => self::TS, 'updated_at' => self::TS],
            ['business_id' => 1, 'category_id' => 2, 'name' => 'Şokolad', 'sku' => 'SNK-002', 'price' => 3.00, 'is_active' => 1, 'created_at' => self::TS, 'updated_at' => self::TS],
        ];
        $this->table('products')->insert($products)->saveData();

        $stock = [];
        for ($pid = 1; $pid <= 4; $pid++) {
            $stock[] = ['product_id' => $pid, 'quantity' => 50, 'created_at' => self::TS, 'updated_at' => self::TS];
        }
        $this->table('product_stock')->insert($stock)->saveData();

        $this->table('settings')->insert([
            ['business_id' => 1, 'key' => 'receipt_header', 'value' => 'PS Club'],
            ['business_id' => 1, 'key' => 'receipt_footer', 'value' => 'Təşəkkür edirik!'],
        ])->saveData();
    }
}
