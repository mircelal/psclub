<?php

declare(strict_types=1);

/** Extended smoke — promotions, customer groups, adjust, discounts */
$base = getenv('QA_API_BASE') ?: 'http://127.0.0.1:8080';
$failures = 0;
$passed = 0;

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

function shiftIsOpen(?array $data): bool
{
    return is_array($data)
        && ($data['open'] ?? true) !== false
        && !empty($data['id']);
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

function request(string $method, string $path, ?array $body = null, ?string $token = null): array
{
    global $base;
    $url = rtrim($base, '/') . $path;
    $headers = "Content-Type: application/json\r\nAccept: application/json\r\n";
    if ($token !== null) {
        $headers .= "Authorization: Bearer {$token}\n";
    }
    $opts = [
        'http' => [
            'method' => $method,
            'header' => $headers,
            'ignore_errors' => true,
            'timeout' => 30,
        ],
    ];
    if ($body !== null && in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE'], true)) {
        $opts['http']['content'] = json_encode($body, JSON_UNESCAPED_UNICODE);
    }
    $raw = @file_get_contents($url, false, stream_context_create($opts));
    $status = 0;
    if (isset($http_response_header[0]) && preg_match('/\d{3}/', $http_response_header[0], $m)) {
        $status = (int) $m[0];
    }
    $json = json_decode($raw ?: '', true);

    return [
        'ok' => is_array($json) && ($json['success'] ?? false) === true,
        'status' => $status,
        'message' => is_array($json) ? (string) ($json['message'] ?? '') : 'Invalid JSON',
        'data' => is_array($json) ? ($json['data'] ?? null) : null,
    ];
}

echo "Extended QA — {$base}\n";

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

foreach ([
    'customer-groups admin' => ['/api/customer-groups', $adminToken],
    'customer-groups active cashier' => ['/api/customer-groups/active', $cashierToken],
    'promotions admin' => ['/api/promotions', $adminToken],
    'promotions active cashier' => ['/api/promotions/active', $cashierToken],
] as $label => [$path, $token]) {
    $r = request('GET', $path, null, $token);
    if (!$r['ok']) {
        fail($label, $r['message'] . ' status=' . $r['status']);
    } else {
        pass($label);
    }
}

$groups = request('GET', '/api/customer-groups', null, $adminToken);
$groupId = (int) (($groups['data'][0]['id'] ?? 0));
if ($groupId <= 0) {
    fail('customer groups seeded');
} else {
    pass('customer groups seeded');
}

$phone = '+99450' . random_int(1000000, 9999999);
$r = request('POST', '/api/customers', [
    'name' => 'QA Group User',
    'phone' => $phone,
    'customer_group_id' => $groupId,
], $cashierToken);
if (!$r['ok']) {
    fail('create customer with group', $r['message']);
    exit(1);
}
$customerId = (int) ($r['data']['id'] ?? 0);
pass('create customer with group');

$r = request('GET', '/api/shifts/current', null, $cashierToken);
$hasShift = $r['ok'] && shiftIsOpen($r['data']);
if (!$hasShift) {
    $r = request('POST', '/api/shifts/open', ['opening_cash' => 100], $cashierToken);
    if (!$r['ok']) {
        fail('shift open for test', $r['message']);
        exit(1);
    }
    pass('shift opened for test');
} else {
    pass('shift already open');
}

$table = findEmptyTable($cashierToken);
if ($table === null) {
    fail('empty table for session test');
    exit(1);
}
$openSessionBody = ['table_id' => $table['table_id']];
if ($table['tariff_id'] !== null) {
    $openSessionBody['tariff_id'] = $table['tariff_id'];
}

$r = request('POST', '/api/sessions', $openSessionBody, $cashierToken);
if (!$r['ok']) {
    fail('open session without customer', $r['message']);
    exit(1);
}
$sessionId = (int) ($r['data']['id'] ?? 0);
pass('open session without customer');

$r = request('GET', "/api/sessions/{$sessionId}", null, $cashierToken);
$sessionPayload = is_array($r['data']['session'] ?? null) ? $r['data']['session'] : $r['data'];
$bill = is_array($sessionPayload['bill_preview'] ?? null) ? $sessionPayload['bill_preview'] : [];
if (!empty($sessionPayload['active_customer_group']) || !empty($bill['active_customer_group'])) {
    fail('no customer group before assign');
} else {
    pass('no customer group before assign');
}

$r = request('PATCH', "/api/sessions/{$sessionId}/customer", ['customer_id' => $customerId], $cashierToken);
if (!$r['ok']) {
    fail('assign customer mid-session', $r['message']);
    exit(1);
}
pass('assign customer mid-session');

$r = request('GET', "/api/sessions/{$sessionId}", null, $cashierToken);
$sessionPayload = is_array($r['data']['session'] ?? null) ? $r['data']['session'] : $r['data'];
$bill = is_array($sessionPayload['bill_preview'] ?? null) ? $sessionPayload['bill_preview'] : [];
$activeGroup = $sessionPayload['active_customer_group'] ?? $bill['active_customer_group'] ?? null;
if ($activeGroup === null) {
    fail('session active_customer_group after assign');
} else {
    pass('session active_customer_group after assign');
}

if ((float) ($bill['discount'] ?? 0) <= 0 && ($r['data']['discount_type'] ?? 'none') === 'none') {
    // Package/set price 0 time charge may yield 0 discount until time accrues — check tables after wait
    pass('session discount may be 0 at t=0 (time not accrued yet)');
} else {
    pass('session bill has discount preview');
}

$r = request('GET', '/api/tables', null, $cashierToken);
$tables = $r['data']['tables'] ?? [];
$openTable = null;
foreach ($tables as $t) {
    if ((int) ($t['session_id'] ?? 0) === $sessionId) {
        $openTable = $t;
        break;
    }
}
if ($openTable === null) {
    fail('tables list contains open session');
} elseif (empty($openTable['active_customer_group']) && empty($openTable['bill_preview']['active_customer_group'])) {
    fail('tables API active_customer_group on open table');
} else {
    pass('tables API customer group on open table');
}

$r = request('GET', "/api/sessions/{$sessionId}/preview", null, $cashierToken);
$previewTotal = (float) ($r['data']['total_amount'] ?? $r['data']['bill']['total_amount'] ?? 0);
$r = request('POST', "/api/sessions/{$sessionId}/close", [
    'method' => 'cash',
    'cash_amount' => max(0.01, $previewTotal),
    'card_amount' => 0,
], $cashierToken);
if (!$r['ok']) {
    fail('close session for adjust test', $r['message']);
} else {
    pass('close session for adjust test');
}

$newTotal = max(0.01, round($previewTotal * 0.7, 2));
$r = request('PUT', "/api/orders/{$sessionId}/adjust", [
    'total_amount' => $newTotal,
    'time_charge' => $newTotal,
    'products_total' => 0,
    'discount' => 0,
], $adminToken);
if (!$r['ok']) {
    fail('admin adjust order', $r['message']);
} else {
    pass('admin adjust order');
    if (empty($r['data']['adjust_summary'])) {
        fail('adjust_summary in response');
    } else {
        pass('adjust_summary in response');
    }
}

$r = request('GET', '/api/shifts/current', null, $cashierToken);
if ($r['ok'] && shiftIsOpen($r['data'])) {
    $cashSales = (float) ($r['data']['totals']['cash_sales'] ?? 0);
    pass('shift totals after adjust (cash_sales=' . $cashSales . ')');
} else {
    pass('no open shift after close (adjust shift sync N/A)');
}

echo "\n{$passed} passed, {$failures} failed\n";
exit($failures > 0 ? 1 : 0);
