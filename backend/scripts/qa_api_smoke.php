<?php

declare(strict_types=1);

/**
 * QA API smoke — psclub_qa + http://127.0.0.1:8080
 * API: DB_NAME=psclub_qa php -S 127.0.0.1:8080 (backend/public)
 * php scripts/qa_api_smoke.php
 */

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
        $headers .= "Authorization: Bearer {$token}\r\n";
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
    $ctx = stream_context_create($opts);
    $raw = @file_get_contents($url, false, $ctx);
    if ($raw === false) {
        return ['ok' => false, 'status' => 0, 'message' => 'Connection failed', 'data' => null];
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

echo "QA API smoke — {$base}\n";

// 1 Health
$r = request('GET', '/api/health');
if ($r['status'] !== 200) {
    fail('health status', (string) $r['status']);
} else {
    pass('health');
}

$r = request('GET', '/api/public/config');
if (!$r['ok']) {
    fail('public config', $r['message']);
} else {
    pass('public config');
}

// 2 Auth
$r = request('POST', '/api/auth/login', ['username' => 'admin', 'password' => 'admin']);
if (!$r['ok'] || empty($r['data']['token'])) {
    fail('admin login', $r['message']);
    exit(1);
}
$adminToken = (string) $r['data']['token'];
pass('admin login');

$r = request('POST', '/api/auth/login', ['username' => 'kassir', 'password' => 'kassir']);
if (!$r['ok'] || empty($r['data']['token'])) {
    fail('cashier login', $r['message']);
    exit(1);
}
$cashierToken = (string) $r['data']['token'];
pass('cashier login');

// Close leftover open shift from previous QA run
$r = request('GET', '/api/shifts/current', null, $cashierToken);
if ($r['ok'] && shiftIsOpen($r['data'])) {
    $oldShiftId = (int) $r['data']['id'];
    $oldExpected = round((float) ($r['data']['totals']['expected_cash'] ?? 0), 2);
    request('POST', "/api/shifts/{$oldShiftId}/close", ['closing_cash' => $oldExpected], $cashierToken);
    pass('cleanup old shift');
}

// 3 Shift open
$r = request('POST', '/api/shifts/open', ['opening_cash' => 100], $cashierToken);
if (!$r['ok']) {
    fail('shift open', $r['message']);
} else {
    pass('shift open');
}

$r = request('GET', '/api/shifts/current', null, $cashierToken);
if (!$r['ok'] || !shiftIsOpen($r['data']) || !is_array($r['data']['totals'] ?? null)) {
    fail('shift current totals', $r['message']);
} else {
    pass('shift current');
}
$shiftId = (int) ($r['data']['id'] ?? 0);

// 4 Table session + product + close
$table = findEmptyTable($cashierToken);
if ($table === null) {
    fail('empty table for session');
    exit(1);
}
$openSessionBody = ['table_id' => $table['table_id']];
if ($table['tariff_id'] !== null) {
    $openSessionBody['tariff_id'] = $table['tariff_id'];
}
$r = request('POST', '/api/sessions', $openSessionBody, $cashierToken);
if (!$r['ok']) {
    fail('open table session', $r['message']);
    exit(1);
}
$tableSessionId = (int) ($r['data']['id'] ?? $r['data']['session']['id'] ?? 0);
if ($tableSessionId <= 0) {
    fail('table session id');
    exit(1);
}
pass('open table session');

$r = request('POST', "/api/sessions/{$tableSessionId}/items", ['product_id' => 1, 'quantity' => 1], $cashierToken);
if (!$r['ok']) {
    fail('add item table', $r['message']);
} else {
    pass('add item table');
}

$r = request('GET', "/api/sessions/{$tableSessionId}/preview", null, $cashierToken);
if (!$r['ok']) {
    fail('preview table', $r['message']);
} else {
    pass('preview table');
}

$previewTotal = (float) ($r['data']['total_amount'] ?? $r['data']['bill']['total_amount'] ?? 0);
if ($previewTotal <= 0) {
    fail('preview total > 0');
} else {
    pass('preview total positive');
}

$r = request('POST', "/api/sessions/{$tableSessionId}/close", [
    'method' => 'cash',
    'cash_amount' => $previewTotal,
    'card_amount' => 0,
], $cashierToken);
if (!$r['ok']) {
    fail('close table session', $r['message']);
} else {
    pass('close table session');
}
$tableOrderId = $tableSessionId;

// 5 Counter sale
$r = request('POST', '/api/sessions', ['session_type' => 'counter'], $cashierToken);
if (!$r['ok']) {
    fail('open counter', $r['message']);
} else {
    $counterId = (int) ($r['data']['id'] ?? $r['data']['session']['id'] ?? 0);
    pass('open counter');
}

$r = request('POST', "/api/sessions/{$counterId}/items", ['product_id' => 2, 'quantity' => 2], $cashierToken);
if (!$r['ok']) {
    fail('counter add item', $r['message']);
} else {
    pass('counter add item');
}

$r = request('GET', "/api/sessions/{$counterId}/preview", null, $cashierToken);
$counterTotal = (float) ($r['data']['total_amount'] ?? $r['data']['bill']['total_amount'] ?? 7.0);
$r = request('POST', "/api/sessions/{$counterId}/close", [
    'method' => 'cash',
    'cash_amount' => $counterTotal,
    'card_amount' => 0,
], $cashierToken);
if (!$r['ok']) {
    fail('close counter', $r['message']);
} else {
    pass('close counter');
}

// 6 Shift totals increased
$r = request('GET', '/api/shifts/current', null, $cashierToken);
$cashSales = (float) ($r['data']['totals']['cash_sales'] ?? 0);
if ($cashSales < $previewTotal) {
    fail('cash_sales increased', "sales={$cashSales}");
} else {
    pass('cash_sales after sales');
}

// 7 Delete order (admin)
$r = request('GET', '/api/shifts/current', null, $cashierToken);
$expectedBeforeDelete = (float) ($r['data']['totals']['expected_cash'] ?? 0);

$r = request('DELETE', "/api/orders/{$tableOrderId}", ['restore_stock' => true], $adminToken);
if (!$r['ok'] || empty($r['data']['deleted'])) {
    fail('delete order', $r['message']);
} else {
    pass('delete order');
}

$r = request('GET', '/api/shifts/current', null, $cashierToken);
$expectedAfterDelete = (float) ($r['data']['totals']['expected_cash'] ?? 0);
if ($expectedAfterDelete >= $expectedBeforeDelete - 0.01) {
    fail('expected_cash decreased after delete', "before={$expectedBeforeDelete} after={$expectedAfterDelete}");
} else {
    pass('expected_cash after delete');
}

// 8 Journal activity
$r = request('GET', "/api/shifts/{$shiftId}", null, $adminToken);
if (!$r['ok']) {
    fail('shift show', $r['message']);
} else {
    $activity = $r['data']['activity'] ?? [];
    $kinds = array_map(static fn ($a) => $a['kind'] ?? '', $activity);
    $hasDeleted = in_array('order_deleted', $kinds, true);
    $hasSession = in_array('session', $kinds, true);
    if (!$hasDeleted || !$hasSession) {
        fail('shift activity kinds', 'deleted=' . ($hasDeleted ? 'y' : 'n') . ' session=' . ($hasSession ? 'y' : 'n'));
    } else {
        pass('shift activity delete+session');
    }
}

// 9 Refund another order — open quick counter and close
$r = request('POST', '/api/sessions', ['session_type' => 'counter'], $cashierToken);
$refundSessionId = (int) ($r['data']['id'] ?? 0);
request('POST', "/api/sessions/{$refundSessionId}/items", ['product_id' => 1, 'quantity' => 1], $cashierToken);
$r = request('GET', "/api/sessions/{$refundSessionId}/preview", null, $cashierToken);
$rt = (float) ($r['data']['total_amount'] ?? $r['data']['bill']['total_amount'] ?? 2);
request('POST', "/api/sessions/{$refundSessionId}/close", ['method' => 'cash', 'cash_amount' => $rt, 'card_amount' => 0], $cashierToken);

$r = request('POST', "/api/orders/{$refundSessionId}/refund", ['restore_stock' => true], $adminToken);
if (!$r['ok']) {
    fail('refund order', $r['message']);
} else {
    pass('refund order');
}

// 10 Expense
$r = request('POST', "/api/shifts/{$shiftId}/movements", [
    'type' => 'expense',
    'amount' => 5,
    'category' => 'diger',
    'description' => 'QA test',
], $cashierToken);
if (!$r['ok']) {
    fail('shift expense', $r['message']);
} else {
    pass('shift expense');
}

$r = request('GET', '/api/shifts/current', null, $cashierToken);
$expectedAfterExpense = (float) ($r['data']['totals']['expected_cash'] ?? 0);

// 11 Close shift
$closingCash = round($expectedAfterExpense, 2);
$r = request('POST', "/api/shifts/{$shiftId}/close", ['closing_cash' => $closingCash], $cashierToken);
if (!$r['ok']) {
    fail('shift close', $r['message']);
} else {
    pass('shift close');
}

// 12 Cashier cannot delete
$r = request('DELETE', "/api/orders/{$counterId}", [], $cashierToken);
if ($r['status'] === 403 || ($r['ok'] === false && $r['status'] >= 400)) {
    pass('cashier delete forbidden');
} else {
    fail('cashier delete forbidden', 'status=' . $r['status']);
}

// 13 Admin reads (CRUD smoke)
foreach ([
    'tables' => '/api/tables',
    'products' => '/api/products',
    'users' => '/api/users',
    'shifts list' => '/api/shifts',
    'orders today' => '/api/orders?from=' . date('Y-m-d') . '&to=' . date('Y-m-d'),
    'dashboard' => '/api/reports/dashboard',
] as $label => $path) {
    $r = request('GET', $path, null, $adminToken);
    if (!$r['ok']) {
        fail("admin GET {$label}", $r['message']);
    } else {
        pass("admin GET {$label}");
    }
}

// 14 Stock alert
$r = request('GET', '/api/stock/alerts', null, $cashierToken);
if (!$r['ok']) {
    fail('stock alerts', $r['message']);
} else {
    pass('stock alerts');
}

// 15 No open shift blocks session (fresh cashier after close)
$table = findEmptyTable($cashierToken);
if ($table === null) {
    fail('empty table for no-shift test');
} else {
    $blockedBody = ['table_id' => $table['table_id']];
    if ($table['tariff_id'] !== null) {
        $blockedBody['tariff_id'] = $table['tariff_id'];
    }
    $r = request('POST', '/api/sessions', $blockedBody, $cashierToken);
    if ($r['ok']) {
        fail('session without shift should fail');
    } else {
        pass('session blocked without shift');
    }
}

echo "\n{$passed} passed, {$failures} failed\n";
exit($failures > 0 ? 1 : 0);
