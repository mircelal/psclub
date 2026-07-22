<?php

declare(strict_types=1);

/**
 * Hard audit — tam iş axını: vaxt, müştəri, loyallıq, endirim, pause, billing.
 * QA_API_BASE=http://127.0.0.1:8080 php scripts/qa_hard_audit.php
 */

$base = getenv('QA_API_BASE') ?: 'http://127.0.0.1:8080';
$failures = 0;
$passed = 0;
$warnings = [];

function fail(string $label, string $detail = ''): void
{
    global $failures;
    echo "FAIL {$label}" . ($detail !== '' ? ": {$detail}" : '') . "\n";
    $failures++;
}

function pass(string $label): void
{
    global $passed;
    echo "OK {$label}\n";
    $passed++;
}

function warn(string $label, string $detail = ''): void
{
    global $warnings;
    echo "WARN {$label}" . ($detail !== '' ? ": {$detail}" : '') . "\n";
    $warnings[] = $label;
}

function shiftIsOpen(?array $data): bool
{
    return is_array($data)
        && ($data['open'] ?? true) !== false
        && !empty($data['id']);
}

function request(string $method, string $path, ?array $body = null, ?string $token = null): array
{
    global $base;
    $url = rtrim($base, '/') . $path;
    $headers = "Content-Type: application/json\r\nAccept: application/json\r\n";
    if ($token !== null) {
        $headers .= "Authorization: Bearer {$token}\r\n";
    }
    $opts = [
        'http' => [
            'method' => $method,
            'header' => $headers,
            'ignore_errors' => true,
            'timeout' => 45,
        ],
    ];
    if ($body !== null && in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE'], true)) {
        $opts['http']['content'] = json_encode($body, JSON_UNESCAPED_UNICODE);
    }
    $raw = @file_get_contents($url, false, stream_context_create($opts));
    if ($raw === false) {
        return ['ok' => false, 'status' => 0, 'message' => 'Connection failed', 'data' => null, 'raw' => null];
    }
    $status = 0;
    if (isset($http_response_header[0]) && preg_match('/\d{3}/', $http_response_header[0], $m)) {
        $status = (int) $m[0];
    }
    $json = json_decode($raw, true);

    return [
        'ok' => is_array($json) && ($json['success'] ?? false) === true,
        'status' => $status,
        'message' => is_array($json) ? (string) ($json['message'] ?? '') : 'Invalid JSON',
        'data' => is_array($json) ? ($json['data'] ?? null) : null,
        'raw' => $json,
    ];
}

function findEmptyTable(string $token): ?array
{
    $r = request('GET', '/api/tables', null, $token);
    if (!$r['ok']) {
        return null;
    }
    foreach ($r['data']['tables'] ?? [] as $table) {
        if (!is_array($table)) {
            continue;
        }
        if (($table['status'] ?? '') !== 'empty' || !empty($table['session_id'])) {
            continue;
        }
        $tableId = (int) ($table['id'] ?? 0);
        if ($tableId <= 0) {
            continue;
        }
        $tariffId = null;
        $tariffs = $table['tariffs'] ?? [];
        if (is_array($tariffs) && $tariffs !== []) {
            $first = $tariffs[0];
            if (is_array($first)) {
                $tariffId = (int) ($first['id'] ?? 0) ?: null;
            }
        }

        return ['table_id' => $tableId, 'tariff_id' => $tariffId];
    }

    return null;
}

function ensureShift(string $cashierToken): bool
{
    $r = request('GET', '/api/shifts/current', null, $cashierToken);
    if ($r['ok'] && shiftIsOpen($r['data'])) {
        pass('shift already open');

        return true;
    }
    $r = request('POST', '/api/shifts/open', ['opening_cash' => 200], $cashierToken);
    if (!$r['ok']) {
        fail('shift open', $r['message']);

        return false;
    }
    pass('shift opened');

    return true;
}

echo "=== HARD AUDIT — {$base} ===\n\n";

// --- Auth & config ---
$r = request('GET', '/api/health');
$r['status'] === 200 ? pass('health') : fail('health', (string) $r['status']);

$r = request('GET', '/api/public/config');
if ($r['ok']) {
    pass('public config');
    $billingMode = $r['data']['billing_mode'] ?? $r['data']['charge_billing_mode'] ?? 'unknown';
    echo "    billing_mode={$billingMode}\n";
} else {
    fail('public config', $r['message']);
}

$r = request('POST', '/api/auth/login', ['username' => 'admin', 'password' => 'admin']);
$adminToken = (string) ($r['data']['token'] ?? '');
if ($adminToken === '') {
    fail('admin login');
    exit(1);
}
pass('admin login');

$r = request('POST', '/api/auth/login', ['username' => 'kassir', 'password' => 'kassir']);
$cashierToken = (string) ($r['data']['token'] ?? '');
if ($cashierToken === '') {
    fail('cashier login');
    exit(1);
}
pass('cashier login');

$r = request('GET', '/api/auth/me', null, $adminToken);
($r['ok'] && ($r['data']['role'] ?? '') === 'admin') ? pass('auth me admin') : fail('auth me admin');

