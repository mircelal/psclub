<?php

declare(strict_types=1);

namespace App\Support;

final class DiscountCalculator
{
    /** @param float $base Subtotal or time_charge only — caller chooses scope. */
    public static function amount(float $base, string $type, float $value): float
    {
        if ($base <= 0 || $type === 'none') {
            return 0.0;
        }
        if ($type === 'fixed') {
            return min($base, max(0, round($value, 2)));
        }
        if ($type === 'percent') {
            return min($base, round($base * max(0, $value) / 100, 2));
        }

        return 0.0;
    }
}
