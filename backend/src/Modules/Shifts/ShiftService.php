<?php

declare(strict_types=1);

namespace App\Modules\Shifts;

use App\Support\DbSchema;
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

    /** @return array{cash_sales: float, card_sales: float, expenses: float, owner_withdrawals: float, pay_ins: float, refunds: float, expected_cash: float} */
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
        $refunds = (float) ($byType['refund'] ?? 0);
        $expected = round($opening + $cashSales - $expenses - $owner - $refunds + $payIns, 2);

        return [
            'cash_sales' => round($cashSales, 2),
            'card_sales' => round((float) $sales['card_sales'], 2),
            'expenses' => round($expenses, 2),
            'owner_withdrawals' => round($owner, 2),
            'pay_ins' => round($payIns, 2),
            'refunds' => round($refunds, 2),
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
        $shift['movements'] = $this->getMovements((int) $shift['id']);
        $shift['activity'] = $this->getShiftActivity($shift);

        return $shift;
    }

    /** @return list<array<string, mixed>> */
    public function getShiftActivity(array $shift): array
    {
        $shiftId = (int) $shift['id'];
        $businessId = (int) $shift['business_id'];
        $openedAt = $shift['opened_at'];
        $endAt = $shift['closed_at'] ?? date('Y-m-d H:i:s');

        $activity = [];

        $giftSelect = DbSchema::hasColumn($this->pdo, 'sessions', 'gift_note') ? ', s.gift_note' : '';
        $sessStmt = $this->pdo->prepare(
            'SELECT s.id, s.session_type, s.closed_at, s.time_charge, s.products_total,
                    s.discount, s.total_amount, s.table_id' . $giftSelect . ',
                    t.name AS table_name,
                    p.method AS payment_method, p.cash_amount, p.card_amount, p.created_at AS paid_at
             FROM sessions s
             LEFT JOIN tables t ON t.id = s.table_id
             JOIN payments p ON p.session_id = s.id
             WHERE s.business_id = ?
               AND s.status = \'closed\'
               AND s.order_state != \'deleted\'
               AND s.closed_at >= ?
               AND s.closed_at <= ?
               AND (p.shift_id = ? OR p.shift_id IS NULL)
             ORDER BY s.closed_at DESC'
        );
        $sessStmt->execute([$businessId, $openedAt, $endAt, $shiftId]);
        $sessions = $sessStmt->fetchAll();

        $itemsBySession = [];
        if ($sessions !== []) {
            $ids = array_map(static fn (array $r): int => (int) $r['id'], $sessions);
            $placeholders = implode(',', array_fill(0, count($ids), '?'));
            $itemStmt = $this->pdo->prepare(
                "SELECT session_id, product_name, quantity, unit_price, is_set_item
                 FROM session_items
                 WHERE session_id IN ({$placeholders})
                 ORDER BY session_id, id"
            );
            $itemStmt->execute($ids);
            foreach ($itemStmt->fetchAll() as $row) {
                $sid = (int) $row['session_id'];
                $itemsBySession[$sid][] = $row;
            }
        }

        foreach ($sessions as $session) {
            $sessionId = (int) $session['id'];
            $items = $itemsBySession[$sessionId] ?? [];
            $formatted = $this->formatSessionActivity($session, $items);
            $activity[] = [
                'kind' => 'session',
                'at' => $session['closed_at'] ?? $session['paid_at'],
                'title' => $formatted['title'],
                'amount' => round((float) $session['total_amount'], 2),
                'sign' => '+',
                'session_id' => $sessionId,
                'session_type' => (string) ($session['session_type'] ?? 'table'),
                'lines' => $formatted['lines'],
            ];
        }

        $deletedStmt = $this->pdo->prepare(
            'SELECT s.id, s.session_type, s.closed_at, s.deleted_at, s.time_charge, s.products_total,
                    s.discount, s.total_amount, s.table_id,
                    t.name AS table_name,
                    p.method AS payment_method,
                    COALESCE(p.pre_delete_cash, 0) AS cash_amount,
                    COALESCE(p.pre_delete_card, 0) AS card_amount,
                    u.full_name AS deleted_by_name, u.username AS deleted_by_username
             FROM sessions s
             LEFT JOIN tables t ON t.id = s.table_id
             JOIN payments p ON p.session_id = s.id
             LEFT JOIN users u ON u.id = s.deleted_by
             WHERE s.business_id = ?
               AND s.status = \'closed\'
               AND s.order_state = \'deleted\'
               AND s.deleted_at IS NOT NULL
               AND s.deleted_at >= ?
               AND s.deleted_at <= ?
               AND (p.shift_id = ? OR p.shift_id IS NULL)
             ORDER BY s.deleted_at DESC'
        );
        $deletedStmt->execute([$businessId, $openedAt, $endAt, $shiftId]);
        $deletedSessions = $deletedStmt->fetchAll();

        $deletedItemsBySession = [];
        if ($deletedSessions !== []) {
            $ids = array_map(static fn (array $r): int => (int) $r['id'], $deletedSessions);
            $placeholders = implode(',', array_fill(0, count($ids), '?'));
            $itemStmt = $this->pdo->prepare(
                "SELECT session_id, product_name, quantity, unit_price, is_set_item
                 FROM session_items
                 WHERE session_id IN ({$placeholders})
                 ORDER BY session_id, id"
            );
            $itemStmt->execute($ids);
            foreach ($itemStmt->fetchAll() as $row) {
                $sid = (int) $row['session_id'];
                $deletedItemsBySession[$sid][] = $row;
            }
        }

        foreach ($deletedSessions as $session) {
            $sessionId = (int) $session['id'];
            $items = $deletedItemsBySession[$sessionId] ?? [];
            $formatted = $this->formatSessionActivity($session, $items);
            $adminName = trim((string) ($session['deleted_by_name'] ?? $session['deleted_by_username'] ?? 'Admin'));
            $removedTotal = round((float) $session['total_amount'], 2);

            $activity[] = [
                'kind' => 'session',
                'at' => $session['closed_at'] ?? $session['deleted_at'],
                'title' => $formatted['title'],
                'amount' => $removedTotal,
                'sign' => '+',
                'session_id' => $sessionId,
                'lines' => $formatted['lines'],
            ];

            $activity[] = [
                'kind' => 'order_deleted',
                'at' => $session['deleted_at'],
                'title' => 'Admin ' . $adminName . ' sildi: sifariş #' . $sessionId,
                'subtitle' => $formatted['title'],
                'amount' => $removedTotal,
                'sign' => '−',
                'session_id' => $sessionId,
                'lines' => [
                    ['label' => 'Sifariş #' . $sessionId . ' ləğv edildi', 'amount' => null],
                    ['label' => $adminName, 'amount' => null],
                ],
            ];
        }

        foreach ($this->getMovements($shiftId) as $movement) {
            $type = (string) $movement['type'];
            $isIn = $type === 'pay_in';
            $title = $this->movementActivityTitle($type, (string) ($movement['category'] ?? ''));
            $lines = [];
            if (!empty($movement['description'])) {
                $lines[] = ['label' => (string) $movement['description'], 'amount' => null];
            }
            if (!empty($movement['created_by_name'])) {
                $lines[] = ['label' => (string) $movement['created_by_name'], 'amount' => null];
            }

            $activity[] = [
                'kind' => 'cash_movement',
                'at' => $movement['created_at'],
                'title' => $title,
                'amount' => round((float) $movement['amount'], 2),
                'sign' => $isIn ? '+' : '−',
                'movement_id' => (int) $movement['id'],
                'movement_type' => $type,
                'movement_category' => (string) ($movement['category'] ?? ''),
                'lines' => $lines,
            ];
        }

        usort($activity, static function (array $a, array $b): int {
            return strcmp((string) $a['at'], (string) $b['at']);
        });

        return $activity;
    }

    /**
     * @param array<string, mixed> $session
     * @param list<array<string, mixed>> $items
     * @return array{title: string, lines: list<array{label: string, amount: float|null}>}
     */
    private function formatSessionActivity(array $session, array $items): array
    {
        $sessionType = (string) ($session['session_type'] ?? 'table');
        $timeCharge = round((float) ($session['time_charge'] ?? 0), 2);
        $discount = round((float) ($session['discount'] ?? 0), 2);
        $cash = round((float) ($session['cash_amount'] ?? 0), 2);
        $card = round((float) ($session['card_amount'] ?? 0), 2);
        $tableName = trim((string) ($session['table_name'] ?? ''));

        $productLines = [];
        foreach ($items as $item) {
            if (!empty($item['is_set_item'])) {
                continue;
            }
            $qty = (int) ($item['quantity'] ?? 1);
            $unit = round((float) ($item['unit_price'] ?? 0), 2);
            $lineTotal = round($unit * $qty, 2);
            $name = (string) ($item['product_name'] ?? 'Məhsul');
            $productLines[] = [
                'label' => $qty > 1 ? "{$name} ×{$qty}" : $name,
                'amount' => $lineTotal,
            ];
        }

        $title = $this->sessionActivityTitle($sessionType, $tableName, $timeCharge, $productLines);

        $lines = [];
        if ($timeCharge > 0) {
            $lines[] = ['label' => 'Vaxt', 'amount' => $timeCharge];
        }
        foreach ($productLines as $pl) {
            $lines[] = $pl;
        }
        if ($discount > 0) {
            $lines[] = ['label' => 'Endirim', 'amount' => -$discount];
        }
        $giftNote = trim((string) ($session['gift_note'] ?? ''));
        if ($giftNote !== '') {
            $lines[] = ['label' => 'Hədiyyə: ' . $giftNote, 'amount' => null];
        }
        $payParts = [];
        if ($cash > 0) {
            $payParts[] = 'nağd ' . number_format($cash, 2, '.', '') . ' AZN';
        }
        if ($card > 0) {
            $payParts[] = 'kart ' . number_format($card, 2, '.', '') . ' AZN';
        }
        if ($payParts !== []) {
            $lines[] = ['label' => 'Ödəniş: ' . implode(' · ', $payParts), 'amount' => null];
        }

        return ['title' => $title, 'lines' => $lines];
    }

    /**
     * @param list<array{label: string, amount: float}> $productLines
     */
    private function sessionActivityTitle(
        string $sessionType,
        string $tableName,
        float $timeCharge,
        array $productLines
    ): string {
        if ($sessionType === 'counter') {
            if ($timeCharge <= 0 && count($productLines) === 1) {
                $p = $productLines[0];

                return 'Kassa: ' . $p['label'];
            }

            return 'Kassa satışı — bağlandı';
        }

        $label = $tableName !== '' ? $tableName : 'Masa';

        return $label . ' — bağlandı';
    }

    private function movementActivityTitle(string $type, string $category): string
    {
        if ($type === 'owner_withdrawal') {
            return 'Sahibkarə verilmə';
        }
        if ($type === 'pay_in') {
            return 'Kassaya əlavə';
        }
        if ($type === 'refund') {
            return 'Satış qaytarması';
        }

        return $this->categoryLabel($category);
    }

    public function categoryLabel(string $key): string
    {
        if ($key === 'sahibkar') {
            return 'Sahibkarə verilmə';
        }
        if ($key === 'sale_refund') {
            return 'Satış qaytarması';
        }

        return self::EXPENSE_CATEGORIES[$key] ?? $key;
    }

    public function movementTypeLabel(string $type): string
    {
        return match ($type) {
            'expense' => 'Xərc',
            'owner_withdrawal' => 'Sahibkarə',
            'pay_in' => 'Kassaya mədaxil',
            'refund' => 'Satış qaytarması',
            default => $type,
        };
    }
}