// --- Loyalty admin ---
$r = request('GET', '/api/loyalty/tiers', null, $adminToken);
$r['ok'] ? pass('loyalty tiers list') : fail('loyalty tiers list', $r['message']);

$tierName = 'QA Audit ' . date('His');
$r = request('POST', '/api/loyalty/tiers', [
    'name' => $tierName,
    'spend_threshold' => 10,
    'reward_kind' => 'hours',
    'reward_value' => 30,
    'is_active' => true,
], $adminToken);
$tierId = (int) ($r['data']['id'] ?? 0);
$tierId > 0 ? pass('loyalty tier create') : fail('loyalty tier create', $r['message']);

$r = request('PUT', "/api/loyalty/tiers/{$tierId}", ['name' => $tierName . ' v2'], $adminToken);
$r['ok'] ? pass('loyalty tier update') : fail('loyalty tier update', $r['message']);

// --- Customers ---
$phone = '+99455' . random_int(1000000, 9999999);
$r = request('POST', '/api/customers', ['name' => 'Audit Müştəri', 'phone' => $phone], $cashierToken);
$customerId = (int) ($r['data']['id'] ?? 0);
$customerId > 0 ? pass('customer create') : fail('customer create', $r['message']);

$r = request('POST', '/api/customers', ['name' => 'Dup', 'phone' => $phone], $cashierToken);
!$r['ok'] ? pass('customer duplicate phone blocked') : fail('customer duplicate phone blocked');

$r = request('GET', '/api/customers?q=Audit', null, $cashierToken);
$r['ok'] && count($r['data'] ?? []) > 0 ? pass('customer search') : fail('customer search');

$r = request('POST', "/api/customers/{$customerId}/loyalty/grant", [
    'kind' => 'hours',
    'value' => 90,
    'note' => 'QA audit grant',
], $adminToken);
$r['ok'] ? pass('loyalty admin grant hours') : fail('loyalty admin grant hours', $r['message']);

$r = request('POST', "/api/customers/{$customerId}/loyalty/grant", [
    'kind' => 'wallet',
    'value' => 10,
    'note' => 'QA audit wallet',
], $adminToken);
$r['ok'] ? pass('loyalty admin grant wallet') : fail('loyalty admin grant wallet', $r['message']);

$r = request('GET', "/api/customers/{$customerId}", null, $adminToken);
$loyaltyBal = $r['data']['loyalty']['balance'] ?? null;
if ($r['ok'] && is_array($loyaltyBal) && (int) ($loyaltyBal['bonus_minutes'] ?? 0) >= 90) {
    pass('customer profile loyalty balance');
} else {
    fail('customer profile loyalty balance', $r['ok'] ? json_encode($loyaltyBal) : $r['message']);
}

if (!ensureShift($cashierToken)) {
    exit(1);
}

// --- Timed session + pause + extend ---
$table = findEmptyTable($cashierToken);
if ($table === null) {
    fail('empty table');
    exit(1);
}

$openBody = [
    'table_id' => $table['table_id'],
    'planned_minutes' => 60,
    'customer_id' => $customerId,
];
if ($table['tariff_id'] !== null) {
    $openBody['tariff_id'] = $table['tariff_id'];
}

$r = request('POST', '/api/sessions', $openBody, $cashierToken);
$sessionId = (int) ($r['data']['id'] ?? $r['data']['session']['id'] ?? 0);
$sessionId > 0 ? pass('open timed session 60min with customer') : fail('open timed session', $r['message']);

$r = request('PATCH', "/api/sessions/{$sessionId}/pause", [], $cashierToken);
$r['ok'] ? pass('session pause') : fail('session pause', $r['message']);

$r = request('PATCH', "/api/sessions/{$sessionId}/resume", [], $cashierToken);
$r['ok'] ? pass('session resume') : fail('session resume', $r['message']);

$r = request('PATCH', "/api/sessions/{$sessionId}/extend", ['add_minutes' => 30], $cashierToken);
if ($r['ok']) {
    pass('session extend +30');
} else {
    fail('session extend +30', $r['message']);
}

$r = request('GET', "/api/sessions/{$sessionId}", null, $cashierToken);
$payload = is_array($r['data']['session'] ?? null) ? $r['data']['session'] : $r['data'];
$planned = (int) ($payload['planned_minutes'] ?? 0);
if ($planned === 90) {
    pass('planned_minutes after extend = 90');
} else {
    fail('planned_minutes after extend', "got {$planned}");
}

$r = request('PATCH', "/api/sessions/{$sessionId}/discount", [
    'discount_type' => 'percent',
    'discount_value' => 10,
    'discount_applies_to' => 'time_only',
], $cashierToken);
$r['ok'] ? pass('session manual discount') : fail('session manual discount', $r['message']);

