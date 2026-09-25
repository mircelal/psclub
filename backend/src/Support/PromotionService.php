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

        return self::filterCurrentlyActive($stmt->fetchAll() ?: [], $this->serverNow());
    }

    /**
     * @param list<array<string, mixed>> $rows
     * @return list<array<string, mixed>>
     */
    public static function filterCurrentlyActive(array $rows, \DateTimeInterface $now): array
    {
        $out = [];
        foreach ($rows as $promo) {
            $from = isset($promo['valid_from']) && $promo['valid_from'] !== '' ? (string) $promo['valid_from'] : null;
            $until = isset($promo['valid_until']) && $promo['valid_until'] !== '' ? (string) $promo['valid_until'] : null;
            if (!self::isWithinDateRange($from, $until, $now)) {
                continue;
            }
            if (!self::isWithinTimeWindow($promo, $now)) {
                continue;
            }
            $out[] = $promo;
        }

        return $out;
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
            if (($promo['scope'] ?? '') === 'products') {
                continue;
            }
            if (!$this->matchesScope($promo, $tariffName) || !self::isWithinTimeWindow($promo, $this->serverNow())) {
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
     * Məhsul endirimi — scope=products aktiv paketlər.
     *
     * @param list<array<string, mixed>> $items
     * @return array{
     *   amount: float,
     *   promotions: list<array{id: int, name: string, discount_type: string, discount_value: float}>,
     *   item_discounts: array<int, float>
     * }
     */
    public function resolveProductDiscount(array $items, int $businessId = 1): array
    {
        $empty = ['amount' => 0.0, 'promotions' => [], 'item_discounts' => []];
        if ($items === [] || !$this->hasPromotionsTable()) {
            return $empty;
        }

        $productPromos = [];
        foreach ($this->listActive($businessId) as $promo) {
            if (($promo['scope'] ?? '') !== 'products') {
                continue;
            }
            if (!self::isWithinTimeWindow($promo, $this->serverNow())) {
                continue;
            }
            $ids = $this->decodeProductIds($promo['product_ids'] ?? null);
            if ($ids === []) {
                continue;
            }
            $promo['_product_id_set'] = array_fill_keys($ids, true);
            $productPromos[] = $promo;
        }

        if ($productPromos === []) {
            return $empty;
        }

        $total = 0.0;
        $itemDiscounts = [];
        /** @var array<int, array{id: int, name: string, discount_type: string, discount_value: float}> $used */
        $used = [];

        foreach ($items as $item) {
            if (!empty($item['is_set_item'])) {
                continue;
            }
            $productId = (int) ($item['product_id'] ?? 0);
            if ($productId <= 0) {
                continue;
            }
            $lineTotal = round((float) ($item['unit_price'] ?? 0) * (int) ($item['quantity'] ?? 0), 2);
            if ($lineTotal <= 0) {
                continue;
            }

            $bestAmount = 0.0;
            $bestPromo = null;
            foreach ($productPromos as $promo) {
                if (!isset($promo['_product_id_set'][$productId])) {
                    continue;
                }
                $amount = DiscountCalculator::amount(
                    $lineTotal,
                    (string) $promo['discount_type'],
                    (float) $promo['discount_value']
                );
                if ($amount > $bestAmount) {
                    $bestAmount = $amount;
                    $bestPromo = $promo;
                }
            }

            if ($bestPromo === null || $bestAmount <= 0) {
                continue;
            }

            $itemId = (int) ($item['id'] ?? 0);
            if ($itemId > 0) {
                $itemDiscounts[$itemId] = $bestAmount;
            }
            $total += $bestAmount;
            $promoId = (int) $bestPromo['id'];
            if (!isset($used[$promoId])) {
                $used[$promoId] = [
                    'id' => $promoId,
                    'name' => (string) $bestPromo['name'],
                    'discount_type' => (string) $bestPromo['discount_type'],
                    'discount_value' => (float) $bestPromo['discount_value'],
                ];
            }
        }

        return [
            'amount' => round($total, 2),
            'promotions' => array_values($used),
            'item_discounts' => $itemDiscounts,
        ];
    }

    /**
     * @param list<array<string, mixed>> $items
     * @return array{
     *   amount: float,
     *   promotion: ?array<string, mixed>,
     *   customer_group: ?array<string, mixed>,
     *   product_discount: float,
     *   active_product_promotions: list<array{id: int, name: string, discount_type: string, discount_value: float}>,
     *   item_discounts: array<int, float>
     * }
     */
    public function resolveDiscount(
        array $session,
        float $timeCharge,
        float $productsTotal,
        float $manualDiscount = 0.0,
        array $items = []
    ): array {
        $subtotal = $timeCharge + $productsTotal;
        $discountType = $session['discount_type'] ?? 'none';
        $appliesTo = $session['discount_applies_to'] ?? 'time_only';
        $emptyProduct = ['amount' => 0.0, 'promotions' => [], 'item_discounts' => []];

        if ($discountType !== 'none') {
            $base = $appliesTo === 'time_only' ? $timeCharge : $subtotal;
            $value = (float) ($session['discount_value'] ?? 0);
            $amount = DiscountCalculator::amount($base, (string) $discountType, $value);

            return [
                'amount' => $amount,
                'promotion' => null,
                'customer_group' => null,
                'product_discount' => 0.0,
                'active_product_promotions' => [],
                'item_discounts' => [],
            ];
        }

        if ($manualDiscount > 0) {
            return [
                'amount' => min($subtotal, $manualDiscount),
                'promotion' => null,
                'customer_group' => null,
                'product_discount' => 0.0,
                'active_product_promotions' => [],
                'item_discounts' => [],
            ];
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

        $timeOrGroupAmount = 0.0;
        $chosenPromo = null;
        $chosenGroup = null;
        if ($group !== null && $groupAmount >= $promoAmount) {
            $timeOrGroupAmount = $groupAmount;
            $chosenGroup = $group;
        } elseif ($promo !== null && $promoAmount > 0) {
            $timeOrGroupAmount = $promoAmount;
            $chosenPromo = $promo;
        }

        $productResolved = $this->resolveProductDiscount($items, (int) ($session['business_id'] ?? 1));
        $productAmount = $productResolved['amount'];
        $total = min($subtotal, round($timeOrGroupAmount + $productAmount, 2));

        return [
            'amount' => $total,
            'promotion' => $chosenPromo,
            'customer_group' => $chosenGroup,
            'product_discount' => $productAmount,
            'active_product_promotions' => $productResolved['promotions'],
            'item_discounts' => $productResolved['item_discounts'],
        ];
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
    public function validateManualDiscount(array $user, string $type, float $value, float $base, bool $isCounter = false): ?string
    {
        if ($value < 0) {
            return 'Endirim mənfi ola bilməz';
        }

        if (($user['role'] ?? '') !== 'admin') {
            $allowFull = $isCounter && $base > 0 && $type === 'percent' && $value >= 100.0;
            if ($type === 'percent' && $value > self::CASHIER_MAX_PERCENT && !$allowFull) {
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
        if ($scope === 'products') {
            return false;
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

    public static function normalizeValidFrom(mixed $value): ?string
    {
        $day = self::parseDateOnly($value);
        return $day === null ? null : $day . ' 00:00:00';
    }

    public static function normalizeValidUntil(mixed $value): ?string
    {
        $day = self::parseDateOnly($value);
        return $day === null ? null : $day . ' 23:59:59';
    }

    public static function parseDateOnly(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }
        $s = trim((string) $value);
        if (!preg_match('/^(\d{4}-\d{2}-\d{2})/', $s, $m)) {
            return null;
        }
        $parsed = \DateTimeImmutable::createFromFormat('Y-m-d', $m[1]);
        if ($parsed === false || $parsed->format('Y-m-d') !== $m[1]) {
            return null;
        }

        return $m[1];
    }

    public static function isWithinDateRange(?string $from, ?string $until, \DateTimeInterface $now): bool
    {
        $ts = $now->format('Y-m-d H:i:s');
        if ($from !== null && $from !== '' && $ts < $from) {
            return false;
        }
        if ($until !== null && $until !== '' && $ts > $until) {
            return false;
        }

        return true;
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

    private function serverNow(): \DateTimeImmutable
    {
        try {
            $now = $this->pdo->query('SELECT NOW()')->fetchColumn();
            if ($now instanceof \DateTimeInterface) {
                return \DateTimeImmutable::createFromInterface($now);
            }
            if (is_string($now) && $now !== '') {
                return new \DateTimeImmutable($now);
            }
        } catch (\Throwable) {
        }

        return new \DateTimeImmutable();
    }

    /**
     * @return list<int>
     */
    private function decodeProductIds(mixed $raw): array
    {
        if ($raw === null || $raw === '') {
            return [];
        }
        if (is_array($raw)) {
            $decoded = $raw;
        } else {
            $decoded = json_decode((string) $raw, true);
        }
        if (!is_array($decoded)) {
            return [];
        }
        $ids = [];
        foreach ($decoded as $id) {
            $n = (int) $id;
            if ($n > 0) {
                $ids[$n] = $n;
            }
        }

        return array_values($ids);
    }

    private function hasPromotionsTable(): bool
    {
        try {
            $stmt = $this->pdo->query(
                "SELECT 1 FROM information_schema.TABLES
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'promotions' LIMIT 1"
            );
            if ($stmt !== false && $stmt->fetchColumn()) {
                return true;
            }
        } catch (\Throwable) {
        }

        try {
            $this->pdo->query('SELECT 1 FROM promotions LIMIT 1');

            return true;
        } catch (\Throwable) {
            return false;
        }
    }
}
