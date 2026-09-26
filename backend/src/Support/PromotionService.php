<?php

declare(strict_types=1);

namespace App\Support;

use PDO;

final class PromotionService
{
    private const CASHIER_MAX_PERCENT = 30.0;

    public function __construct(
        private readonly PDO $pdo,
        private readonly CustomerGroupService $customerGroups,
        private readonly ?SpendDiscountService $spendDiscounts = null,
    ) {
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function listActive(int $businessId = 1): array
    {
        if (!$this->hasPromotionsTable()) {
            return [];
        }

        $stmt = $this->pdo->prepare(
            'SELECT * FROM promotions
             WHERE business_id = ? AND is_active = 1
               AND (valid_from IS NULL OR valid_from <= NOW())
               AND (valid_until IS NULL OR valid_until >= NOW())
             ORDER BY sort_order, id'
        );
        $stmt->execute([$businessId]);

        return self::filterBySchedule($stmt->fetchAll() ?: []);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findBestForSession(array $session, float $timeCharge): ?array
    {
        if ($timeCharge <= 0 || ($session['session_type'] ?? 'table') === 'counter') {
            return null;
        }

        $tariffName = trim((string) ($session['tariff_name_snapshot'] ?? ''));
        $best = null;
        $bestAmount = 0.0;

        foreach ($this->listActive((int) ($session['business_id'] ?? 1)) as $promo) {
            if (!$this->matchesScope($promo, $tariffName)) {
                continue;
            }
            $amount = DiscountCalculator::amount($timeCharge, (string) $promo['discount_type'], (float) $promo['discount_value']);
            if ($amount > $bestAmount) {
                $bestAmount = $amount;
                $best = $promo;
            }
        }

        return $best;
    }

    /**
     * @return array{amount: float, promotion: ?array<string, mixed>, customer_group: ?array<string, mixed>, spend_rule: ?array<string, mixed>}
     */
    public function resolveDiscount(
        array $session,
        float $timeCharge,
        float $productsTotal,
        float $manualDiscount = 0.0
    ): array {
        $subtotal = $timeCharge + $productsTotal;
        $discountType = $session['discount_type'] ?? 'none';
        $appliesTo = $session['discount_applies_to'] ?? 'time_only';

        if ($discountType !== 'none') {
            $base = $appliesTo === 'time_only' ? $timeCharge : $subtotal;
            $value = (float) ($session['discount_value'] ?? 0);
            $amount = DiscountCalculator::amount($base, (string) $discountType, $value);

            return ['amount' => $amount, 'promotion' => null, 'customer_group' => null, 'spend_rule' => null];
        }

        if ($manualDiscount > 0) {
            return ['amount' => min($subtotal, $manualDiscount), 'promotion' => null, 'customer_group' => null, 'spend_rule' => null];
        }

        $customerId = isset($session['customer_id']) ? (int) $session['customer_id'] : 0;
        $groupResolved = $this->customerGroups->resolveDiscount(
            $customerId > 0 ? $customerId : null,
            $timeCharge,
            $productsTotal
        );
        $groupAmount = $groupResolved['amount'];
        $group = $groupResolved['group'];

        $promo = $this->findBestForSession($session, $timeCharge);
        $promoAmount = 0.0;
        if ($promo !== null) {
            $promoAmount = DiscountCalculator::amount(
                $timeCharge,
                (string) $promo['discount_type'],
                (float) $promo['discount_value']
            );
        }

        $spendResolved = $this->spendRules()->resolve(
            $customerId > 0 ? $customerId : null,
            $timeCharge,
            $productsTotal
        );
        $spendAmount = $spendResolved['amount'];
        $spendRule = $spendResolved['rule'];

        if ($group !== null && $groupAmount >= $promoAmount && $groupAmount >= $spendAmount) {
            return ['amount' => $groupAmount, 'promotion' => null, 'customer_group' => $group, 'spend_rule' => null];
        }

        if ($promo !== null && $promoAmount >= $spendAmount && $promoAmount > 0) {
            return ['amount' => $promoAmount, 'promotion' => $promo, 'customer_group' => null, 'spend_rule' => null];
        }

        if ($spendRule !== null && $spendAmount > 0) {
            return ['amount' => $spendAmount, 'promotion' => null, 'customer_group' => null, 'spend_rule' => $spendRule];
        }

        return ['amount' => 0.0, 'promotion' => null, 'customer_group' => null, 'spend_rule' => null];
    }

    /**
     * UI üçün — endirim tətbiq olunmasa belə müştəri qrupu metadata.
     *
     * @return array<string, mixed>|null
     */
    public function displayCustomerGroup(array $session): ?array
    {
        $group = $this->customerGroups->findForSession($session);
        if ($group === null) {
            return null;
        }

        return [
            'id' => (int) $group['id'],
            'name' => (string) $group['name'],
            'discount_type' => (string) $group['discount_type'],
            'discount_value' => (float) $group['discount_value'],
            'applies_to' => (string) ($group['applies_to'] ?? 'time_only'),
            'color' => $group['color'] ?? null,
        ];
    }

    /**
     * @param array<string, mixed> $user
     */
    public function validateManualDiscount(array $user, string $type, float $value, float $base, bool $allowFull = false): ?string
    {
        if ($value < 0) {
            return 'Endirim mənfi ola bilməz';
        }

        if (($user['role'] ?? '') !== 'admin') {
            if (!$allowFull && $type === 'percent' && $value > self::CASHIER_MAX_PERCENT) {
                return 'Kassir üçün maksimum endirim ' . (int) self::CASHIER_MAX_PERCENT . '%';
            }
            if ($type === 'fixed' && $value > $base) {
                return 'Endirim məbləği endirim bazasından böyük ola bilməz';
            }
        }

        return null;
    }

    public static function cashierMaxPercent(): float
    {
        return self::CASHIER_MAX_PERCENT;
    }

    private function matchesScope(array $promo, string $tariffName): bool
    {
        $scope = (string) ($promo['scope'] ?? 'all_tables');
        if ($scope === 'all_tables') {
            return true;
        }

        $names = json_decode((string) ($promo['tariff_names'] ?? '[]'), true);
        if (!is_array($names) || $names === []) {
            return false;
        }

        foreach ($names as $name) {
            if (strcasecmp(trim((string) $name), $tariffName) === 0) {
                return true;
            }
        }

        return false;
    }

    /**
     * @param list<array<string, mixed>> $rows
     * @return list<array<string, mixed>>
     */
    public static function filterBySchedule(array $rows, ?\DateTimeInterface $now = null): array
    {
        $now = $now ?? new \DateTimeImmutable('now');
        $out = [];
        foreach ($rows as $row) {
            if (self::isWithinTimeWindow($row, $now)) {
                $out[] = $row;
            }
        }

        return $out;
    }

    /**
     * @param array<string, mixed> $promo
     */
    public static function isWithinTimeWindow(array $promo, \DateTimeInterface $now): bool
    {
        $days = self::decodeJsonList($promo['valid_days'] ?? null);
        if ($days !== []) {
            $weekday = (int) $now->format('N') - 1;
            $normalized = array_map(static fn ($d) => (int) $d, $days);
            if (!in_array($weekday, $normalized, true)) {
                return false;
            }
        }

        $hours = self::decodeJsonList($promo['valid_hours'] ?? null);
        if ($hours === []) {
            return true;
        }

        $current = (int) $now->format('H') * 60 + (int) $now->format('i');
        foreach ($hours as $range) {
            if (!is_array($range)) {
                continue;
            }
            $from = self::parseClockMinutes($range['from'] ?? null);
            $until = self::parseClockMinutes($range['until'] ?? null);
            if ($from === null || $until === null) {
                continue;
            }
            if ($from <= $until) {
                if ($current >= $from && $current <= $until) {
                    return true;
                }
            } elseif ($current >= $from || $current <= $until) {
                return true;
            }
        }

        return false;
    }

    /**
     * Keep weekday 0 (Monday). Bare array_filter() drops it.
     *
     * @param mixed $value
     */
    public static function encodeValidDays(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }
        if (is_string($value)) {
            $decoded = json_decode($value, true);
            $value = is_array($decoded) ? $decoded : [];
        }
        if (!is_array($value)) {
            return null;
        }
        $mapped = array_map(static fn ($v) => (int) $v, $value);
        $clean = array_values(array_unique(array_filter($mapped, static fn ($v) => $v >= 0 && $v <= 6)));
        if ($clean === []) {
            return null;
        }

        return json_encode($clean, JSON_UNESCAPED_UNICODE);
    }

    /**
     * @param mixed $value
     */
    public static function encodeValidHours(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }
        if (is_string($value)) {
            return $value;
        }
        if (!is_array($value)) {
            return null;
        }
        $clean = [];
        foreach ($value as $range) {
            if (!is_array($range)) {
                continue;
            }
            $from = self::parseClockMinutes($range['from'] ?? null);
            $until = self::parseClockMinutes($range['until'] ?? null);
            if ($from === null || $until === null) {
                continue;
            }
            $clean[] = [
                'from' => sprintf('%02d:%02d', intdiv($from, 60), $from % 60),
                'until' => sprintf('%02d:%02d', intdiv($until, 60), $until % 60),
            ];
        }
        if ($clean === []) {
            return null;
        }

        return json_encode($clean, JSON_UNESCAPED_UNICODE);
    }

    public static function parseClockMinutes(mixed $time): ?int
    {
        if ($time === null || $time === '') {
            return null;
        }
        if (!preg_match('/^(\d{1,2}):(\d{2})$/', trim((string) $time), $m)) {
            return null;
        }
        $h = (int) $m[1];
        $min = (int) $m[2];
        if ($h > 23 || $min > 59) {
            return null;
        }

        return $h * 60 + $min;
    }

    /**
     * @return list<mixed>
     */
    private static function decodeJsonList(mixed $raw): array
    {
        if (is_array($raw)) {
            return $raw;
        }
        if ($raw === null || $raw === '') {
            return [];
        }
        $decoded = json_decode((string) $raw, true);

        return is_array($decoded) ? $decoded : [];
    }

    private function spendRules(): SpendDiscountService
    {
        return $this->spendDiscounts ?? new SpendDiscountService($this->pdo);
    }

    private function hasPromotionsTable(): bool
    {
        return DbSchema::hasTable($this->pdo, 'promotions');
    }
}
