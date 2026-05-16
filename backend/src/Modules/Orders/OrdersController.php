<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Modules\Stock\StockController;
use App\Support\ApiResponse;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class OrdersController
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly StockController $stock
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
                WHERE s.status = 'closed' AND DATE(s.closed_at) BETWEEN ? AND ?";
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
        if (!$order) {
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
        if ($order['order_state'] === 'refunded') {
            return ApiResponse::error('Qaytarılmış sifariş düzəldilə bilməz', 400);
        }

        $validation = v::key('total_amount', v::numericVal());
        if (!$validation->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $timeCharge = (float) ($body['time_charge'] ?? $order['time_charge']);
        $productsTotal = (float) ($body['products_total'] ?? $order['products_total']);
        $discount = (float) ($body['discount'] ?? $order['discount']);
        $total = round((float) $body['total_amount'], 2);

        $expected = round($timeCharge + $productsTotal - $discount, 2);
        if (abs($expected - $total) > 0.05) {
            return ApiResponse::error('Total does not match time + products - discount', 422);
        }

        $note = trim((string) ($body['admin_note'] ?? $order['admin_note'] ?? ''));

        $this->pdo->beginTransaction();
        try {
            $this->pdo->prepare(
                'UPDATE sessions SET time_charge = ?, products_total = ?, discount = ?, total_amount = ?,
                 order_state = \'adjusted\', admin_note = ?, adjusted_by = ?, adjusted_at = NOW(), updated_at = NOW()
                 WHERE id = ?'
            )->execute([$timeCharge, $productsTotal, $discount, $total, $note ?: null, (int) $user['id'], $id]);

            $method = $body['payment_method'] ?? null;
            if ($method && in_array($method, ['cash', 'card', 'mixed'], true)) {
                $cash = (float) ($body['cash_amount'] ?? 0);
                $card = (float) ($body['card_amount'] ?? 0);
                if ($method === 'cash') {
                    $cash = $total;
                    $card = 0;
                } elseif ($method === 'card') {
                    $cash = 0;
                    $card = $total;
                }
                $this->pdo->prepare(
                    'UPDATE payments SET method = ?, cash_amount = ?, card_amount = ?, total_amount = ? WHERE session_id = ?'
                )->execute([$method, $cash, $card, $total, $id]);
            } else {
                $this->pdo->prepare('UPDATE payments SET total_amount = ? WHERE session_id = ?')
                    ->execute([$total, $id]);
            }

            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            throw $e;
        }

        return ApiResponse::success($this->fetchOrderDetail($id));
    }

    public function refund(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');

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

        $restoreStock = !empty($body['restore_stock']);
        $note = trim((string) ($body['admin_note'] ?? ''));
        $adminNote = $note !== '' ? $note : ($order['admin_note'] ?? '');

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

            $this->pdo->prepare(
                'UPDATE sessions SET order_state = \'refunded\', refund_amount = ?, admin_note = ?, updated_at = NOW() WHERE id = ?'
            )->execute([$refundAmount, $adminNote ?: null, $id]);

            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            return ApiResponse::error($e->getMessage(), 400);
        }

        return ApiResponse::success($this->fetchOrderDetail($id));
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
