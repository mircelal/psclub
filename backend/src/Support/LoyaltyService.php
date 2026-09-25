<?php

declare(strict_types=1);

namespace App\Support;

use PDO;

final class LoyaltyService
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function tablesExist(): bool
    {
        return DbSchema::hasTable($this->pdo, 'loyalty_ledger')
            && DbSchema::hasColumn($this->pdo, 'customers', 'bonus_minutes')
            && DbSchema::hasColumn($this->pdo, 'customers', 'bonus_wallet');
    }

    /**
     * @return array{bonus_minutes: int, bonus_wallet: float}
     */
    public function getBalance(int $customerId): array
    {
        if ($customerId <= 0 || !$this->tablesExist()) {
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
            'bonus_wallet' => round((float) ($row['bonus_wallet'] ?? 0), 2),
        ];
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function getLedger(int $customerId, int $limit = 20): array
    {
        if ($customerId <= 0 || !$this->tablesExist()) {
            return [];
        }

        $limit = max(1, min(50, $limit));
        $stmt = $this->pdo->prepare(
            'SELECT id, entry_type, minutes_delta, wallet_delta, note, session_id, created_at
             FROM loyalty_ledger
             WHERE customer_id = ?
             ORDER BY id DESC
             LIMIT ' . $limit
        );
        $stmt->execute([$customerId]);
        $rows = $stmt->fetchAll() ?: [];
        foreach ($rows as &$row) {
            $row['id'] = (int) $row['id'];
            $row['minutes_delta'] = (int) $row['minutes_delta'];
            $row['wallet_delta'] = round((float) $row['wallet_delta'], 2);
        }
        unset($row);

        return $rows;
    }

    /**
     * @return array{minutes_delta: int, wallet_delta: float}
     */
    public function adminGrant(int $customerId, string $kind, float $value, ?string $note, int $adminId): array
    {
        $this->assertReady($customerId);
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
        $this->insertLedger($customerId, $entryType, $minutes, $wallet, $note !== null && trim($note) !== '' ? trim($note) : 'Admin tərəfindən əlavə edildi', null, $adminId);

        return ['minutes_delta' => $minutes, 'wallet_delta' => $wallet];
    }

    /**
     * @return array{minutes_delta: int, wallet_delta: float}
     */
    public function adminAdjust(int $customerId, string $kind, float $delta, string $note, int $adminId): array
    {
        $this->assertReady($customerId);
        $note = trim($note);
        if ($note === '') {
            throw new \InvalidArgumentException('Qeyd tələb olunur');
        }

        $balance = $this->getBalance($customerId);
        $minutes = 0;
        $wallet = 0.0;

        if ($kind === 'hours') {
            $requested = (int) round($delta);
            if ($requested === 0) {
                throw new \InvalidArgumentException('Dəyişiklik sıfır ola bilməz');
            }
            $next = $balance['bonus_minutes'] + $requested;
            $minutes = $next < 0 ? -$balance['bonus_minutes'] : $requested;
            if ($minutes === 0) {
                throw new \InvalidArgumentException('Balans artıq 0-dır');
            }
        } elseif ($kind === 'wallet') {
            $requested = round($delta, 2);
            if (abs($requested) < 0.01) {
                throw new \InvalidArgumentException('Dəyişiklik sıfır ola bilməz');
            }
            $next = round($balance['bonus_wallet'] + $requested, 2);
            $wallet = $next < 0 ? round(-$balance['bonus_wallet'], 2) : $requested;
            if (abs($wallet) < 0.01) {
                throw new \InvalidArgumentException('Balans artıq 0-dır');
            }
        } else {
            throw new \InvalidArgumentException('Yanlış bonus növü');
        }

        $this->applyBalanceDelta($customerId, $minutes, $wallet);
        $this->insertLedger($customerId, 'adjust', $minutes, $wallet, $note, null, $adminId);

        return ['minutes_delta' => $minutes, 'wallet_delta' => $wallet];
    }

    /**
     * @param array<string, mixed> $bill
     * @param array{bonus_minutes: int, bonus_wallet: float}|null $balance
     * @return array<string, mixed>
     */
    public function applyBonusToBill(
        array $bill,
        int $redeemMinutes,
        float $redeemWallet,
        float $hourlyRate,
        ?array $balance
    ): array {
        $bill['bonus_minutes_used'] = 0;
        $bill['bonus_wallet_used'] = 0.0;
        $bill['loyalty_credit'] = 0.0;
        if ($balance === null) {
            return $bill;
        }

        $total = round((float) ($bill['total_amount'] ?? 0), 2);
        $timeCharge = round((float) ($bill['time_charge'] ?? 0), 2);
        $discount = round((float) ($bill['discount'] ?? 0), 2);
        $timeRemaining = max(0.0, round($timeCharge - min($discount, $timeCharge), 2));

        $minutesUsed = 0;
        $minuteCredit = 0.0;
        if ($redeemMinutes > 0 && $hourlyRate > 0 && $timeRemaining > 0 && $total > 0) {
            $available = max(0, (int) ($balance['bonus_minutes'] ?? 0));
            $minutesUsed = min($redeemMinutes, $available);
            $perMinute = $hourlyRate / 60;
            if ($perMinute > 0) {
                $maxByTime = (int) floor(($timeRemaining + 0.0001) / $perMinute);
                $minutesUsed = min($minutesUsed, max(0, $maxByTime));
                $minuteCredit = round($minutesUsed * $perMinute, 2);
                if ($minuteCredit > $timeRemaining) {
                    $minuteCredit = $timeRemaining;
                }
                if ($minuteCredit > $total) {
                    $minuteCredit = $total;
                }
            }
        }

        $totalAfterMinutes = round($total - $minuteCredit, 2);
        $walletAvailable = round((float) ($balance['bonus_wallet'] ?? 0), 2);
        $walletUsed = 0.0;
        if ($redeemWallet > 0 && $walletAvailable > 0 && $totalAfterMinutes > 0) {
            $walletUsed = round(min($redeemWallet, $walletAvailable, $totalAfterMinutes), 2);
        }

        $bill['bonus_minutes_used'] = $minutesUsed;
        $bill['bonus_wallet_used'] = $walletUsed;
        $bill['loyalty_credit'] = round($minuteCredit + $walletUsed, 2);
        $bill['total_amount'] = round(max(0, $total - $minuteCredit - $walletUsed), 2);

        return $bill;
    }

    public function commitRedemption(int $customerId, int $sessionId, int $minutes, float $wallet, int $userId): void
    {
        if ($customerId <= 0 || !$this->tablesExist()) {
            return;
        }
        $minutes = max(0, $minutes);
        $wallet = round(max(0, $wallet), 2);
        if ($minutes === 0 && $wallet <= 0) {
            return;
        }

        $this->applyBalanceDelta($customerId, -$minutes, -$wallet);
        if ($minutes > 0) {
            $this->insertLedger($customerId, 'redeem_hours', -$minutes, 0, 'Satışda istifadə', $sessionId, $userId);
        }
        if ($wallet > 0) {
            $this->insertLedger($customerId, 'redeem_wallet', 0, -$wallet, 'Satışda istifadə', $sessionId, $userId);
        }
    }

    private function assertReady(int $customerId): void
    {
        if (!$this->tablesExist()) {
            throw new \RuntimeException('Loyallıq cədvəlləri mövcud deyil — miqrasiya işlədin');
        }
        $stmt = $this->pdo->prepare('SELECT id FROM customers WHERE id = ? AND is_active = 1');
        $stmt->execute([$customerId]);
        if (!$stmt->fetch()) {
            throw new \InvalidArgumentException('Müştəri tapılmadı');
        }
    }

    private function applyBalanceDelta(int $customerId, int $minutesDelta, float $walletDelta): void
    {
        $stmt = $this->pdo->prepare('SELECT bonus_minutes, bonus_wallet FROM customers WHERE id = ?');
        $stmt->execute([$customerId]);
        $row = $stmt->fetch() ?: ['bonus_minutes' => 0, 'bonus_wallet' => 0];
        $minutes = max(0, (int) $row['bonus_minutes'] + $minutesDelta);
        $wallet = max(0, round((float) $row['bonus_wallet'] + $walletDelta, 2));
        $this->pdo->prepare('UPDATE customers SET bonus_minutes = ?, bonus_wallet = ?, updated_at = ? WHERE id = ?')
            ->execute([$minutes, $wallet, $this->now(), $customerId]);
    }

    private function insertLedger(
        int $customerId,
        string $entryType,
        int $minutesDelta,
        float $walletDelta,
        ?string $note,
        ?int $sessionId,
        int $adminId
    ): void {
        $this->pdo->prepare(
            'INSERT INTO loyalty_ledger (customer_id, entry_type, minutes_delta, wallet_delta, note, session_id, created_by, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
        )->execute([
            $customerId,
            $entryType,
            $minutesDelta,
            round($walletDelta, 2),
            $note,
            $sessionId,
            $adminId > 0 ? $adminId : null,
            $this->now(),
        ]);
    }

    private function now(): string
    {
        return date('Y-m-d H:i:s');
    }
}