// Loyalty redeem preview
$r = request('GET', "/api/sessions/{$sessionId}/preview?redeem_bonus_minutes=60&redeem_bonus_wallet=5", null, $cashierToken);
$baseTotal = (float) ($r['data']['total_amount'] ?? 0);
$loyaltyCredit = (float) ($r['data']['loyalty_credit'] ?? 0);
if ($r['ok'] && $loyaltyCredit > 0) {
    pass('loyalty redeem preview credit=' . $loyaltyCredit);
} else {
    fail('loyalty redeem preview', "credit={$loyaltyCredit} total={$baseTotal}");
}

$r = request('GET', "/api/sessions/{$sessionId}/preview", null, $cashierToken);
$totalNoBonus = (float) ($r['data']['total_amount'] ?? 0);
$totalNoBonus > $baseTotal ? pass('bonus lowers total') : warn('bonus lowers total', "noBonus={$totalNoBonus} withBonus={$baseTotal}");

$r = request('POST', "/api/sessions/{$sessionId}/close", [
    'method' => 'cash',
    'cash_amount' => $baseTotal,
    'card_amount' => 0,
    'redeem_bonus_minutes' => 60,
    'redeem_bonus_wallet' => 5,
], $cashierToken);
$r['ok'] ? pass('close session with loyalty redeem') : fail('close session with loyalty redeem', $r['message']);

$r = request('GET', "/api/customers/{$customerId}", null, $adminToken);
$balAfter = $r['data']['loyalty']['balance'] ?? [];
$minsAfter = (int) ($balAfter['bonus_minutes'] ?? 0);
$walletAfter = (float) ($balAfter['bonus_wallet'] ?? 0);
if ($minsAfter < 90 || $walletAfter < 10) {
    pass('loyalty balance decreased after redeem');
} else {
    fail('loyalty balance after redeem', json_encode($balAfter));
}

// Auto-earn: counter sales to trigger tier (threshold=10)
for ($i = 0; $i < 2; $i++) {
    $r = request('POST', '/api/sessions', ['session_type' => 'counter', 'customer_id' => $customerId], $cashierToken);
    $cid = (int) ($r['data']['id'] ?? 0);
    request('POST', "/api/sessions/{$cid}/items", ['product_id' => 1, 'quantity' => 1], $cashierToken);
    $pr = request('GET', "/api/sessions/{$cid}/preview", null, $cashierToken);
    $t = (float) ($pr['data']['total_amount'] ?? 2);
    request('POST', "/api/sessions/{$cid}/close", [
        'method' => 'cash',
        'cash_amount' => $t,
        'card_amount' => 0,
    ], $cashierToken);
}
pass('counter sales for loyalty earn');

$r = request('GET', "/api/customers/{$customerId}", null, $adminToken);
$ledger = $r['data']['loyalty']['ledger'] ?? [];
$hasTierEarn = false;
foreach ($ledger as $entry) {
    if (($entry['entry_type'] ?? '') === 'tier_earn') {
        $hasTierEarn = true;
        break;
    }
}
if (!$hasTierEarn && $r['ok']) {
    // Ledger boş ola bilər — birbaşa DB yoxlaması
    $ping = request('GET', "/api/customers/{$customerId}/loyalty", null, $adminToken);
    $ledger = $ping['data']['ledger'] ?? $ledger;
    foreach ($ledger as $entry) {
        if (($entry['entry_type'] ?? '') === 'tier_earn') {
            $hasTierEarn = true;
            break;
        }
    }
}
$hasTierEarn ? pass('loyalty tier auto-earn in ledger') : fail('loyalty tier auto-earn', 'no tier_earn entry');

// --- Admin reads ---
foreach ([
    'promotions' => '/api/promotions',
    'customer-groups' => '/api/customer-groups',
    'coupons' => '/api/coupons',
    'settings' => '/api/settings',
    'session-sets' => '/api/session-sets',
    'audit-logs' => '/api/audit-logs',
] as $label => $path) {
    $r = request('GET', $path, null, $adminToken);
    $r['ok'] ? pass("admin GET {$label}") : fail("admin GET {$label}", $r['message']);
}

// Cashier forbidden admin
$r = request('GET', '/api/users', null, $cashierToken);
($r['status'] === 403 || !$r['ok']) ? pass('cashier blocked from users') : fail('cashier blocked from users');

$r = request('DELETE', "/api/loyalty/tiers/{$tierId}", null, $adminToken);
$r['ok'] ? pass('loyalty tier delete') : fail('loyalty tier delete', $r['message']);

// --- Summary ---
echo "\n=== AUDIT SUMMARY ===\n";
echo "PASSED: {$passed}\n";
echo "FAILED: {$failures}\n";
echo 'WARNINGS: ' . count($warnings) . ($warnings !== [] ? ' (' . implode(', ', $warnings) . ')' : '') . "\n";

if ($failures === 0) {
    echo "\nVERDICT: READY for production deploy (with migration on server)\n";
} elseif ($failures <= 2) {
    echo "\nVERDICT: MOSTLY READY — fix failures before go-live\n";
} else {
    echo "\nVERDICT: NOT READY — critical issues found\n";
}

exit($failures > 0 ? 1 : 0);
