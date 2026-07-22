<?php

declare(strict_types=1);

namespace App\Support;

use PDO;

final class LoyaltyService
{
    private const DEFAULT_HOURLY_RATE = 10.0;

    public function __construct(private readonly PDO $pdo)
    {
    }

    public function tablesExist(): bool
    {
        $stmt = $this->pdo->query("SHOW TABLES LIKE 'loyalty_tiers'");

        return (bool) $stmt->fetch();
    }

    /**
     * @return array{bonus_minutes: int, bonus_wallet: float}
     */
    public function getBalance(int $customerId): array
    {
        if (!$this->tablesExist()) {
            return ['bonus_minutes' => 0, 'bonus_wallet' => 0.0];
        }

        $stmt = $this->pdo->prepare('SELECT bonus_minutes, bonus_wallet FROM customers WHERE id = ? AND is_active = 1');
        $stmt->execute([$customerId]);
        $row = $stmt->fetch();

        if (!$row) {
            return ['bonus_minutes' => 0, 'bonus_wallet' => 0.0];
        }

        return [
            'bonus_minutes' => (int) ($row['bonus_minutes'] ?? 0),
            'bonus_wallet' => (float) ($row['bonus_wallet'] ?? 0),
        ];
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function getLedger(int $customerId, int $limit = 50): array
    {
        if (!$this->tablesExist()) {
            return [];
        }

        $stmt = $this->pdo->prepare(
            'SELECT l.*, t.name AS tier_name, u.full_name AS created_by_name
             FROM loyalty_ledger l
             LEFT JOIN loyalty_tiers t ON t.id = l.tier_id
             LEFT JOIN users u ON u.id = l.created_by
             WHERE l.customer_id = ?
             ORDER BY l.id DESC
             LIMIT ' . max(1, min($limit, 200))
        );
        $stmt->execute([$customerId]);

        return $stmt->fetchAll() ?: [];
    }

    /**
     * @return array{minutes_delta: int, wallet_delta: float, entries: list<array<string, mixed>>}
     */
    public function processTierRewards(int $customerId, int $sessionId, ?int $adminId = null, float $sessionPaidAmount = 0): array
    {
        if (!$this->tablesExist() || $sessionPaidAmount <= 0) {
            return ['minutes_delta' => 0, 'wallet_delta' => 0.0, 'entries' => []];
        }

        $totalSpent = $this->lifetimeQualifyingSpend($customerId);
        $previousSpent = max(0.0, $totalSpent - $sessionPaidAmount);
        $tiers = $this->activeTiers();
        $totalMinutes = 0;
        $totalWallet = 0.0;
        $entries = [];

        foreach ($tiers as $tier) {
            $threshold = (float) $tier['spend_threshold'];
            if ($threshold <= 0) {
                continue;
            }

            $tierId = (int) $tier['id'];
            if ($this->tierEarnCountForSession($customerId, $tierId, $sessionId) > 0) {
                continue;
            }

            // Yalnız bu sessiyanın ödənişi ilə keçilən hədd sayı; sessiya üzrə max 1 mükafat.
            $crossings = (int) floor($totalSpent / $threshold) - (int) floor($previousSpent / $threshold);
            $toGrant = min(1, max(0, $crossings));

            for ($i = 0; $i < $toGrant; $i++) {
                $reward = $this->computeTierReward($tier, $threshold);
                $this->applyBalanceDelta($customerId, $reward['minutes'], $reward['wallet']);
                $this->insertLedger([
                    'customer_id' => $customerId,
                    'entry_type' => 'tier_earn',
                    'minutes_delta' => $reward['minutes'],
                    'wallet_delta' => $reward['wallet'],
                    'session_id' => $sessionId,
                    'tier_id' => $tierId,
                    'note' => sprintf('«%s» — %.2f ₼ həddinə çatdı', $tier['name'], $threshold),
                    'created_by' => $adminId,
                ]);
                $totalMinutes += $reward['minutes'];
                $totalWallet += $reward['wallet'];
                $entries[] = [
                    'tier_id' => $tierId,
                    'tier_name' => $tier['name'],
                    'minutes' => $reward['minutes'],
                    'wallet' => $reward['wallet'],
                ];
            }
        }

        return [
            'minutes_delta' => $totalMinutes,
            'wallet_delta' => round($totalWallet, 2),
            'entries' => $entries,
        ];
    }

    public function commitRedemption(
        int $customerId,
        int $sessionId,
        int $minutesUsed,
        float $walletUsed,
        ?int $adminId = null
    ): void {
        if (!$this->tablesExist() || ($minutesUsed <= 0 && $walletUsed <= 0)) {
            return;
        }

        if ($minutesUsed > 0) {
            $this->applyBalanceDelta($customerId, -$minutesUsed, 0);
            $this->insertLedger([
                'customer_id' => $customerId,
                'entry_type' => 'redeem_hours',
                'minutes_delta' => -$minutesUsed,
                'wallet_delta' => 0,
                'session_id' => $sessionId,
                'note' => sprintf('Sessiya #%d — %d dəq istifadə', $sessionId, $minutesUsed),
                'created_by' => $adminId,
            ]);
        }

        if ($walletUsed > 0) {
            $this->applyBalanceDelta($customerId, 0, -$walletUsed);
            $this->insertLedger([
                'customer_id' => $customerId,
                'entry_type' => 'redeem_wallet',
                'minutes_delta' => 0,
                'wallet_delta' => -$walletUsed,
                'session_id' => $sessionId,
                'note' => sprintf('Sessiya #%d — %.2f ₼ endirim', $sessionId, $walletUsed),
                'created_by' => $adminId,
            ]);
        }
    }

    /**
     * @return array{minutes_delta: int, wallet_delta: float}
     */
    public function adminGrant(
        int $customerId,
        string $kind,
        float $value,
        ?string $note,
        int $adminId
    ): array {
        if (!$this->tablesExist()) {
            throw new \RuntimeException('Loyallıq cədvəlləri mövcud deyil — miqrasiya işlədin');
        }

        $minutes = 0;
        $wallet = 0.0;
        $entryType = 'adjust';

        if ($kind === 'hours') {
            $minutes = max(0, (int) round($value));
            $entryType = 'admin_hours';
        } elseif ($kind === 'wallet') {
            $wallet = max(0, round($value, 2));
            $entryType = 'admin_wallet';
        } else {
            throw new \InvalidArgumentException('Yanlış bonus növü');
        }

        if ($minutes === 0 && $wallet <= 0) {
            throw new \InvalidArgumentException('Məbləğ sıfırdan böyük olmalıdır');
        }

        $this->applyBalanceDelta($customerId, $minutes, $wallet);
        $this->insertLedger([
            'customer_id' => $customerId,
            'entry_type' => $entryType,
            'minutes_delta' => $minutes,
            'wallet_delta' => $wallet,
            'note' => $note ?: 'Admin tərəfindən əlavə edildi',
            'created_by' => $adminId,
        ]);

        return ['minutes_delta' => $minutes, 'wallet_delta' => $wallet];
    }

    public function resolveHourlyRate(array $session): float
    {
        $rate = (float) ($session['hourly_rate_snapshot'] ?? 0);
        if ($rate > 0) {
            return $rate;
        }

        $setPrice = (float) ($session['set_price_snapshot'] ?? 0);
        $planned = (int) ($session['planned_minutes'] ?? 0);
        if ($setPrice > 0 && $planned > 0) {
            return round($setPrice / ($planned / 60), 4);
        }

        return self::DEFAULT_HOURLY_RATE;
    }

    /**
     * @return array{
     *   loyalty_preview: ?array<string, mixed>,
     *   customer_bonus_minutes: int,
     *   customer_bonus_wallet: float
     * }
     */
    public function previewMaxBonus(array $bill, array $session): array
    {
        $customerId = (int) ($session['customer_id'] ?? 0);
        if ($customerId <= 0) {
            return [
                'loyalty_preview' => null,
                'customer_bonus_minutes' => 0,
                'customer_bonus_wallet' => 0.0,
            ];
        }

        $balance = $this->getBalance($customerId);
        if ($balance['bonus_minutes'] <= 0 && $balance['bonus_wallet'] <= 0) {
            return [
                'loyalty_preview' => null,
                'customer_bonus_minutes' => $balance['bonus_minutes'],
                'customer_bonus_wallet' => $balance['bonus_wallet'],
            ];
        }

        $workingBill = $bill;
        $adjusted = $this->applyBonusToBill(
            $workingBill,
            $balance['bonus_minutes'],
            $balance['bonus_wallet'],
            $this->resolveHourlyRate($session),
            $balance
        );

        return [
            'loyalty_preview' => [
                'bonus_minutes_used' => $adjusted['bonus_minutes_used'],
                'bonus_wallet_used' => $adjusted['bonus_wallet_used'],
                'bonus_time_credit' => $adjusted['bonus_time_credit'],
                'bonus_wallet_credit' => $adjusted['bonus_wallet_credit'],
                'loyalty_credit' => $adjusted['loyalty_credit'],
                'total_after_bonus' => $adjusted['total_amount'],
            ],
            'customer_bonus_minutes' => $balance['bonus_minutes'],
            'customer_bonus_wallet' => $balance['bonus_wallet'],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function applyBonusToBill(
        array $bill,
        int $requestedMinutes,
        float $requestedWallet,
        float $hourlyRate,
        ?array $balance = null
    ): array {
        $total = (float) ($bill['total_amount'] ?? 0);
        $rate = $hourlyRate > 0 ? $hourlyRate : self::DEFAULT_HOURLY_RATE;
        $bonusMinutesUsed = max(0, $requestedMinutes);
        $bonusWalletUsed = max(0, round($requestedWallet, 2));

        if ($balance !== null) {
            $bonusMinutesUsed = min($bonusMinutesUsed, (int) ($balance['bonus_minutes'] ?? 0));
            $bonusWalletUsed = min($bonusWalletUsed, round((float) ($balance['bonus_wallet'] ?? 0), 2));
        }

        $timePayable = $this->timePayableAfterDiscount($bill);
        $activeSeconds = (int) ($bill['active_seconds'] ?? 0);
        if ($activeSeconds > 0 && $timePayable > 0 && $rate > 0) {
            $playedMinutes = (int) ceil($activeSeconds / 60);
            $neededMinutes = (int) ceil(($timePayable / $rate) * 60);
            $bonusMinutesUsed = min($bonusMinutesUsed, max($neededMinutes, $playedMinutes));
        }

        $timeCredit = 0.0;
        if ($bonusMinutesUsed > 0 && $total > 0 && $timePayable > 0) {
            $minuteValue = round(($bonusMinutesUsed / 60) * $rate, 2);
            $timeCredit = min($minuteValue, $timePayable, $total);
            if ($timeCredit < $minuteValue && $rate > 0) {
                $bonusMinutesUsed = (int) ceil(($timeCredit / $rate) * 60);
            }
            $total = round($total - $timeCredit, 2);
        } else {
            $bonusMinutesUsed = 0;
        }

        $walletCredit = 0.0;
        if ($bonusWalletUsed > 0 && $total > 0) {
            $walletCredit = min($bonusWalletUsed, $total);
            $bonusWalletUsed = $walletCredit;
            $total = round($total - $walletCredit, 2);
        } else {
            $bonusWalletUsed = 0.0;
        }

        $bill['bonus_minutes_used'] = $bonusMinutesUsed;
        $bill['bonus_wallet_used'] = round($bonusWalletUsed, 2);
        $bill['bonus_time_credit'] = round($timeCredit, 2);
        $bill['bonus_wallet_credit'] = round($walletCredit, 2);
        $bill['loyalty_credit'] = round($timeCredit + $walletCredit, 2);
        $bill['total_amount'] = max(0, $total);

        return $bill;
    }

    private function timePayableAfterDiscount(array $bill): float
    {
        $timeCharge = (float) ($bill['time_charge'] ?? 0);
        $productsTotal = (float) ($bill['products_total'] ?? 0);
        $discount = (float) ($bill['discount'] ?? 0);
        $appliesTo = (string) ($bill['discount_applies_to'] ?? 'time_only');

        if ($timeCharge <= 0) {
            return 0.0;
        }
        if ($discount <= 0) {
            return $timeCharge;
        }
        if ($appliesTo === 'time_only') {
            return max(0.0, round($timeCharge - $discount, 2));
        }

        $subtotal = $timeCharge + $productsTotal;
        if ($subtotal <= 0) {
            return 0.0;
        }

        return max(0.0, round($timeCharge - ($discount * $timeCharge / $subtotal), 2));
    }

    private function lifetimeQualifyingSpend(int $customerId): float
    {
        // Yalnız real ödənilmiş məbləğ — bonusla örtülən sessiyalar (total_amount=0) sayılmır.
        $stmt = $this->pdo->prepare(
            "SELECT COALESCE(SUM(total_amount), 0) FROM sessions WHERE customer_id = ? AND status = 'closed'"
        );
        $stmt->execute([$customerId]);

        return (float) $stmt->fetchColumn();
    }

    private function lifetimeSpend(int $customerId): float
    {
        return $this->lifetimeQualifyingSpend($customerId);
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function activeTiers(): array
    {
        $stmt = $this->pdo->query(
            'SELECT * FROM loyalty_tiers WHERE is_active = 1 ORDER BY sort_order, spend_threshold, id'
        );

        return $stmt->fetchAll() ?: [];
    }

    private function tierEarnCountForSession(int $customerId, int $tierId, int $sessionId): int
    {
        $stmt = $this->pdo->prepare(
            "SELECT COUNT(*) FROM loyalty_ledger
             WHERE customer_id = ? AND tier_id = ? AND session_id = ? AND entry_type = 'tier_earn'"
        );
        $stmt->execute([$customerId, $tierId, $sessionId]);

        return (int) $stmt->fetchColumn();
    }

    /**
     * @param array<string, mixed> $tier
     * @return array{minutes: int, wallet: float}
     */
    private function computeTierReward(array $tier, float $threshold): array
    {
        $kind = (string) $tier['reward_kind'];
        $value = (float) $tier['reward_value'];
        $rate = (float) ($tier['reference_hourly_rate'] ?? 0);
        if ($rate <= 0) {
            $rate = self::DEFAULT_HOURLY_RATE;
        }

        return match ($kind) {
            'hours' => ['minutes' => max(0, (int) round($value)), 'wallet' => 0.0],
            'hours_percent' => [
                'minutes' => max(0, (int) round((($threshold * $value / 100) / $rate) * 60)),
                'wallet' => 0.0,
            ],
            'wallet_percent' => ['minutes' => 0, 'wallet' => round($threshold * $value / 100, 2)],
            'wallet_fixed' => ['minutes' => 0, 'wallet' => round($value, 2)],
            default => ['minutes' => 0, 'wallet' => 0.0],
        };
    }

    private function applyBalanceDelta(int $customerId, int $minutesDelta, float $walletDelta): void
    {
        $this->pdo->prepare(
            'UPDATE customers SET
                bonus_minutes = GREATEST(0, bonus_minutes + ?),
                bonus_wallet = GREATEST(0, bonus_wallet + ?),
                updated_at = NOW()
             WHERE id = ?'
        )->execute([$minutesDelta, $walletDelta, $customerId]);
    }

    /**
     * @param array<string, mixed> $row
     */
    private function insertLedger(array $row): void
    {
        $this->pdo->prepare(
            'INSERT INTO loyalty_ledger
                (customer_id, entry_type, minutes_delta, wallet_delta, session_id, tier_id, note, created_by, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())'
        )->execute([
            $row['customer_id'],
            $row['entry_type'],
            $row['minutes_delta'] ?? 0,
            $row['wallet_delta'] ?? 0,
            $row['session_id'] ?? null,
            $row['tier_id'] ?? null,
            $row['note'] ?? null,
            $row['created_by'] ?? null,
        ]);
    }
}
