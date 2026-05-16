<?php

declare(strict_types=1);

namespace App\Modules\Shifts;

use App\Support\ApiResponse;
use App\Support\DatabaseClock;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class ShiftsController
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly ShiftService $shifts,
        private readonly DatabaseClock $clock,
    ) {
    }

    public function categories(Request $request, Response $response): Response
    {
        return ApiResponse::success([
            'expense_categories' => ShiftService::EXPENSE_CATEGORIES,
            'movement_types' => [
                'expense' => 'Xərc',
                'owner_withdrawal' => 'Sahibkarə verilmə',
                'pay_in' => 'Kassaya əlavə',
            ],
        ]);
    }

    public function current(Request $request, Response $response): Response
    {
        $user = $request->getAttribute('user');
        $businessId = (int) $user['business_id'];
        $shift = $this->shifts->getOpenShift($businessId);

        if (!$shift) {
            return ApiResponse::success(null);
        }

        return ApiResponse::success($this->shifts->enrichShift($shift));
    }

    public function open(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');
        $businessId = (int) $user['business_id'];

        if (!$this->validateAmount($body, 'opening_cash', allowZero: true)) {
            return ApiResponse::error('Başlanğıc kassa məbləği düzgün deyil', 422);
        }

        if ($this->shifts->getOpenShift($businessId)) {
            return ApiResponse::error('Artıq açıq növbə var. Əvvəlcə onu bağlayın.', 409);
        }

        $openingCash = round((float) $body['opening_cash'], 2);
        $now = $this->clock->now();

        $this->pdo->prepare(
            'INSERT INTO shifts (business_id, opened_by, status, opened_at, opening_cash, created_at, updated_at)
             VALUES (?, ?, \'open\', ?, ?, NOW(), NOW())'
        )->execute([$businessId, (int) $user['id'], $now, $openingCash]);

        $id = (int) $this->pdo->lastInsertId();
        $shift = $this->shifts->findShift($id, $businessId);

        return ApiResponse::success($this->shifts->enrichShift($shift), [], 201);
    }

    public function close(Request $request, Response $response, array $args): Response
    {
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');
        $businessId = (int) $user['business_id'];
        $shiftId = (int) $args['id'];

        if (!$this->validateAmount($body, 'closing_cash', allowZero: true)) {
            return ApiResponse::error('Sayılan kassa məbləği düzgün deyil', 422);
        }

        $shift = $this->shifts->findShift($shiftId, $businessId);
        if (!$shift || $shift['status'] !== 'open') {
            return ApiResponse::error('Açıq növbə tapılmadı', 404);
        }

        $totals = $this->shifts->liveTotals($shift);
        $closingCash = round((float) $body['closing_cash'], 2);
        $expected = $totals['expected_cash'];
        $difference = round($closingCash - $expected, 2);
        $now = $this->clock->now();
        $notes = trim((string) ($body['notes'] ?? ''));

        $this->pdo->prepare(
            'UPDATE shifts SET status = \'closed\', closed_by = ?, closed_at = ?,
             closing_cash = ?, expected_cash = ?, cash_difference = ?,
             cash_sales = ?, card_sales = ?, notes = ?, updated_at = NOW()
             WHERE id = ?'
        )->execute([
            (int) $user['id'],
            $now,
            $closingCash,
            $expected,
            $difference,
            $totals['cash_sales'],
            $totals['card_sales'],
            $notes !== '' ? $notes : null,
            $shiftId,
        ]);

        $closed = $this->shifts->findShift($shiftId, $businessId);
        $closed['movements'] = $this->shifts->getMovements($shiftId);
        $closed['totals'] = $totals;
        $closed['summary'] = [
            'opening_cash' => (float) $shift['opening_cash'],
            'closing_cash' => $closingCash,
            'expected_cash' => $expected,
            'cash_difference' => $difference,
            'cash_sales' => $totals['cash_sales'],
            'card_sales' => $totals['card_sales'],
            'expenses' => $totals['expenses'],
            'owner_withdrawals' => $totals['owner_withdrawals'],
            'pay_ins' => $totals['pay_ins'],
        ];

        return ApiResponse::success($closed);
    }

    public function addMovement(Request $request, Response $response, array $args): Response
    {
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');
        $businessId = (int) $user['business_id'];
        $shiftId = (int) $args['id'];

        $shift = $this->shifts->findShift($shiftId, $businessId);
        if (!$shift || $shift['status'] !== 'open') {
            return ApiResponse::error('Açıq növbə tapılmadı', 404);
        }

        return $this->storeMovement($body, $user, $businessId, $shiftId, 'cashier');
    }

    public function adminExpense(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');
        $businessId = (int) $user['business_id'];

        $shiftId = isset($body['shift_id']) ? (int) $body['shift_id'] : null;
        if ($shiftId) {
            $shift = $this->shifts->findShift($shiftId, $businessId);
            if (!$shift) {
                return ApiResponse::error('Növbə tapılmadı', 404);
            }
        } else {
            $open = $this->shifts->getOpenShift($businessId);
            $shiftId = $open ? (int) $open['id'] : null;
        }

        return $this->storeMovement($body, $user, $businessId, $shiftId, 'admin');
    }

    public function index(Request $request, Response $response): Response
    {
        $user = $request->getAttribute('user');
        $businessId = (int) $user['business_id'];
        $params = $request->getQueryParams();
        $status = $params['status'] ?? null;
        $from = $params['from'] ?? date('Y-m-d', strtotime('-30 days'));
        $to = $params['to'] ?? date('Y-m-d');
        $limit = min(100, max(10, (int) ($params['limit'] ?? 50)));

        $sql = 'SELECT s.*, ou.full_name AS opened_by_name, cu.full_name AS closed_by_name
                FROM shifts s
                JOIN users ou ON ou.id = s.opened_by
                LEFT JOIN users cu ON cu.id = s.closed_by
                WHERE s.business_id = ?
                  AND DATE(s.opened_at) BETWEEN ? AND ?';
        $bind = [$businessId, $from, $to];

        if ($status && in_array($status, ['open', 'closed'], true)) {
            $sql .= ' AND s.status = ?';
            $bind[] = $status;
        }

        $sql .= ' ORDER BY s.opened_at DESC LIMIT ' . $limit;

        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($bind);
        $rows = $stmt->fetchAll();

        foreach ($rows as &$row) {
            if ($row['status'] === 'open') {
                $row['totals'] = $this->shifts->liveTotals($row);
            } else {
                $row['totals'] = [
                    'cash_sales' => (float) $row['cash_sales'],
                    'card_sales' => (float) $row['card_sales'],
                    'expected_cash' => (float) $row['expected_cash'],
                ];
            }
        }

        return ApiResponse::success($rows);
    }

    public function show(Request $request, Response $response, array $args): Response
    {
        $user = $request->getAttribute('user');
        $businessId = (int) $user['business_id'];
        $shift = $this->shifts->findShift((int) $args['id'], $businessId);

        if (!$shift) {
            return ApiResponse::error('Növbə tapılmadı', 404);
        }

        $shift['movements'] = $this->shifts->getMovements((int) $shift['id']);
        if ($shift['status'] === 'open') {
            $shift['totals'] = $this->shifts->liveTotals($shift);
        } else {
            $shift['totals'] = [
                'cash_sales' => (float) $shift['cash_sales'],
                'card_sales' => (float) $shift['card_sales'],
                'expected_cash' => (float) $shift['expected_cash'],
                'cash_difference' => (float) $shift['cash_difference'],
            ];
        }

        return ApiResponse::success($shift);
    }

    public function movements(Request $request, Response $response): Response
    {
        $user = $request->getAttribute('user');
        $businessId = (int) $user['business_id'];
        $params = $request->getQueryParams();
        $from = $params['from'] ?? date('Y-m-d', strtotime('-30 days'));
        $to = $params['to'] ?? date('Y-m-d');
        $limit = min(200, max(20, (int) ($params['limit'] ?? 100)));

        $stmt = $this->pdo->prepare(
            'SELECT cm.*, u.full_name AS created_by_name,
                    s.opened_at AS shift_opened_at, s.status AS shift_status
             FROM cash_movements cm
             LEFT JOIN users u ON u.id = cm.created_by
             LEFT JOIN shifts s ON s.id = cm.shift_id
             WHERE cm.business_id = ?
               AND DATE(cm.created_at) BETWEEN ? AND ?
             ORDER BY cm.created_at DESC
             LIMIT ' . $limit
        );
        $stmt->execute([$businessId, $from, $to]);

        $rows = $stmt->fetchAll();
        foreach ($rows as &$row) {
            $row['category_label'] = $this->shifts->categoryLabel((string) $row['category']);
        }

        return ApiResponse::success($rows);
    }

    private function storeMovement(array $body, array $user, int $businessId, ?int $shiftId, string $source): Response
    {
        $validation = v::key('type', v::in(['expense', 'owner_withdrawal', 'pay_in']))
            ->key('amount', v::numericVal()->positive());
        if (!$validation->validate($body)) {
            return ApiResponse::error('Məlumatlar düzgün deyil', 422);
        }

        $type = (string) $body['type'];
        $amount = round((float) $body['amount'], 2);
        if ($amount <= 0) {
            return ApiResponse::error('Məbləğ sıfırdan böyük olmalıdır', 422);
        }

        $category = (string) ($body['category'] ?? '');
        if ($type === 'owner_withdrawal') {
            $category = 'sahibkar';
        } elseif ($type === 'pay_in') {
            $category = 'pay_in';
        } elseif ($category === '' || !isset(ShiftService::EXPENSE_CATEGORIES[$category])) {
            return ApiResponse::error('Xərc kateqoriyası seçilməlidir', 422);
        }

        if ($source === 'cashier' && $shiftId === null) {
            return ApiResponse::error('Açıq növbə tələb olunur', 409);
        }

        $description = trim((string) ($body['description'] ?? ''));

        $this->pdo->prepare(
            'INSERT INTO cash_movements (business_id, shift_id, type, category, amount, description, source, created_by, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())'
        )->execute([
            $businessId,
            $shiftId,
            $type,
            $category,
            $amount,
            $description !== '' ? $description : null,
            $source,
            (int) $user['id'],
        ]);

        $payload = ['id' => (int) $this->pdo->lastInsertId()];
        if ($shiftId) {
            $shift = $this->shifts->findShift($shiftId, $businessId);
            $payload['shift'] = $this->shifts->enrichShift($shift);
        }

        return ApiResponse::success($payload, [], 201);
    }

    private function validateAmount(array $body, string $key, bool $allowZero = false): bool
    {
        if (!isset($body[$key]) || !is_numeric($body[$key])) {
            return false;
        }
        $val = (float) $body[$key];

        return $allowZero ? $val >= 0 : $val > 0;
    }

    public static function assertCashierHasOpenShift(ShiftService $shifts, array $user): ?Response
    {
        if ($user['role'] === 'admin') {
            return null;
        }

        $open = $shifts->getOpenShift((int) $user['business_id']);
        if (!$open) {
            return ApiResponse::error('Əvvəlcə günün növbəsini açın (kassa)', 403);
        }

        return null;
    }
}
