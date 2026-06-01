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

if (in_array('sqlite', PDO::getAvailableDrivers(), true)) {
    $pdo = new PDO('sqlite::memory:');
    $service = new PromotionService($pdo, new \App\Support\CustomerGroupService($pdo));
    $cashier = ['role' => 'cashier'];

    assertNotNull($service->validateManualDiscount($cashier, 'percent', 31, 20), 'cashier over cap');
    assertNull($service->validateManualDiscount($cashier, 'percent', 30, 20), 'cashier at cap');
    assertNull($service->validateManualDiscount(['role' => 'admin'], 'percent', 50, 20), 'admin no cap');
} else {
    echo "SKIP PromotionService PDO tests (sqlite driver unavailable)\n";
}

exit($failures > 0 ? 1 : 0);
