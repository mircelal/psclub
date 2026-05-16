<?php

declare(strict_types=1);

namespace App\Support;

final class DiscountCalculator
{
    public static function amount(float $subtotal, string $type, float $value): float
    {
        if ($subtotal <= 0 || $type === 'none') {
            return 0.0;
        }
        if ($type === 'fixed') {
            return min($subtotal, max(0, round($value, 2)));
        }
        if ($type === 'percent') {
            return min($subtotal, round($subtotal * max(0, $value) / 100, 2));
        }

        return 0.0;
    }
}
