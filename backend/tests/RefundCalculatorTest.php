<?php

declare(strict_types=1);

require __DIR__ . '/../vendor/autoload.php';

use App\Modules\Orders\RefundCalculator;

$failures = 0;

function assertEq(float $expected, float $actual, string $label): void
{
    global $failures;
    if (abs($expected - $actual) > 0.01) {
        echo "FAIL {$label}: expected {$expected}, got {$actual}\n";
        $failures++;
    } else {
        echo "OK {$label}\n";
    }
}

$cash = RefundCalculator::splitRefund(50.0, [
    'method' => 'cash',
    'cash_amount' => 50,
    'card_amount' => 0,
    'total_amount' => 50,
]);
assertEq(50.0, $cash['cash_refund'], 'full cash');
assertEq(0.0, $cash['card_refund'], 'full cash card');

$mixed = RefundCalculator::splitRefund(100.0, [
    'method' => 'mixed',
    'cash_amount' => 40,
    'card_amount' => 60,
    'total_amount' => 100,
]);
assertEq(40.0, $mixed['cash_refund'], 'mixed cash');
assertEq(60.0, $mixed['card_refund'], 'mixed card');

$partial = RefundCalculator::splitRefund(50.0, [
    'method' => 'mixed',
    'cash_amount' => 40,
    'card_amount' => 60,
    'total_amount' => 100,
]);
assertEq(20.0, $partial['cash_refund'], 'partial mixed cash');
assertEq(30.0, $partial['card_refund'], 'partial mixed card');

$rescaled = RefundCalculator::rescalePayment(20.0, [
    'method' => 'cash',
    'cash_amount' => 25,
    'card_amount' => 0,
    'total_amount' => 25,
]);
assertEq(20.0, $rescaled['cash_amount'], 'rescale cash down');
assertEq(20.0, $rescaled['total_amount'], 'rescale total down');

$rescaledMixed = RefundCalculator::rescalePayment(80.0, [
    'method' => 'mixed',
    'cash_amount' => 40,
    'card_amount' => 60,
    'total_amount' => 100,
]);
assertEq(32.0, $rescaledMixed['cash_amount'], 'rescale mixed cash');
assertEq(48.0, $rescaledMixed['card_amount'], 'rescale mixed card');

$inWindow = RefundCalculator::sessionInShiftWindow(
    '2026-05-21 14:00:00',
    ['opened_at' => '2026-05-21 08:00:00', 'closed_at' => '2026-05-21 23:59:59']
);
echo ($inWindow ? 'OK' : 'FAIL') . " session in shift window\n";
if (!$inWindow) {
    $failures++;
}

exit($failures > 0 ? 1 : 0);
