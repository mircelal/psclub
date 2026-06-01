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

        return $stmt->fetchAll() ?: [];
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
     * @return array{amount: float, promotion: ?array<string, mixed>, customer_group: ?array<string, mixed>}
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

            return ['amount' => $amount, 'promotion' => null, 'customer_group' => null];
        }

        if ($manualDiscount > 0) {
            return ['amount' => min($subtotal, $manualDiscount), 'promotion' => null, 'customer_group' => null];
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

        if ($group !== null && $groupAmount >= $promoAmount) {
            return ['amount' => $groupAmount, 'promotion' => null, 'customer_group' => $group];
        }

        if ($promo !== null && $promoAmount > 0) {
            return ['amount' => $promoAmount, 'promotion' => $promo, 'customer_group' => null];
        }

        return ['amount' => 0.0, 'promotion' => null, 'customer_group' => null];
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
    public function validateManualDiscount(array $user, string $type, float $value, float $base): ?string
    {
        if ($value < 0) {
            return 'Endirim mənfi ola bilməz';
        }

        if (($user['role'] ?? '') !== 'admin') {
            if ($type === 'percent' && $value > self::CASHIER_MAX_PERCENT) {
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

    private function hasPromotionsTable(): bool
    {
        $stmt = $this->pdo->query(
            "SELECT 1 FROM information_schema.TABLES
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'promotions' LIMIT 1"
        );

        return (bool) $stmt->fetchColumn();
    }
}
