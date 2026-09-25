<?php

declare(strict_types=1);

require __DIR__ . '/../vendor/autoload.php';

use App\Support\CustomerGroupService;
use App\Support\LoyaltyService;
use App\Support\PromotionService;
use App\Support\SessionCloseRules;
use App\Support\SpendDiscountService;

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

assertTrue(PromotionService::encodeValidDays([0]) === '[0]', 'monday 0 kept');
assertTrue(PromotionService::encodeValidDays([0, 3]) === '[0,3]', 'monday with thursday');
assertTrue(PromotionService::encodeValidDays([]) === null, 'empty days means every day');

$monday = new DateTimeImmutable('2026-08-17 12:00:00');
$tuesday = new DateTimeImmutable('2026-08-18 12:00:00');
assertTrue(PromotionService::isWithinTimeWindow(['valid_days' => '[0]'], $monday), 'monday promo on monday');
assertTrue(!PromotionService::isWithinTimeWindow(['valid_days' => '[0]'], $tuesday), 'monday promo hidden on tuesday');

assertTrue(
    SessionCloseRules::counterZeroTotalError(2, 0, 0, 80, 0, '') === null,
    'bonus wallet covers counter sale'
);
assertTrue(
    SessionCloseRules::counterZeroTotalError(2, 0, 0, 0, 0, '') !== null,
    'zero total without bonus or gift rejected'
);
assertTrue(
    SessionCloseRules::counterZeroTotalError(2, 0, 80, 0, 0, '') === 'Hədiyyə üçün qeyd yazın',
    'gift without note rejected'
);
assertTrue(
    SessionCloseRules::counterZeroTotalError(2, 0, 80, 0, 0, 'dostum') === null,
    'gift with note allowed'
);

if (!in_array('sqlite', PDO::getAvailableDrivers(), true)) {
    echo "SKIP sqlite scenarios\n";
    exit($failures > 0 ? 1 : 0);
}

$pdo = new PDO('sqlite::memory:');
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$pdo->exec('CREATE TABLE customers (
    id INTEGER PRIMARY KEY,
    name TEXT,
    phone TEXT,
    email TEXT,
    is_active INT,
    customer_group_id INT,
    bonus_minutes INT DEFAULT 0,
    bonus_wallet REAL DEFAULT 0,
    updated_at TEXT
)');
$pdo->exec('CREATE TABLE loyalty_ledger (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INT,
    entry_type TEXT,
    minutes_delta INT,
    wallet_delta REAL,
    note TEXT,
    session_id INT,
    created_by INT,
    created_at TEXT
)');
$pdo->exec('CREATE TABLE customer_groups (
    id INTEGER PRIMARY KEY,
    business_id INT,
    name TEXT,
    is_active INT
)');
$pdo->exec('CREATE TABLE sessions (
    id INTEGER PRIMARY KEY,
    customer_id INT,
    status TEXT,
    order_state TEXT,
    time_charge REAL,
    products_total REAL,
    closed_at TEXT
)');
$pdo->exec('CREATE TABLE spend_discount_rules (
    id INTEGER PRIMARY KEY,
    business_id INT,
    name TEXT,
    min_spend REAL,
    window_type TEXT,
    window_days INT,
    discount_type TEXT,
    discount_value REAL,
    applies_to TEXT,
    is_active INT,
    sort_order INT
)');

$pdo->exec("INSERT INTO customers (id, name, is_active, bonus_minutes, bonus_wallet) VALUES (1, 'Kenan', 1, 0, 0)");
$loyalty = new LoyaltyService($pdo);
$loyalty->adminGrant(1, 'hours', 6000, '100 saat', 1);
$loyalty->adminAdjust(1, 'hours', -600, '10 saat silindi', 1);
$balance = $loyalty->getBalance(1);
assertTrue($balance['bonus_minutes'] === 5400, 'hour balance after removing 10 hours');
$loyalty->adminGrant(1, 'wallet', 100, null, 1);
$loyalty->adminAdjust(1, 'wallet', -120, 'artıq manatı sil', 1);
$balance = $loyalty->getBalance(1);
assertTrue(abs($balance['bonus_wallet']) < 0.001, 'wallet does not go below zero');
$ledger = $loyalty->getLedger(1);
assertTrue(count($ledger) >= 3, 'ledger records grant and adjust');

$pdo->exec("INSERT INTO customer_groups (id, business_id, name, is_active) VALUES (5, 1, 'VIP', 1)");
$pdo->exec("INSERT INTO customers (id, name, is_active) VALUES (2, 'A', 1), (3, 'B', 1)");
$groups = new CustomerGroupService($pdo);
$groups->changeMembers(5, [2, 3], []);
$members = $groups->listMembers(5);
assertTrue(count($members) === 2, 'two customers added to group');
$groups->changeMembers(5, [], [3]);
$members = $groups->listMembers(5);
assertTrue(count($members) === 1 && (int) $members[0]['id'] === 2, 'one customer removed from group');

$now = new DateTimeImmutable('2026-09-25 12:00:00');
$pdo->exec("INSERT INTO spend_discount_rules
    (id, business_id, name, min_spend, window_type, window_days, discount_type, discount_value, applies_to, is_active, sort_order)
    VALUES
    (1, 1, '100+', 100, 'lifetime', NULL, 'percent', 10, 'all', 1, 0),
    (2, 1, '200+', 200, 'lifetime', NULL, 'percent', 20, 'all', 1, 0),
    (3, 1, 'ay', 50, 'rolling_days', 7, 'percent', 15, 'all', 1, 0)");
$pdo->exec("INSERT INTO sessions (id, customer_id, status, order_state, time_charge, products_total, closed_at)
    VALUES (10, 1, 'closed', 'paid', 0, 150, '2026-09-20 10:00:00')");
$spend = new SpendDiscountService($pdo);
$low = $spend->resolve(2, 0, 80, $now);
assertTrue($low['amount'] === 0.0, 'below threshold no discount');
$mid = $spend->resolve(1, 0, 80, $now);
assertTrue(abs($mid['amount'] - 8.0) < 0.001, '150 spend gets 10 percent of 80');
$pdo->exec("UPDATE sessions SET products_total = 250 WHERE id = 10");
$high = $spend->resolve(1, 0, 80, $now);
assertTrue(abs($high['amount'] - 16.0) < 0.001 && ($high['rule']['name'] ?? '') === '200+', 'higher threshold wins');
$pdo->exec("UPDATE sessions SET closed_at = '2026-01-01 00:00:00', products_total = 500 WHERE id = 10");
$pdo->exec('UPDATE spend_discount_rules SET is_active = 0 WHERE id IN (1, 2)');
$expired = $spend->resolve(1, 0, 80, $now);
assertTrue($expired['amount'] === 0.0, 'rolling window excludes old spend');

exit($failures > 0 ? 1 : 0);
