<?php

/**
 * Köhnə bağlanmış sessiyalar: PHP/MySQL saat fərqinə görə time_charge=0 qalıbsa yenidən hesabla.
 * Bir dəfə: php scripts/repair_session_billing.php
 */

require __DIR__ . '/../vendor/autoload.php';

$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->load();
date_default_timezone_set($_ENV['APP_TIMEZONE'] ?? 'Asia/Baku');

$pdo = App\Support\Database::connect();
$billing = new App\Support\BillingCalculator();
$biz = $pdo->query(
    'SELECT billing_mode, billing_rounding, time_billing_enabled,
            min_billing_minutes, billing_increment_minutes, billing_grace_minutes
     FROM businesses WHERE id = 1'
)->fetch();

$stmt = $pdo->query(
    "SELECT * FROM sessions WHERE status = 'closed' AND active_seconds = 0 AND closed_at > opened_at"
);
$rows = $stmt->fetchAll();
$update = $pdo->prepare(
    'UPDATE sessions SET time_charge = ?, products_total = ?, discount = ?, total_amount = ?, active_seconds = ? WHERE id = ?'
);

$fixed = 0;
foreach ($rows as $session) {
    $pauses = $pdo->prepare('SELECT * FROM session_pauses WHERE session_id = ?');
    $pauses->execute([(int) $session['id']]);
    $pauseRows = $pauses->fetchAll();

    $items = $pdo->prepare('SELECT * FROM session_items WHERE session_id = ?');
    $items->execute([(int) $session['id']]);
    $itemRows = $items->fetchAll();

    $activeSeconds = $billing->calculateActiveSeconds(
        $session['opened_at'],
        $session['closed_at'],
        $pauseRows
    );

    $isCounter = ($session['session_type'] ?? 'table') === 'counter';
    $timeBilling = !$isCounter && (!isset($biz['time_billing_enabled']) || (bool) $biz['time_billing_enabled']);
    $plannedMinutes = isset($session['planned_minutes']) ? (int) $session['planned_minutes'] : 0;
    $timeCharge = $timeBilling
        ? $billing->calculateTimeCharge(
            $activeSeconds,
            (float) $session['hourly_rate_snapshot'],
            $biz['billing_mode'] ?? 'per_minute',
            (float) ($biz['billing_rounding'] ?? 0.01),
            max(1, (int) ($biz['min_billing_minutes'] ?? 60)),
            max(1, (int) ($biz['billing_increment_minutes'] ?? 30)),
            max(0, (int) ($biz['billing_grace_minutes'] ?? 10)),
            $plannedMinutes > 0 ? $plannedMinutes : null
        )
        : 0.0;
    $productsTotal = $billing->calculateProductsTotal($itemRows);
    $subtotal = $timeCharge + $productsTotal;
    $discount = (float) ($session['discount'] ?? 0);
    $total = round($subtotal - $discount, 2);

    if ($activeSeconds <= 0 && $productsTotal <= 0) {
        continue;
    }

    $update->execute([$timeCharge, $productsTotal, $discount, $total, $activeSeconds, (int) $session['id']]);
    $pdo->prepare('UPDATE payments SET total_amount = ? WHERE session_id = ?')->execute([$total, (int) $session['id']]);
    echo "Session #{$session['id']}: vaxt={$timeCharge}, məhsul={$productsTotal}, cəmi={$total}, saniyə={$activeSeconds}\n";
    $fixed++;
}

echo "Düzəldildi: $fixed sessiya\n";
