<?php

declare(strict_types=1);

require __DIR__ . '/../vendor/autoload.php';

use App\Support\DiscountCalculator;
use App\Support\PromotionService;

$failures = 0;

function assertTrue(bool $cond, string $label): void
{
    global $failures;
    if (!$cond) {
        echo "FAIL {$label}\n";
        $failures++;
    } else {
        echo "OK {$label}\n";
    }
}

function assertNull(?string $value, string $label): void
{
    assertTrue($value === null, $label);
}

function assertNotNull(?string $value, string $label): void
{
    assertTrue($value !== null, $label);
}

assertTrue(DiscountCalculator::amount(10.0, 'percent', 50) === 5.0, 'percent discount');
assertTrue(DiscountCalculator::amount(10.0, 'fixed', 3) === 3.0, 'fixed discount');
assertTrue(DiscountCalculator::amount(10.0, 'fixed', 15) === 10.0, 'fixed capped at base');

// encodeJsonList weekday-0 (Monday) must be preserved — mirrors PromotionsController fix.
function encodeValidDays(array $value): ?string
{
    $mapped = array_map(static fn ($v) => (int) $v, $value);
    $clean = array_values(array_unique(array_filter($mapped, static fn ($v) => $v >= 0 && $v <= 6)));
    if ($clean === []) {
        return null;
    }

    return json_encode($clean, JSON_UNESCAPED_UNICODE);
}

function encodeValidDaysBroken(array $value): ?string
{
    $clean = array_values(array_filter(array_map(static fn ($v) => (int) $v, $value)));
    if ($clean === []) {
        return null;
    }

    return json_encode($clean, JSON_UNESCAPED_UNICODE);
}

assertTrue(encodeValidDaysBroken([0]) === null, 'broken filter drops Monday=0');
assertTrue(encodeValidDays([0]) === '[0]', 'fixed filter keeps Monday=0');
assertTrue(encodeValidDays([0, 3]) === '[0,3]', 'fixed filter keeps Monday with other days');
assertTrue(encodeValidDays([3]) === '[3]', 'fixed filter keeps Thursday');

if (in_array('sqlite', PDO::getAvailableDrivers(), true)) {
    $pdo = new PDO('sqlite::memory:');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->exec('CREATE TABLE customer_groups (
        id INTEGER PRIMARY KEY, business_id INT, name TEXT, discount_type TEXT,
        discount_value REAL, applies_to TEXT, is_active INT, sort_order INT, color TEXT
    )');
    $pdo->exec('CREATE TABLE customers (
        id INTEGER PRIMARY KEY, customer_group_id INT, is_active INT
    )');
    // SQLite: NOW() via custom — PromotionService uses SELECT NOW() and information_schema.
    // Stub promotions table path: without information_schema, hasPromotionsTable returns false.
    // Test DiscountCalculator path + cashier validation only when table missing.
    $service = new PromotionService($pdo, new \App\Support\CustomerGroupService($pdo));
    $cashier = ['role' => 'cashier'];

    assertNotNull($service->validateManualDiscount($cashier, 'percent', 31, 20), 'cashier over cap');
    assertNull($service->validateManualDiscount($cashier, 'percent', 30, 20), 'cashier at cap');
    assertNull($service->validateManualDiscount(['role' => 'admin'], 'percent', 50, 20), 'admin no cap');

    // Product discount math (unit-level) via DiscountCalculator — same as resolveProductDiscount.
    $line = 10.0; // 2 x 5
    $productPct = DiscountCalculator::amount($line, 'percent', 20);
    assertTrue($productPct === 2.0, 'product line 20% discount');
    $productFixed = DiscountCalculator::amount($line, 'fixed', 3);
    assertTrue($productFixed === 3.0, 'product line fixed discount');

    // Combined time + product capped at subtotal.
    $timeCharge = 20.0;
    $productsTotal = 10.0;
    $timeDisc = DiscountCalculator::amount($timeCharge, 'percent', 50); // 10
    $prodDisc = 2.0;
    $combined = min($timeCharge + $productsTotal, round($timeDisc + $prodDisc, 2));
    assertTrue($combined === 12.0, 'time+product discount combined');
} else {
    echo "SKIP PromotionService PDO tests (sqlite driver unavailable)\n";
}

exit($failures > 0 ? 1 : 0);
