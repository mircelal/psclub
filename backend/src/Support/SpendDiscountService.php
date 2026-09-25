<?php

declare(strict_types=1);

namespace App\Support;

use PDO;

final class SpendDiscountService
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function tablesExist(): bool
    {
        return DbSchema::hasTable($this->pdo, 'spend_discount_rules');
    }

    /**
     * @return array{amount: float, rule: ?array<string, mixed>}
     */
    public function resolve(
        ?int $customerId,
        float $timeCharge,
        float $productsTotal,
        ?\DateTimeInterface $now = null
    ): array {
        if ($customerId === null || $customerId <= 0 || !$this->tablesExist()) {
            return ['amount' => 0.0, 'rule' => null];
        }

        $now = $now ?? new \DateTimeImmutable('now');
        $best = null;
        $bestThreshold = -1.0;
        $bestAmount = 0.0;

        foreach ($this->activeRules() as $rule) {
            $spent = $this->qualifyingSpend($customerId, $rule, $now);
            $threshold = round((float) $rule['min_spend'], 2);
            if ($spent + 0.0001 < $threshold) {
                continue;
            }

            $appliesTo = (string) ($rule['applies_to'] ?? 'all');
            $base = $appliesTo === 'all' ? $timeCharge + $productsTotal : $timeCharge;
            $amount = $base > 0
                ? DiscountCalculator::amount($base, (string) $rule['discount_type'], (float) $rule['discount_value'])
                : 0.0;

            if ($threshold > $bestThreshold || (abs($threshold - $bestThreshold) < 0.001 && $amount > $bestAmount)) {
                $best = $rule;
                $bestThreshold = $threshold;
                $bestAmount = $amount;
            }
        }

        return ['amount' => $bestAmount, 'rule' => $best];
    }

    /**
     * @param array<string, mixed> $rule
     */
    public function qualifyingSpend(int $customerId, array $rule, \DateTimeInterface $now): float
    {
        $from = $this->windowStart($rule, $now);
        $sql = "SELECT COALESCE(SUM(time_charge + products_total), 0)
                FROM sessions
                WHERE customer_id = ? AND status = 'closed'
                  AND (order_state IS NULL OR order_state <> 'deleted')";
        $params = [$customerId];
        if ($from !== null) {
            $sql .= ' AND closed_at >= ?';
            $params[] = $from;
        }

        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);

        return round((float) $stmt->fetchColumn(), 2);
    }

    /**
     * @param array<string, mixed> $rule
     */
    public function windowStart(array $rule, \DateTimeInterface $now): ?string
    {
        $type = (string) ($rule['window_type'] ?? 'lifetime');
        if ($type === 'calendar_month') {
            return $now->format('Y-m-01 00:00:00');
        }
        if ($type === 'rolling_days') {
            $days = max(1, (int) ($rule['window_days'] ?? 1));
            $start = \DateTimeImmutable::createFromInterface($now)->modify('-' . $days . ' days');

            return $start->format('Y-m-d H:i:s');
        }

        return null;
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function activeRules(): array
    {
        $stmt = $this->pdo->query(
            'SELECT * FROM spend_discount_rules WHERE is_active = 1 ORDER BY min_spend DESC, id ASC'
        );

        return $stmt->fetchAll() ?: [];
    }
}
