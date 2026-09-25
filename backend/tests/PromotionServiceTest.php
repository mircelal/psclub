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

assertTrue(PromotionService::normalizeValidFrom('2026-06-01') === '2026-06-01 00:00:00', 'valid_from start of day');
assertTrue(PromotionService::normalizeValidUntil('2026-06-01 12:00:00') === '2026-06-01 23:59:59', 'valid_until end of day');
assertTrue(PromotionService::parseDateOnly('2026-02-31') === null, 'invalid calendar day rejected');
assertTrue(PromotionService::parseDateOnly('foo') === null, 'garbage date rejected');
assertTrue(PromotionService::parseClockMinutes('abc') === null, 'invalid clock rejected');
assertTrue(PromotionService::parseClockMinutes('25:00') === null, 'hour 25 rejected');
assertTrue(PromotionService::parseClockMinutes('9:00') === 540, 'H:mm accepted');
assertTrue(PromotionService::parseClockMinutes('18:00') === 18 * 60, '18:00 minutes');

$singleDayFrom = '2026-06-01 00:00:00';
$singleDayUntil = '2026-06-01 23:59:59';
assertTrue(PromotionService::isWithinDateRange($singleDayFrom, $singleDayUntil, new DateTimeImmutable('2026-06-01 10:00:00')), 'specific day active');
assertTrue(!PromotionService::isWithinDateRange($singleDayFrom, $singleDayUntil, new DateTimeImmutable('2026-06-02 00:00:00')), 'next day inactive');
assertTrue(PromotionService::isWithinDateRange('2026-06-01 00:00:00', '2026-06-07 23:59:59', new DateTimeImmutable('2026-06-07 23:59:59')), 'range last second active');
assertTrue(!PromotionService::isWithinDateRange('2026-06-01 00:00:00', '2026-06-07 23:59:59', new DateTimeImmutable('2026-06-08 00:00:00')), 'range next day inactive');

$hoursPromo = ['valid_hours' => json_encode([['from' => '09:00', 'until' => '18:00']])];
assertTrue(PromotionService::isWithinTimeWindow($hoursPromo, new DateTimeImmutable('2026-08-16 18:00:00')), 'until 18:00 inclusive');
assertTrue(!PromotionService::isWithinTimeWindow($hoursPromo, new DateTimeImmutable('2026-08-16 18:01:00')), '18:01 outside window');
assertTrue(!PromotionService::isWithinTimeWindow($hoursPromo, new DateTimeImmutable('2026-08-16 08:59:00')), '08:59 outside window');
assertTrue(!PromotionService::isWithinTimeWindow(['valid_hours' => json_encode([['from' => 'abc', 'until' => 'def']])], new DateTimeImmutable('2026-08-16 12:00:00')), 'invalid hours do not match');

$sundayPromo = ['valid_days' => json_encode([6])];
assertTrue(PromotionService::isWithinTimeWindow($sundayPromo, new DateTimeImmutable('2026-08-16 12:00:00')), 'Sunday promo on Sunday');
assertTrue(!PromotionService::isWithinTimeWindow($sundayPromo, new DateTimeImmutable('2026-08-17 12:00:00')), 'Sunday promo not on Monday');

$overnight = ['valid_hours' => json_encode([['from' => '22:00', 'until' => '06:00']])];
assertTrue(PromotionService::isWithinTimeWindow($overnight, new DateTimeImmutable('2026-08-16 23:00:00')), 'overnight late');
assertTrue(PromotionService::isWithinTimeWindow($overnight, new DateTimeImmutable('2026-08-16 06:00:00')), 'overnight until inclusive');
assertTrue(!PromotionService::isWithinTimeWindow($overnight, new DateTimeImmutable('2026-08-16 06:01:00')), 'overnight after until');

$sundayRow = ['name' => 'Bazar', 'valid_days' => '[6]', 'valid_from' => null, 'valid_until' => null];
$juneRow = ['name' => '1 iyun', 'valid_from' => '2026-06-01 00:00:00', 'valid_until' => '2026-06-01 23:59:59', 'valid_days' => null];
$filteredSun = PromotionService::filterCurrentlyActive([$sundayRow, $juneRow], new DateTimeImmutable('2026-08-16 12:00:00'));
assertTrue(array_map(static fn ($p) => $p['name'], $filteredSun) === ['Bazar'], 'listActive Sunday promo on Sunday');
$filteredMon = PromotionService::filterCurrentlyActive([$sundayRow, $juneRow], new DateTimeImmutable('2026-08-17 12:00:00'));
assertTrue($filteredMon === [], 'listActive Sunday promo hidden on Monday');
$filteredJune = PromotionService::filterCurrentlyActive([$sundayRow, $juneRow], new DateTimeImmutable('2026-06-01 10:00:00'));
assertTrue(array_map(static fn ($p) => $p['name'], $filteredJune) === ['1 iyun'], 'listActive specific day on that day');

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
    $service = new PromotionService($pdo, new \App\Support\CustomerGroupService($pdo));
    $cashier = ['role' => 'cashier'];

    assertNotNull($service->validateManualDiscount($cashier, 'percent', 31, 20), 'cashier over cap');
    assertNull($service->validateManualDiscount($cashier, 'percent', 30, 20), 'cashier at cap');
    assertNull($service->validateManualDiscount(['role' => 'admin'], 'percent', 50, 20), 'admin no cap');

    $line = 10.0;
    $productPct = DiscountCalculator::amount($line, 'percent', 20);
    assertTrue($productPct === 2.0, 'product line 20% discount');
    $productFixed = DiscountCalculator::amount($line, 'fixed', 3);
    assertTrue($productFixed === 3.0, 'product line fixed discount');

    $timeCharge = 20.0;
    $productsTotal = 10.0;
    $timeDisc = DiscountCalculator::amount($timeCharge, 'percent', 50);
    $prodDisc = 2.0;
    $combined = min($timeCharge + $productsTotal, round($timeDisc + $prodDisc, 2));
    assertTrue($combined === 12.0, 'time+product discount combined');
} else {
    echo "SKIP PromotionService PDO tests (sqlite driver unavailable)\n";
}

exit($failures > 0 ? 1 : 0);
