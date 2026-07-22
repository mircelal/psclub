<?php

declare(strict_types=1);

/**
 * Session transfer API tests.
 * php scripts/test_session_transfer.php
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
    ];
}

function markSessionAsPackage(int $sessionId): void
{
    static $pdo = null;
    if ($pdo === null) {
        require __DIR__ . '/../vendor/autoload.php';
        $dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
        $dotenv->safeLoad();
        $pdo = App\Support\Database::connect();
    }
    $pdo->prepare(
        'UPDATE sessions SET set_price_snapshot = 15, set_name_snapshot = ? WHERE id = ?'
    )->execute(['QA Paket', $sessionId]);
}

function findEmptyTables(string $token, int $count = 2): array
{
    $r = request('GET', '/api/tables', null, $token);
    if (!$r['ok']) {
        return [];
    }
    $found = [];
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
        $found[] = [
            'table_id' => $tableId,
            'tariff_id' => $tariffId,
            'hourly_rate' => (float) ($table['hourly_rate'] ?? 0),
        ];
        if (count($found) >= $count) {
            break;
        }
    }

    return $found;
}

echo "Session transfer tests — {$base}\n";

$r = request('POST', '/api/auth/login', ['username' => 'kassir', 'password' => 'kassir']);
if (!$r['ok'] || empty($r['data']['token'])) {
    fail('cashier login', $r['message']);
    exit(1);
}
$token = (string) $r['data']['token'];
pass('cashier login');

$r = request('GET', '/api/shifts/current', null, $token);
if (!$r['ok'] || empty($r['data']['id'])) {
    $r = request('POST', '/api/shifts/open', ['opening_cash' => 100], $token);
    if (!$r['ok']) {
        fail('shift open', $r['message']);
        exit(1);
    }
    pass('shift open');
} else {
    pass('shift already open');
}

$tables = findEmptyTables($token, 2);
if (count($tables) < 2) {
    fail('need 2 empty tables', 'found ' . count($tables));
    exit(1);
}
pass('found 2 empty tables');

$source = $tables[0];
$target = $tables[1];

$openBody = [
    'table_id' => $source['table_id'],
    'planned_minutes' => 60,
];
if ($source['tariff_id'] !== null) {
    $openBody['tariff_id'] = $source['tariff_id'];
}

$r = request('POST', '/api/sessions', $openBody, $token);
if (!$r['ok']) {
    fail('open source session', $r['message']);
    exit(1);
}
$session = $r['data'];
$sessionId = (int) ($session['id'] ?? 0);
$openedAt = (string) ($session['opened_at'] ?? '');
$sourceRate = (float) ($session['hourly_rate_snapshot'] ?? 0);
if ($sessionId <= 0 || $openedAt === '') {
    fail('session id/opened_at');
    exit(1);
}
pass('open anonymous timed session');

$r = request('POST', "/api/sessions/{$sessionId}/items", ['product_id' => 1, 'quantity' => 1], $token);
if (!$r['ok']) {
    fail('add item before transfer', $r['message']);
} else {
    pass('add item before transfer');
}

$r = request('PATCH', "/api/sessions/{$sessionId}/transfer", [
    'target_table_id' => $target['table_id'],
    'tariff_mode' => 'keep',
], $token);
if (!$r['ok']) {
    fail('transfer keep', $r['message']);
    exit(1);
}
$summary = $r['data']['transfer_summary'] ?? [];
$newSession = $r['data']['session'] ?? [];
$newTableId = (int) ($newSession['table_id'] ?? 0);
if ($newTableId !== $target['table_id']) {
    fail('transfer table_id', "expected {$target['table_id']}, got {$newTableId}");
} elseif (($newSession['opened_at'] ?? '') !== $openedAt) {
    fail('opened_at preserved');
} elseif (abs($sourceRate - (float) ($summary['new_hourly_rate'] ?? 0)) > 0.01) {
    fail('keep rate unchanged');
} else {
    pass('transfer keep — table_id, opened_at, rate');
}

$r = request('PATCH', "/api/sessions/{$sessionId}/transfer", [
    'target_table_id' => $source['table_id'],
    'tariff_mode' => 'keep',
], $token);
if (!$r['ok']) {
    fail('transfer back to empty source', $r['message']);
} else {
    pass('transfer back to empty source');
}

// Occupied target: open session on a third table while our session is active
$tables3 = findEmptyTables($token, 1);
if ($tables3 !== []) {
    $occ = $tables3[0];
    $r = request('POST', '/api/sessions', array_filter([
        'table_id' => $occ['table_id'],
        'tariff_id' => $occ['tariff_id'],
    ]), $token);
    if ($r['ok']) {
        $occSessionId = (int) ($r['data']['id'] ?? 0);
        $r = request('PATCH', "/api/sessions/{$sessionId}/transfer", [
            'target_table_id' => $occ['table_id'],
            'tariff_mode' => 'keep',
        ], $token);
        if ($r['ok'] || $r['status'] !== 409) {
            fail('occupied target should 409', 'status ' . $r['status'] . ' msg ' . $r['message']);
        } else {
            pass('occupied target rejected');
        }
        request('POST', "/api/sessions/{$occSessionId}/close", [
            'method' => 'cash',
            'cash_amount' => 0,
            'card_amount' => 0,
        ], $token);
    } else {
        fail('open occupied test session', $r['message']);
    }
} else {
    fail('need empty table for occupied test');
}

// Paket sessiyada target tarif bloklanır (cari sessiyaya snapshot tətbiq edilir)
markSessionAsPackage($sessionId);
$r = request('PATCH', "/api/sessions/{$sessionId}/transfer", [
    'target_table_id' => $target['table_id'],
    'tariff_mode' => 'target',
    'tariff_id' => $target['tariff_id'],
], $token);
if ($r['ok'] || $r['status'] !== 400) {
    fail('package target tariff should 400', 'status ' . $r['status']);
} else {
    pass('package target tariff blocked');
}
$r = request('PATCH', "/api/sessions/{$sessionId}/transfer", [
    'target_table_id' => $target['table_id'],
    'tariff_mode' => 'keep',
], $token);
if (!$r['ok']) {
    fail('package keep transfer', $r['message']);
} else {
    pass('package keep transfer ok');
}

// Target tariff mode (non-package hourly session)
require __DIR__ . '/../vendor/autoload.php';
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->safeLoad();
$pdo = App\Support\Database::connect();
$pdo->prepare('UPDATE sessions SET set_price_snapshot = NULL, set_name_snapshot = NULL WHERE id = ?')
    ->execute([$sessionId]);

$r = request('PATCH', "/api/sessions/{$sessionId}/transfer", [
    'target_table_id' => $source['table_id'],
    'tariff_mode' => 'target',
    'tariff_id' => $source['tariff_id'],
], $token);
if (!$r['ok']) {
    fail('transfer target tariff', $r['message']);
} else {
    $newRate = (float) ($r['data']['transfer_summary']['new_hourly_rate'] ?? 0);
    if ($newRate <= 0) {
        fail('target tariff rate applied');
    } else {
        pass('transfer target tariff');
    }
}

// Cleanup: close transferred session
$r = request('GET', "/api/sessions/{$sessionId}/preview", null, $token);
$total = (float) ($r['data']['total_amount'] ?? 0);
request('POST', "/api/sessions/{$sessionId}/close", [
    'method' => 'cash',
    'cash_amount' => $total,
    'card_amount' => 0,
], $token);
pass('cleanup close session');

echo "\nPassed: {$passed}, Failed: {$failures}\n";
exit($failures > 0 ? 1 : 0);
