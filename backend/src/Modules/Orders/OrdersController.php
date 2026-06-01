<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Modules\Shifts\ShiftService;
use App\Modules\Stock\StockController;
use App\Support\ApiResponse;
use App\Support\DiscountCalculator;
use App\Support\SchemaMigrator;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class OrdersController
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly StockController $stock,
        private readonly ShiftService $shifts
    ) {
    }

    public function index(Request $request, Response $response): Response
    {
        $params = $request->getQueryParams();
        $from = $params['from'] ?? date('Y-m-d');
        $to = $params['to'] ?? date('Y-m-d');
        $state = $params['order_state'] ?? null;
        $limit = min(200, max(1, (int) ($params['limit'] ?? 100)));

        $sql = "SELECT s.id, s.session_type, s.table_id, s.status, s.order_state, s.opened_at, s.closed_at,
                       s.time_charge, s.products_total, s.discount, s.total_amount, s.refund_amount, s.admin_note,
                       s.active_seconds, s.hourly_rate_snapshot, s.discount_type, s.discount_value,
                       t.name AS table_name, c.name AS customer_name,
                       p.method AS payment_method, p.cash_amount, p.card_amount,
                       u.username AS closed_by_name, r.receipt_number
                FROM sessions s
                LEFT JOIN tables t ON t.id = s.table_id
                LEFT JOIN customers c ON c.id = s.customer_id
                LEFT JOIN payments p ON p.session_id = s.id
                LEFT JOIN users u ON u.id = s.closed_by
                LEFT JOIN receipts r ON r.session_id = s.id
                WHERE s.status = 'closed' AND s.order_state != 'deleted'
                  AND DATE(s.closed_at) BETWEEN ? AND ?";
        $bind = [$from, $to];

        if ($state && in_array($state, ['paid', 'refunded', 'adjusted'], true)) {
            $sql .= ' AND s.order_state = ?';
            $bind[] = $state;
        }

        $sql .= ' ORDER BY s.closed_at DESC LIMIT ' . $limit;

        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($bind);

        return ApiResponse::success($stmt->fetchAll());
    }

    public function show(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $order = $this->fetchOrder($id);
        if (!$order || $order['order_state'] === 'deleted') {
            return ApiResponse::error('Order not found', 404);
        }

        $items = $this->pdo->prepare('SELECT * FROM session_items WHERE session_id = ? ORDER BY id');
        $items->execute([$id]);

        $payment = $this->pdo->prepare('SELECT * FROM payments WHERE session_id = ? LIMIT 1');
        $payment->execute([$id]);

        $receipt = $this->pdo->prepare('SELECT receipt_number, created_at FROM receipts WHERE session_id = ? LIMIT 1');
        $receipt->execute([$id]);

        $order['items'] = $items->fetchAll();
        $order['payment'] = $payment->fetch() ?: null;
        $order['receipt'] = $receipt->fetch() ?: null;

        return ApiResponse::success($order);
    }

    public function adjust(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');

        $order = $this->fetchOrder($id);
        if (!$order || $order['status'] !== 'closed') {
            return ApiResponse::error('Order not found', 404);
        }
        if (in_array($order['order_state'], ['refunded', 'deleted'], true)) {
            return ApiResponse::error('Qaytarılmış və ya silinmiş sifariş düzəldilə bilməz', 400);
        }

        $validation = v::key('total_amount', v::numericVal());
        if (!$validation->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $timeCharge = (float) ($body['time_charge'] ?? $order['time_charge']);
        $productsTotal = (float) ($body['products_total'] ?? $order['products_total']);
        $appliesTo = $body['discount_applies_to'] ?? $order['discount_applies_to'] ?? 'time_only';
        if (!in_array($appliesTo, ['all', 'time_only'], true)) {
            $appliesTo = 'time_only';
        }

        $discountType = $body['discount_type'] ?? $order['discount_type'] ?? 'none';
        $discountValue = (float) ($body['discount_value'] ?? $order['discount_value'] ?? 0);
        $base = $appliesTo === 'time_only' ? $timeCharge : ($timeCharge + $productsTotal);

        if ($discountType === 'percent') {
            $discount = DiscountCalculator::amount($base, 'percent', $discountValue);
        } elseif ($discountType === 'fixed') {
            $discount = DiscountCalculator::amount($base, 'fixed', $discountValue);
        } else {
            $discount = (float) ($body['discount'] ?? $order['discount'] ?? 0);
            $discount = min(max(0, $discount), $timeCharge + $productsTotal);
        }

        $discount = round($discount, 2);
        $expected = round($timeCharge + $productsTotal - $discount, 2);
        $total = round((float) ($body['total_amount'] ?? $expected), 2);

        if (abs($expected - $total) > 0.05) {
            return ApiResponse::error('Ümumi məbləğ düzgün deyil: vaxt + məhsul − endirim = ' . number_format($expected, 2), 422);
        }

        if ($discount <= 0) {
            $discountType = 'none';
            $discountValue = 0;
        } elseif ($discountType === 'none') {
            $discountType = 'fixed';
            $discountValue = $discount;
        }

        $note = trim((string) ($body['admin_note'] ?? $order['admin_note'] ?? ''));
        $oldTotal = round((float) $order['total_amount'], 2);

        $paymentStmt = $this->pdo->prepare('SELECT * FROM payments WHERE session_id = ? LIMIT 1');
        $paymentStmt->execute([$id]);
        $payment = $paymentStmt->fetch();
        if (!$payment) {
            return ApiResponse::error('Payment not found for this order', 404);
        }

        $businessId = (int) $user['business_id'];
        $openShift = $this->shifts->getOpenShift($businessId);
        $closedAt = (string) ($order['closed_at'] ?? '');
        $inCurrentShiftWindow = $openShift !== null
            && $closedAt !== ''
            && RefundCalculator::sessionInShiftWindow($closedAt, $openShift);

        $rescaled = RefundCalculator::rescalePayment($total, $payment);
        $shiftMovementId = null;

        $this->pdo->beginTransaction();
        try {
            $this->pdo->prepare(
                'UPDATE sessions SET time_charge = ?, products_total = ?, discount = ?, discount_type = ?, discount_value = ?, discount_applies_to = ?, total_amount = ?,
                 order_state = \'adjusted\', admin_note = ?, adjusted_by = ?, adjusted_at = NOW(), updated_at = NOW()
                 WHERE id = ?'
            )->execute([
                $timeCharge,
                $productsTotal,
                $discount,
                $discountType,
                $discountValue,
                $appliesTo,
                $total,
                $note ?: null,
                (int) $user['id'],
                $id,
            ]);

            $shiftIdForPayment = $inCurrentShiftWindow && $openShift !== null
                ? (int) $openShift['id']
                : null;

            $this->pdo->prepare(
                'UPDATE payments SET method = ?, cash_amount = ?, card_amount = ?, total_amount = ?,
                 shift_id = COALESCE(?, shift_id)
                 WHERE session_id = ?'
            )->execute([
                $rescaled['method'],
                $rescaled['cash_amount'],
                $rescaled['card_amount'],
                $rescaled['total_amount'],
                $shiftIdForPayment,
                $id,
            ]);

            $delta = round($total - $oldTotal, 2);
            if (abs($delta) >= 0.01 && $openShift !== null && !$inCurrentShiftWindow) {
                $split = RefundCalculator::splitRefund(abs($delta), $payment);
                if ($delta < 0 && $split['cash_refund'] > 0) {
                    $this->pdo->prepare(
                        'INSERT INTO cash_movements (business_id, shift_id, type, category, amount, description, source, created_by, created_at)
                         VALUES (?, ?, \'refund\', \'sale_adjust\', ?, ?, \'admin\', ?, NOW())'
                    )->execute([
                        $businessId,
                        (int) $openShift['id'],
                        $split['cash_refund'],
                        'Sifariş düzəlişi #' . $id . ' (azaldıldı)',
                        (int) $user['id'],
                    ]);
                    $shiftMovementId = (int) $this->pdo->lastInsertId();
                } elseif ($delta > 0 && $split['cash_refund'] > 0) {
                    $this->pdo->prepare(
                        'INSERT INTO cash_movements (business_id, shift_id, type, category, amount, description, source, created_by, created_at)
                         VALUES (?, ?, \'pay_in\', \'sale_adjust\', ?, ?, \'admin\', ?, NOW())'
                    )->execute([
                        $businessId,
                        (int) $openShift['id'],
                        $split['cash_refund'],
                        'Sifariş düzəlişi #' . $id . ' (artırıldı)',
                        (int) $user['id'],
                    ]);
                    $shiftMovementId = (int) $this->pdo->lastInsertId();
                }
            }

            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            throw $e;
        }

        $detail = $this->fetchOrderDetail($id);
        $detail['adjust_summary'] = [
            'previous_total' => $oldTotal,
            'new_total' => $total,
            'delta' => round($total - $oldTotal, 2),
            'cash_amount' => $rescaled['cash_amount'],
            'card_amount' => $rescaled['card_amount'],
            'in_current_shift' => $inCurrentShiftWindow,
            'shift_movement_id' => $shiftMovementId,
        ];

        return ApiResponse::success($detail);
    }

    public function refund(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');
        $businessId = (int) $user['business_id'];

        $order = $this->fetchOrder($id);
        if (!$order || $order['status'] !== 'closed') {
            return ApiResponse::error('Order not found', 404);
        }
        if ($order['order_state'] === 'refunded') {
            return ApiResponse::error('Already refunded', 400);
        }

        $total = (float) $order['total_amount'];
        $refundAmount = isset($body['amount']) ? round((float) $body['amount'], 2) : $total;
        if ($refundAmount <= 0 || $refundAmount > $total) {
            return ApiResponse::error('Invalid refund amount', 422);
        }

        $paymentStmt = $this->pdo->prepare('SELECT * FROM payments WHERE session_id = ? LIMIT 1');
        $paymentStmt->execute([$id]);
        $payment = $paymentStmt->fetch();
        if (!$payment) {
            return ApiResponse::error('Payment not found for this order', 404);
        }

        $split = RefundCalculator::splitRefund($refundAmount, $payment);
        $cashRefund = $split['cash_refund'];
        $cardRefund = $split['card_refund'];

        $openShift = $this->shifts->getOpenShift($businessId);
        $closedAt = (string) ($order['closed_at'] ?? '');
        $inCurrentShiftWindow = $openShift !== null
            && $closedAt !== ''
            && RefundCalculator::sessionInShiftWindow($closedAt, $openShift);

        if ($cashRefund > 0 && $openShift === null) {
            return ApiResponse::error('Nağd qaytarma üçün açıq növbə lazımdır', 409);
        }

        $restoreStock = !empty($body['restore_stock']);
        $note = trim((string) ($body['admin_note'] ?? ''));
        $adminNote = $note !== '' ? $note : ($order['admin_note'] ?? '');

        $shiftMovementId = null;

        $this->pdo->beginTransaction();
        try {
            if ($restoreStock) {
                $items = $this->pdo->prepare('SELECT * FROM session_items WHERE session_id = ?');
                $items->execute([$id]);
                foreach ($items->fetchAll() as $item) {
                    $qty = (int) $item['quantity'];
                    if ($qty > 0) {
                        $this->stock->applyStockChange(
                            (int) $item['product_id'],
                            'in',
                            $qty,
                            'return',
                            'refund',
                            $id,
                            (int) $user['id'],
                            'Refund session #' . $id
                        );
                    }
                }
            }

            $newCash = round((float) $payment['cash_amount'] - $cashRefund, 2);
            $newCard = round((float) $payment['card_amount'] - $cardRefund, 2);
            $newTotal = round((float) $payment['total_amount'] - $refundAmount, 2);
            if ($newCash < -0.01 || $newCard < -0.01 || $newTotal < -0.01) {
                throw new \RuntimeException('Refund exceeds payment amounts');
            }
            $newCash = max(0, $newCash);
            $newCard = max(0, $newCard);
            $newTotal = max(0, $newTotal);

            $this->pdo->prepare(
                'UPDATE payments SET cash_amount = ?, card_amount = ?, total_amount = ? WHERE session_id = ?'
            )->execute([$newCash, $newCard, $newTotal, $id]);

            if ($cashRefund > 0 && !$inCurrentShiftWindow && $openShift !== null) {
                $this->pdo->prepare(
                    'INSERT INTO cash_movements (business_id, shift_id, type, category, amount, description, source, created_by, created_at)
                     VALUES (?, ?, \'refund\', \'sale_refund\', ?, ?, \'admin\', ?, NOW())'
                )->execute([
                    $businessId,
                    (int) $openShift['id'],
                    $cashRefund,
                    'Satış qaytarması #' . $id,
                    (int) $user['id'],
                ]);
                $shiftMovementId = (int) $this->pdo->lastInsertId();
            }

            if ($refundAmount >= $total - 0.01 && !empty($order['coupon_id'])) {
                $couponId = (int) $order['coupon_id'];
                $this->pdo->prepare('DELETE FROM coupon_redemptions WHERE session_id = ?')->execute([$id]);
                $this->pdo->prepare(
                    'UPDATE coupons SET used_count = GREATEST(0, used_count - 1), updated_at = NOW() WHERE id = ?'
                )->execute([$couponId]);
            }

            $this->pdo->prepare(
                'UPDATE sessions SET order_state = \'refunded\', refund_amount = ?, admin_note = ?, updated_at = NOW() WHERE id = ?'
            )->execute([$refundAmount, $adminNote ?: null, $id]);

            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            return ApiResponse::error($e->getMessage(), 400);
        }

        $detail = $this->fetchOrderDetail($id);
        $detail['refund_summary'] = [
            'refund_amount' => $refundAmount,
            'cash_refunded' => $cashRefund,
            'card_refunded' => $cardRefund,
            'shift_movement_id' => $shiftMovementId,
            'applied_to_current_shift' => $cashRefund > 0 && !$inCurrentShiftWindow && $shiftMovementId !== null,
        ];

        return ApiResponse::success($detail);
    }

    public function delete(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');
        $businessId = (int) $user['business_id'];

        $order = $this->fetchOrder($id);
        if (!$order || $order['status'] !== 'closed') {
            return ApiResponse::error('Order not found', 404);
        }
        if ($order['order_state'] === 'deleted') {
            return ApiResponse::error('Sifariş artıq silinib', 400);
        }
        if ($order['order_state'] === 'refunded') {
            return ApiResponse::error('Qaytarılmış sifariş silinə bilməz', 400);
        }

        $paymentStmt = $this->pdo->prepare('SELECT * FROM payments WHERE session_id = ? LIMIT 1');
        $paymentStmt->execute([$id]);
        $payment = $paymentStmt->fetch();
        if (!$payment) {
            return ApiResponse::error('Payment not found for this order', 404);
        }

        $total = round((float) $order['total_amount'], 2);
        $split = RefundCalculator::splitRefund($total, $payment);
        $cashRefund = $split['cash_refund'];
        $cardRefund = $split['card_refund'];

        $openShift = $this->shifts->getOpenShift($businessId);
        $closedAt = (string) ($order['closed_at'] ?? '');
        $inCurrentShiftWindow = $openShift !== null
            && $closedAt !== ''
            && RefundCalculator::sessionInShiftWindow($closedAt, $openShift);

        $restoreStock = !array_key_exists('restore_stock', $body) || !empty($body['restore_stock']);
        $note = trim((string) ($body['admin_note'] ?? ''));
        $adminNote = $note !== '' ? $note : ($order['admin_note'] ?? '');

        $shiftMovementId = null;

        $this->pdo->beginTransaction();
        try {
            if ($restoreStock) {
                $items = $this->pdo->prepare('SELECT * FROM session_items WHERE session_id = ?');
                $items->execute([$id]);
                foreach ($items->fetchAll() as $item) {
                    if (!empty($item['is_set_item'])) {
                        continue;
                    }
                    $productId = (int) ($item['product_id'] ?? 0);
                    $qty = (int) $item['quantity'];
                    if ($productId > 0 && $qty > 0) {
                        $this->stock->applyStockChange(
                            $productId,
                            'in',
                            $qty,
                            'in',
                            'order_delete',
                            $id,
                            (int) $user['id'],
                            'Deleted order #' . $id
                        );
                    }
                }
            }

            $adminLabel = trim((string) ($user['full_name'] ?? $user['username'] ?? 'Admin'));

            if ($cashRefund > 0 && !$inCurrentShiftWindow && $openShift !== null) {
                $this->pdo->prepare(
                    'INSERT INTO cash_movements (business_id, shift_id, type, category, amount, description, source, created_by, created_at)
                     VALUES (?, ?, \'refund\', \'sale_refund\', ?, ?, \'admin\', ?, NOW())'
                )->execute([
                    $businessId,
                    (int) $openShift['id'],
                    $cashRefund,
                    'Admin ' . $adminLabel . ' sildi: sifariş #' . $id,
                    (int) $user['id'],
                ]);
                $shiftMovementId = (int) $this->pdo->lastInsertId();
            }

            if (!empty($order['coupon_id'])) {
                $couponId = (int) $order['coupon_id'];
                $this->pdo->prepare('DELETE FROM coupon_redemptions WHERE session_id = ?')->execute([$id]);
                $this->pdo->prepare(
                    'UPDATE coupons SET used_count = GREATEST(0, used_count - 1), updated_at = NOW() WHERE id = ?'
                )->execute([$couponId]);
            }

            $hasPreDeleteCols = SchemaMigrator::columnExists($this->pdo, 'payments', 'pre_delete_cash');
            if ($hasPreDeleteCols) {
                $this->pdo->prepare(
                    'UPDATE payments SET pre_delete_cash = cash_amount, pre_delete_card = card_amount, pre_delete_total = total_amount,
                     cash_amount = 0, card_amount = 0, total_amount = 0
                     WHERE session_id = ?'
                )->execute([$id]);
            } else {
                $this->pdo->prepare(
                    'UPDATE payments SET cash_amount = 0, card_amount = 0, total_amount = 0 WHERE session_id = ?'
                )->execute([$id]);
            }

            $sessionUpdate = 'UPDATE sessions SET order_state = \'deleted\', admin_note = ?, updated_at = NOW() WHERE id = ?';
            $sessionParams = [$adminNote ?: null, $id];
            if (SchemaMigrator::columnExists($this->pdo, 'sessions', 'deleted_by')) {
                $sessionUpdate = 'UPDATE sessions SET order_state = \'deleted\', admin_note = ?, deleted_by = ?, deleted_at = NOW(), updated_at = NOW() WHERE id = ?';
                $sessionParams = [$adminNote ?: null, (int) $user['id'], $id];
            }
            $this->pdo->prepare($sessionUpdate)->execute($sessionParams);

            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            return ApiResponse::error($e->getMessage(), 400);
        }

        return ApiResponse::success([
            'deleted' => true,
            'session_id' => $id,
            'delete_summary' => [
                'total_removed' => $total,
                'cash_removed' => $cashRefund,
                'card_removed' => $cardRefund,
                'stock_restored' => $restoreStock,
                'shift_movement_id' => $shiftMovementId,
                'removed_from_current_shift' => $inCurrentShiftWindow,
            ],
        ]);
    }

    private function fetchOrder(int $id): ?array
    {
        $stmt = $this->pdo->prepare(
            'SELECT s.*, t.name AS table_name, c.name AS customer_name
             FROM sessions s
             LEFT JOIN tables t ON t.id = s.table_id
             LEFT JOIN customers c ON c.id = s.customer_id
             WHERE s.id = ?'
        );
        $stmt->execute([$id]);
        $row = $stmt->fetch();

        return $row ?: null;
    }

    private function fetchOrderDetail(int $id): array
    {
        $order = $this->fetchOrder($id);
        $items = $this->pdo->prepare('SELECT * FROM session_items WHERE session_id = ? ORDER BY id');
        $items->execute([$id]);
        $payment = $this->pdo->prepare('SELECT * FROM payments WHERE session_id = ? LIMIT 1');
        $payment->execute([$id]);
        $receipt = $this->pdo->prepare('SELECT receipt_number, created_at FROM receipts WHERE session_id = ? LIMIT 1');
        $receipt->execute([$id]);

        $order['items'] = $items->fetchAll();
        $order['payment'] = $payment->fetch() ?: null;
        $order['receipt'] = $receipt->fetch() ?: null;

        return $order;
    }
}
