<?php

declare(strict_types=1);

namespace App\Support;

use PDO;

final class CustomerGroupService
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function listActive(int $businessId = 1): array
    {
        if (!$this->hasTable()) {
            return [];
        }

        $stmt = $this->pdo->prepare(
            'SELECT * FROM customer_groups
             WHERE business_id = ? AND is_active = 1
             ORDER BY sort_order, id'
        );
        $stmt->execute([$businessId]);

        return $stmt->fetchAll() ?: [];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findForCustomer(?int $customerId): ?array
    {
        if ($customerId === null || $customerId <= 0 || !$this->hasTable()) {
            return null;
        }

        $stmt = $this->pdo->prepare(
            'SELECT cg.*
             FROM customers c
             JOIN customer_groups cg ON cg.id = c.customer_group_id
             WHERE c.id = ? AND c.is_active = 1 AND cg.is_active = 1
             LIMIT 1'
        );
        $stmt->execute([$customerId]);

        $row = $stmt->fetch();

        return $row ?: null;
    }

    /**
     * @return array{amount: float, group: ?array<string, mixed>}
     */
    public function resolveDiscount(
        ?int $customerId,
        float $timeCharge,
        float $productsTotal
    ): array {
        $group = $this->findForCustomer($customerId);
        if ($group === null) {
            return ['amount' => 0.0, 'group' => null];
        }

        $subtotal = $timeCharge + $productsTotal;
        $appliesTo = (string) ($group['applies_to'] ?? 'time_only');
        $base = $appliesTo === 'all' ? $subtotal : $timeCharge;
        if ($base <= 0) {
            // Endirim hələ 0 olsa da qrup metadata UI-da göstərilməlidir (VIP badge və s.).
            return ['amount' => 0.0, 'group' => $group];
        }

        $amount = DiscountCalculator::amount(
            $base,
            (string) $group['discount_type'],
            (float) $group['discount_value']
        );

        return ['amount' => $amount, 'group' => $group];
    }

    /**
     * @param array<string, mixed> $session
     *
     * @return array<string, mixed>|null
     */
    public function findForSession(array $session): ?array
    {
        $customerId = isset($session['customer_id']) ? (int) $session['customer_id'] : 0;

        return $this->findForCustomer($customerId > 0 ? $customerId : null);
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function listMembers(int $groupId): array
    {
        if ($groupId <= 0 || !$this->hasTable()) {
            return [];
        }

        $stmt = $this->pdo->prepare(
            'SELECT id, name, phone, email
             FROM customers
             WHERE customer_group_id = ? AND is_active = 1
             ORDER BY name'
        );
        $stmt->execute([$groupId]);

        return $stmt->fetchAll() ?: [];
    }

    /**
     * @param list<int> $add
     * @param list<int> $remove
     */
    public function changeMembers(int $groupId, array $add, array $remove): void
    {
        if ($groupId <= 0 || !$this->hasTable()) {
            throw new \RuntimeException('Müştəri qrupları mövcud deyil — miqrasiya işlədin');
        }

        $now = date('Y-m-d H:i:s');
        $removeStmt = $this->pdo->prepare(
            'UPDATE customers SET customer_group_id = NULL, updated_at = ? WHERE id = ? AND customer_group_id = ?'
        );
        foreach ($this->uniqueIds($remove) as $id) {
            $removeStmt->execute([$now, $id, $groupId]);
        }

        $addStmt = $this->pdo->prepare(
            'UPDATE customers SET customer_group_id = ?, updated_at = ? WHERE id = ? AND is_active = 1'
        );
        foreach ($this->uniqueIds($add) as $id) {
            $addStmt->execute([$groupId, $now, $id]);
        }
    }

    /**
     * @param list<mixed> $ids
     * @return list<int>
     */
    private function uniqueIds(array $ids): array
    {
        $clean = [];
        foreach ($ids as $id) {
            $n = (int) $id;
            if ($n > 0) {
                $clean[$n] = $n;
            }
        }

        return array_values($clean);
    }

    private function hasTable(): bool
    {
        return DbSchema::hasTable($this->pdo, 'customer_groups');
    }
}
