<?php

declare(strict_types=1);

namespace App\Support;

final class BillingCalculator
{
    public function calculateTimeCharge(
        int $activeSeconds,
        float $hourlyRate,
        string $billingMode,
        float $rounding = 0.01,
        int $minBillingMinutes = 60,
        int $billingIncrementMinutes = 30,
        int $billingGraceMinutes = 10,
        ?int $plannedMinutes = null
    ): float {
        if ($billingMode === 'min_1h_then_30' && $plannedMinutes !== null && $plannedMinutes > 0) {
            $billed = $this->billableMinutesFromPlanned(
                $plannedMinutes,
                max(1, $minBillingMinutes),
                max(1, $billingIncrementMinutes)
            );

            return $this->roundAmount($hourlyRate * ($billed / 60), $rounding);
        }

        if ($activeSeconds <= 0) {
            return 0.0;
        }

        $charge = match ($billingMode) {
            'block_30' => $this->blockCharge($activeSeconds, $hourlyRate, 30, 0.5),
            'block_60' => $this->blockCharge($activeSeconds, $hourlyRate, 60, 1.0),
            'min_1h_then_30' => $this->minFirstHourThenInterval(
                $activeSeconds,
                $hourlyRate,
                max(1, $minBillingMinutes),
                max(1, $billingIncrementMinutes),
                max(0, $billingGraceMinutes)
            ),
            default => $this->perMinuteCharge($activeSeconds, $hourlyRate),
        };

        return $this->roundAmount($charge, $rounding);
    }

    /**
     * Vaxtsız sessiya: minimum ilk müddət; sonrakı vaxt interval blokları + güzəşt.
     */
    public function billableMinutesFromActive(
        int $activeSeconds,
        int $minMinutes = 60,
        int $intervalMinutes = 30,
        int $graceMinutes = 10
    ): int {
        if ($activeSeconds <= 0) {
            return 0;
        }

        $minutes = (int) ceil($activeSeconds / 60);
        $minM = max(1, $minMinutes);
        $stepM = max(1, $intervalMinutes);
        $grace = max(0, $graceMinutes);

        if ($minutes <= $minM) {
            return $minM;
        }

        $extra = $minutes - $minM;
        if ($extra <= $grace) {
            return $minM;
        }

        $chargeableExtra = $extra - $grace;
        $blocks = (int) ceil($chargeableExtra / $stepM);

        return $minM + ($blocks * $stepM);
    }

    /**
     * Minimum ilk müddət (məs. 60 dəq) tam saatlıq ödəniş; sonrakı vaxt interval (məs. 30 dəq) blokları ilə.
     */
    private function minFirstHourThenInterval(
        int $activeSeconds,
        float $hourlyRate,
        int $minMinutes,
        int $intervalMinutes,
        int $graceMinutes
    ): float {
        $billed = $this->billableMinutesFromActive($activeSeconds, $minMinutes, $intervalMinutes, $graceMinutes);

        return $hourlyRate * ($billed / 60);
    }

    /**
     * Müddətli sessiya: ilk blok minimum saat, hər uzatma interval dəqiqəsi üçün ödəniş.
     */
    public function billableMinutesFromPlanned(
        int $plannedMinutes,
        int $minBillingMinutes = 60,
        int $billingIncrementMinutes = 30
    ): int {
        $minM = max(1, $minBillingMinutes);
        $stepM = max(1, $billingIncrementMinutes);
        if ($plannedMinutes <= $minM) {
            return $minM;
        }

        $over = $plannedMinutes - $minM;
        $blocks = (int) ($over / $stepM);

        return $minM + ($blocks * $stepM);
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

    public function calculateProductsTotal(array $items, bool $excludeSetItems = false): float
    {
        $total = 0.0;
        foreach ($items as $item) {
            if ($excludeSetItems && !empty($item['is_set_item'])) {
                continue;
            }
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
