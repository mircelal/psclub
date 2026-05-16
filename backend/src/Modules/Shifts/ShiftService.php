<?php

declare(strict_types=1);

namespace App\Modules\Shifts;

use PDO;

final class ShiftService
{
    public const EXPENSE_CATEGORIES = [
        'internet' => 'İnternet',
        'isig' => 'İşıq',
        'su' => 'Su',
        'cay' => 'Çay / qonaqlıq',
        'icare' => 'İcarə',
        'vergi' => 'Vergi / rüsum',
        'temizlik' => 'Təmizlik',
        'techizat' => 'Təchizat',
        'diger' => 'Digər',
    ];

    public function __construct(private readonly PDO $pdo)
    {
    }

    public function getOpenShift(int $businessId): ?array
    {
        $stmt = $this->pdo->prepare(
            'SELECT s.*, u.full_name AS opened_by_name, u.username AS opened_by_username
             FROM shifts s
             JOIN users u ON u.id = s.opened_by
             WHERE s.business_id = ? AND s.status = \'open\'
             ORDER BY s.opened_at DESC LIMIT 1'
        );
        $stmt->execute([$businessId]);

        return $stmt->fetch() ?: null;
    }

    public function findShift(int $id, int $businessId): ?array
    {
        $stmt = $this->pdo->prepare(
            'SELECT s.*, ou.full_name AS opened_by_name, ou.username AS opened_by_username,
                    cu.full_name AS closed_by_name
             FROM shifts s
             JOIN users ou ON ou.id = s.opened_by
             LEFT JOIN users cu ON cu.id = s.closed_by
             WHERE s.id = ? AND s.business_id = ?'
        );
        $stmt->execute([$id, $businessId]);

        return $stmt->fetch() ?: null;
    }

    /** @return array{cash_sales: float, card_sales: float, expenses: float, owner_withdrawals: float, pay_ins: float, expected_cash: float} */
    public function liveTotals(array $shift): array
    {
        $shiftId = (int) $shift['id'];
        $openedAt = $shift['opened_at'];
        $endAt = $shift['closed_at'] ?? date('Y-m-d H:i:s');

        $salesStmt = $this->pdo->prepare(
            'SELECT COALESCE(SUM(p.cash_amount), 0) AS cash_sales,
                    COALESCE(SUM(p.card_amount), 0) AS card_sales
             FROM payments p
             JOIN sessions s ON s.id = p.session_id
             WHERE s.business_id = ?
               AND s.status = \'closed\'
               AND s.closed_at >= ?
               AND s.closed_at <= ?
               AND (p.shift_id = ? OR p.shift_id IS NULL)'
        );
        $salesStmt->execute([(int) $shift['business_id'], $openedAt, $endAt, $shiftId]);
        $sales = $salesStmt->fetch() ?: ['cash_sales' => 0, 'card_sales' => 0];

        $movStmt = $this->pdo->prepare(
            'SELECT type, COALESCE(SUM(amount), 0) AS total
             FROM cash_movements
             WHERE shift_id = ?
             GROUP BY type'
        );
        $movStmt->execute([$shiftId]);
        $byType = [];
        foreach ($movStmt->fetchAll() as $row) {
            $byType[$row['type']] = (float) $row['total'];
        }

        $opening = (float) $shift['opening_cash'];
        $cashSales = (float) $sales['cash_sales'];
        $expenses = (float) ($byType['expense'] ?? 0);
        $owner = (float) ($byType['owner_withdrawal'] ?? 0);
        $payIns = (float) ($byType['pay_in'] ?? 0);
        $expected = round($opening + $cashSales - $expenses - $owner + $payIns, 2);

        return [
            'cash_sales' => round($cashSales, 2),
            'card_sales' => round((float) $sales['card_sales'], 2),
            'expenses' => round($expenses, 2),
            'owner_withdrawals' => round($owner, 2),
            'pay_ins' => round($payIns, 2),
            'expected_cash' => $expected,
        ];
    }

    public function getMovements(int $shiftId): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT cm.*, u.full_name AS created_by_name, u.username AS created_by_username
             FROM cash_movements cm
             LEFT JOIN users u ON u.id = cm.created_by
             WHERE cm.shift_id = ?
             ORDER BY cm.created_at DESC'
        );
        $stmt->execute([$shiftId]);

        return $stmt->fetchAll();
    }

    public function enrichShift(array $shift): array
    {
        $totals = $this->liveTotals($shift);
        $shift['totals'] = $totals;
        $shift['movements'] = $shift['status'] === 'open' ? $this->getMovements((int) $shift['id']) : [];

        return $shift;
    }

    public function categoryLabel(string $key): string
    {
        if ($key === 'sahibkar') {
            return 'Sahibkarə verilmə';
        }

        return self::EXPENSE_CATEGORIES[$key] ?? $key;
    }
}
