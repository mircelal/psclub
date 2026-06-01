<?php

declare(strict_types=1);

function req(string $m, string $p, ?array $b = null, ?string $t = null): array
{
    $h = "Content-Type: application/json\r\n" . ($t ? "Authorization: Bearer {$t}\r\n" : '');
    $ctx = stream_context_create(['http' => [
        'method' => $m,
        'header' => $h,
        'content' => $b ? json_encode($b) : '',
        'ignore_errors' => true,
    ]]);
    $raw = file_get_contents('http://127.0.0.1:8080' . $p, false, $ctx);

    return json_decode($raw ?: '', true) ?: [];
}

$ct = req('POST', '/api/auth/login', ['username' => 'kassir', 'password' => 'kassir'])['data']['token'] ?? '';
$groups = req('GET', '/api/customer-groups/active', null, $ct)['data'] ?? [];
$gid = (int) ($groups[0]['id'] ?? 1);
$phone = '+99450' . random_int(1000000, 9999999);
$cid = (int) (req('POST', '/api/customers', ['name' => 'T', 'phone' => $phone, 'customer_group_id' => $gid], $ct)['data']['id'] ?? 0);

if (!req('GET', '/api/shifts/current', null, $ct)['data']) {
    req('POST', '/api/shifts/open', ['opening_cash' => 50], $ct);
}

$tables = req('GET', '/api/tables', null, $ct)['data']['tables'] ?? [];
$tableId = 0;
$tariffId = null;
foreach ($tables as $t) {
    if (empty($t['session_id']) && ($t['status'] ?? '') === 'empty') {
        $tableId = (int) $t['id'];
        $tariffId = (int) ($t['tariffs'][0]['id'] ?? 0) ?: null;
        break;
    }
}
if ($tableId <= 0) {
    echo "no empty table\n";
    exit(1);
}

$openBody = ['table_id' => $tableId];
if ($tariffId !== null) {
    $openBody['tariff_id'] = $tariffId;
}
$open = req('POST', '/api/sessions', $openBody, $ct);
$sid = (int) ($open['data']['id'] ?? 0);
if ($sid <= 0) {
    echo 'open failed: ' . json_encode($open) . PHP_EOL;
    exit(1);
}
req('PATCH', "/api/sessions/{$sid}/customer", ['customer_id' => $cid], $ct);
$payload = req('GET', "/api/sessions/{$sid}", null, $ct)['data'] ?? [];
$s = is_array($payload['session'] ?? null) ? $payload['session'] : $payload;

echo 'active_customer_group top: ' . json_encode($s['active_customer_group'] ?? null) . PHP_EOL;
echo 'bill active_customer_group: ' . json_encode($s['bill_preview']['active_customer_group'] ?? null) . PHP_EOL;
echo 'bill discount: ' . ($s['bill_preview']['discount'] ?? '?') . ' time: ' . ($s['bill_preview']['time_charge'] ?? '?') . PHP_EOL;

foreach (req('GET', '/api/tables', null, $ct)['data']['tables'] ?? [] as $t) {
    if ((int) ($t['session_id'] ?? 0) === $sid) {
        echo 'table active_customer_group: ' . json_encode($t['active_customer_group'] ?? null) . PHP_EOL;
        echo 'table bill active_customer_group: ' . json_encode($t['bill_preview']['active_customer_group'] ?? null) . PHP_EOL;
        break;
    }
}
