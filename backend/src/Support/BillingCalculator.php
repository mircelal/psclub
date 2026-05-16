<?php

declare(strict_types=1);

namespace App\Support;

final class BillingCalculator
{
    public function calculateTimeCharge(
        int $activeSeconds,
        float $hourlyRate,
        string $billingMode,
        float $rounding = 0.01
    ): float {
        if ($activeSeconds <= 0) {
            return 0.0;
        }

        $charge = match ($billingMode) {
            'block_30' => $this->blockCharge($activeSeconds, $hourlyRate, 30, 0.5),
            'block_60' => $this->blockCharge($activeSeconds, $hourlyRate, 60, 1.0),
            default => $this->perMinuteCharge($activeSeconds, $hourlyRate),
        };

        return $this->roundAmount($charge, $rounding);
    }

    private function perMinuteCharge(int $activeSeconds, float $hourlyRate): float
    {
        $minutes = (int) ceil($activeSeconds / 60);

        return $minutes * ($hourlyRate / 60);
    }

    private function blockCharge(int $activeSeconds, float $hourlyRate, int $blockMinutes, float $blockMultiplier): float
    {
        $minutes = (int) ceil($activeSeconds / 60);
        $blocks = (int) ceil($minutes / $blockMinutes);

        return $blocks * ($hourlyRate * $blockMultiplier);
    }

    public function roundAmount(float $amount, float $rounding): float
    {
        if ($rounding <= 0) {
            return round($amount, 2);
        }

        return round(round($amount / $rounding) * $rounding, 2);
    }

    public function calculateProductsTotal(array $items): float
    {
        $total = 0.0;
        foreach ($items as $item) {
            $total += (float) $item['unit_price'] * (int) $item['quantity'];
        }

        return round($total, 2);
    }

    public function calculateActiveSeconds(
        string $openedAt,
        ?string $closedAt,
        array $pauses,
        ?string $now = null
    ): int {
        $end = $closedAt ?? $now ?? date('Y-m-d H:i:s');
        $total = max(0, strtotime($end) - strtotime($openedAt));
        $paused = 0;

        foreach ($pauses as $pause) {
            $pausedAt = $pause['paused_at'] ?? null;
            if (!$pausedAt) {
                continue;
            }
            $resumedAt = $pause['resumed_at'] ?? ($closedAt ? $closedAt : ($now ?? date('Y-m-d H:i:s')));
            $paused += max(0, strtotime($resumedAt) - strtotime($pausedAt));
        }

        return max(0, $total - $paused);
    }
}
