<?php

/**
 * BillingCalculator grace + min_1h_then_30 testləri.
 * php scripts/test_billing_calculator.php
 */

require __DIR__ . '/../vendor/autoload.php';

$calc = new App\Support\BillingCalculator();

function assertEq(int $expected, int $actual, string $label): void
{
    if ($expected !== $actual) {
        fwrite(STDERR, "FAIL {$label}: expected {$expected}, got {$actual}\n");
        exit(1);
    }
    echo "OK {$label}\n";
}

$grace = 10;
$min = 60;
$step = 30;

$cases = [
    [10 * 60, 60, '10 min'],
    [60 * 60, 60, '60 min'],
    [69 * 60, 60, '69 min (1h09)'],
    [70 * 60, 60, '70 min'],
    [71 * 60, 90, '71 min'],
    [80 * 60, 90, '80 min (1h20)'],
    [100 * 60, 90, '100 min (1h40)'],
];

foreach ($cases as [$seconds, $expected, $label]) {
    $actual = $calc->billableMinutesFromActive($seconds, $min, $step, $grace);
    assertEq($expected, $actual, $label);
}

assertEq(90, $calc->billableMinutesFromPlanned(90, $min, $step), 'planned 90');
assertEq(60, $calc->billableMinutesFromPlanned(60, $min, $step), 'planned 60');

$charge69 = $calc->calculateTimeCharge(
    69 * 60,
    10.0,
    'min_1h_then_30',
    0.01,
    $min,
    $step,
    $grace,
    null
);
if (abs($charge69 - 10.0) > 0.001) {
    fwrite(STDERR, "FAIL charge 69min: expected 10.0, got {$charge69}\n");
    exit(1);
}
echo "OK charge 69min = 1 hour rate\n";

$charge90planned = $calc->calculateTimeCharge(
    30 * 60,
    10.0,
    'min_1h_then_30',
    0.01,
    $min,
    $step,
    $grace,
    90
);
if (abs($charge90planned - 15.0) > 0.001) {
    fwrite(STDERR, "FAIL planned 90: expected 15.0, got {$charge90planned}\n");
    exit(1);
}
echo "OK planned 90 ignores elapsed grace\n";

$cap180 = $calc->capActiveSecondsForPlanned(180 * 60, 60);
assertEq(3600, $cap180, 'cap 180min to 60min planned');

$chargePerMinuteTimed = $calc->calculateTimeCharge(
    180 * 60,
    10.0,
    'per_minute',
    0.01,
    $min,
    $step,
    $grace,
    60
);
if (abs($chargePerMinuteTimed - 10.0) > 0.001) {
    fwrite(STDERR, "FAIL per_minute timed cap: expected 10.0, got {$chargePerMinuteTimed}\n");
    exit(1);
}
echo "OK per_minute timed 180min elapsed charges 60min only\n";

$chargeOpen70 = $calc->calculateTimeCharge(
    70 * 60,
    10.0,
    'min_1h_then_30',
    0.01,
    $min,
    $step,
    $grace,
    null
);
if (abs($chargeOpen70 - 10.0) > 0.001) {
    fwrite(STDERR, "FAIL open 70min grace: expected 10.0, got {$chargeOpen70}\n");
    exit(1);
}
echo "OK open-ended 70min with grace = 1 hour rate\n";

$chargeExtended = $calc->calculateTimeCharge(
    180 * 60,
    10.0,
    'per_minute',
    0.01,
    $min,
    $step,
    $grace,
    120
);
if (abs($chargeExtended - 20.0) > 0.001) {
    fwrite(STDERR, "FAIL extended 120min planned: expected 20.0, got {$chargeExtended}\n");
    exit(1);
}
echo "OK extended 120min planned charges 120min only\n";

echo "All billing tests passed.\n";
