<?php

declare(strict_types=1);

namespace App\Modules\Products;

use App\Modules\Stock\StockController;
use App\Support\ApiResponse;
use App\Support\StockMovementLabels;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class ProductsController
{
    private const CLOSED_ORDER_WHERE = "s.status = 'closed' AND s.order_state NOT IN ('deleted', 'refunded')";

    public function __construct(
        private readonly PDO $pdo,
        private readonly StockController $stock,
    ) {
    }

    public function indexCategories(Request $request, Response $response): Response
    {
        $stmt = $this->pdo->query(
            'SELECT pc.*, COUNT(p.id) AS product_count
             FROM product_categories pc
             LEFT JOIN products p ON p.category_id = pc.id AND p.is_active = 1
             GROUP BY pc.id
             ORDER BY pc.sort_order, pc.name, pc.id'
        );

        return ApiResponse::success($stmt->fetchAll());
    }

    public function storeCategory(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        $name = trim((string) ($body['name'] ?? ''));
        if ($name === '') {
            return ApiResponse::error('Kateqoriya adı boş ola bilməz', 422);
        }

        $dup = $this->pdo->prepare('SELECT id FROM product_categories WHERE business_id = 1 AND LOWER(name) = LOWER(?)');
        $dup->execute([$name]);
        if ($dup->fetch()) {
            return ApiResponse::error('Bu adlı kateqoriya artıq var', 409);
        }

        $this->pdo->prepare(
            'INSERT INTO product_categories (business_id, name, sort_order, created_at, updated_at) VALUES (1, ?, ?, NOW(), NOW())'
        )->execute([$name, (int) ($body['sort_order'] ?? 0)]);

        $id = (int) $this->pdo->lastInsertId();

        return ApiResponse::success($this->findCategory($id), [], 201);
    }

    public function updateCategory(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $category = $this->findCategory($id);
        if (!$category) {
            return ApiResponse::error('Kateqoriya tapılmadı', 404);
        }

        $body = (array) $request->getParsedBody();
        $fields = [];
        $params = [];

        if (array_key_exists('name', $body)) {
            $name = trim((string) $body['name']);
            if ($name === '') {
                return ApiResponse::error('Kateqoriya adı boş ola bilməz', 422);
            }
            $dup = $this->pdo->prepare(
                'SELECT id FROM product_categories WHERE business_id = 1 AND LOWER(name) = LOWER(?) AND id != ?'
            );
            $dup->execute([$name, $id]);
            if ($dup->fetch()) {
                return ApiResponse::error('Bu adlı kateqoriya artıq var', 409);
            }
            $fields[] = 'name = ?';
            $params[] = $name;
        }

        if (array_key_exists('sort_order', $body)) {
            $fields[] = 'sort_order = ?';
            $params[] = (int) $body['sort_order'];
        }

        if ($fields === []) {
            return ApiResponse::error('Yenilənəcək sahə yoxdur', 422);
        }

        $fields[] = 'updated_at = NOW()';
        $params[] = $id;
        $this->pdo->prepare('UPDATE product_categories SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);

        return ApiResponse::success($this->findCategory($id));
    }

    public function destroyCategory(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        if (!$this->findCategory($id)) {
            return ApiResponse::error('Kateqoriya tapılmadı', 404);
        }

        $count = $this->pdo->prepare('SELECT COUNT(*) FROM products WHERE category_id = ? AND is_active = 1');
        $count->execute([$id]);
        if ((int) $count->fetchColumn() > 0) {
            return ApiResponse::error('Kateqoriyada məhsul var — əvvəlcə məhsulları başqa kateqoriyaya köçürün', 409);
        }

        $this->pdo->prepare('DELETE FROM product_categories WHERE id = ?')->execute([$id]);

        return ApiResponse::success(['deleted' => true]);
    }

    private function findCategory(int $id): ?array
    {
        $stmt = $this->pdo->prepare(
            'SELECT pc.*, COUNT(p.id) AS product_count
             FROM product_categories pc
             LEFT JOIN products p ON p.category_id = pc.id AND p.is_active = 1
             WHERE pc.id = ?
             GROUP BY pc.id'
        );
        $stmt->execute([$id]);

        return $stmt->fetch() ?: null;
    }

    public function index(Request $request, Response $response): Response
    {
        $stmt = $this->pdo->query(
            'SELECT p.*, ps.quantity AS stock_quantity, pc.name AS category_name
             FROM products p
             LEFT JOIN product_stock ps ON ps.product_id = p.id
             LEFT JOIN product_categories pc ON pc.id = p.category_id
             WHERE p.is_active = 1
             ORDER BY p.name'
        );
        return ApiResponse::success($stmt->fetchAll());
    }

    public function show(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $params = $request->getQueryParams();
        $from = $params['from'] ?? date('Y-m-d', strtotime('-30 days'));
        $to = $params['to'] ?? date('Y-m-d');
        if ($from > $to) {
            [$from, $to] = [$to, $from];
        }

        $product = $this->findProduct($id);
        if (!$product) {
            return ApiResponse::error('Məhsul tapılmadı', 404);
        }

        $currentStock = (int) ($product['stock_quantity'] ?? 0);

        $periodStats = $this->fetchPeriodMovementStats($id, $from, $to);
        $reserved = $this->fetchReservedInOpenSessions($id);
        $orderStats = $this->fetchOrderStats($id, $from, $to);
        $dailySales = $this->fetchDailySales($id, $from, $to);
        $hourlySales = $from === $to ? $this->fetchHourlySales($id, $from) : [];
        $salesLines = $this->fetchSalesLines($id, $from, $to);
        $movements = $this->fetchMovementsWithBalance($id);

        $ledgerCount = count($movements);
        $expectedStock = $ledgerCount > 0 ? (int) $movements[0]['balance_after'] : null;
        $matchesCurrent = $ledgerCount === 0 || $expectedStock === $currentStock;

        return ApiResponse::success([
            'product' => $product,
            'period' => ['from' => $from, 'to' => $to],
            'stats' => [
                'stock_in' => $periodStats['stock_in'],
                'stock_out' => $periodStats['stock_out'],
                'sold_qty' => $periodStats['sold_qty'],
                'returned_qty' => $periodStats['returned_qty'],
                'adjusted_qty' => $periodStats['adjusted_qty'],
                'current_stock' => $currentStock,
                'reserved_in_open_sessions' => $reserved,
                'sold_in_orders_qty' => $orderStats['qty'],
                'sold_revenue' => $orderStats['revenue'],
                'order_lines_count' => $orderStats['lines'],
            ],
            'reconciliation' => [
                'expected_stock_from_ledger' => $expectedStock ?? $currentStock,
                'matches_current' => $matchesCurrent,
                'ledger_entries' => $ledgerCount,
                'initial_stock_without_ledger' => $ledgerCount === 0 && $currentStock > 0,
                'ledger_gap' => ($expectedStock !== null && !$matchesCurrent)
                    ? $currentStock - $expectedStock
                    : 0,
            ],
            'daily_sales' => $dailySales,
            'hourly_sales' => $hourlySales,
            'sales_lines' => $salesLines,
            'movements' => $movements,
        ]);
    }

    public function store(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        $validation = v::key('name', v::stringType()->notEmpty())->key('price', v::numericVal());
        if (!$validation->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $this->pdo->beginTransaction();
        try {
            $this->pdo->prepare(
                'INSERT INTO products (business_id, category_id, name, sku, image_url, price, is_active, created_at, updated_at)
                 VALUES (1, ?, ?, ?, NULL, ?, 1, NOW(), NOW())'
            )->execute([
                $body['category_id'] ?? null,
                $body['name'],
                $body['sku'] ?? null,
                (float) $body['price'],
            ]);
            $productId = (int) $this->pdo->lastInsertId();
            $qty = max(0, (int) ($body['initial_stock'] ?? 0));
            $this->pdo->prepare(
                'INSERT INTO product_stock (product_id, quantity, created_at, updated_at) VALUES (?, 0, NOW(), NOW())'
            )->execute([$productId]);
            if ($qty > 0) {
                $user = $request->getAttribute('user');
                $actor = StockMovementLabels::actorLabel($user['full_name'] ?? null, $user['username'] ?? null);
                $this->stock->applyStockChange(
                    $productId,
                    'in',
                    $qty,
                    'in',
                    'product_create',
                    $productId,
                    (int) ($user['id'] ?? 0),
                    $actor . ': ilkin stok +' . $qty
                );
            }
            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            throw $e;
        }

        return ApiResponse::success(['id' => $productId], [], 201);
    }

    public function update(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');

        if (!$this->findProduct($id)) {
            return ApiResponse::error('Məhsul tapılmadı', 404);
        }

        $fields = [];
        $params = [];
        foreach (['name', 'sku', 'price', 'category_id', 'is_active'] as $key) {
            if (array_key_exists($key, $body)) {
                $fields[] = "{$key} = ?";
                $params[] = $body[$key];
            }
        }
        $hasStock = array_key_exists('stock_quantity', $body);
        if ($fields === [] && !$hasStock) {
            return ApiResponse::error('No fields', 422);
        }

        $this->pdo->beginTransaction();
        try {
            if ($hasStock) {
                $qty = max(0, (int) $body['stock_quantity']);
                $stock = $this->pdo->prepare('SELECT quantity FROM product_stock WHERE product_id = ? FOR UPDATE');
                $stock->execute([$id]);
                $row = $stock->fetch();
                if (!$row) {
                    $this->pdo->prepare(
                        'INSERT INTO product_stock (product_id, quantity, created_at, updated_at) VALUES (?, 0, NOW(), NOW())'
                    )->execute([$id]);
                    $current = 0;
                } else {
                    $current = (int) $row['quantity'];
                }
                if ($current !== $qty) {
                    $actor = StockMovementLabels::actorLabel($user['full_name'] ?? null, $user['username'] ?? null);
                    $this->stock->applyStockChange(
                        $id,
                        'adjustment',
                        $qty,
                        'adjustment',
                        'product_edit',
                        $id,
                        (int) ($user['id'] ?? 0),
                        sprintf('%s: admin stok redaktəsi %d → %d', $actor, $current, $qty)
                    );
                }
            }

            $fields[] = 'updated_at = NOW()';
            $params[] = $id;
            if ($fields !== ['updated_at = NOW()']) {
                $this->pdo->prepare('UPDATE products SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);
            }

            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            return ApiResponse::error($e->getMessage(), 400);
        }

        $product = $this->findProduct($id);

        return ApiResponse::success($product ?: ['updated' => true]);
    }

    public function destroy(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        if (!$this->findProduct($id)) {
            return ApiResponse::error('Məhsul tapılmadı', 404);
        }

        $this->pdo->prepare('UPDATE products SET is_active = 0, updated_at = NOW() WHERE id = ?')->execute([$id]);

        return ApiResponse::success(['deleted' => true]);
    }

    private function findProduct(int $id): ?array
    {
        $stmt = $this->pdo->prepare(
            'SELECT p.*, ps.quantity AS stock_quantity, pc.name AS category_name
             FROM products p
             LEFT JOIN product_stock ps ON ps.product_id = p.id
             LEFT JOIN product_categories pc ON pc.id = p.category_id
             WHERE p.id = ? AND p.is_active = 1'
        );
        $stmt->execute([$id]);

        return $stmt->fetch() ?: null;
    }

    /** @return array{stock_in: int, stock_out: int, sold_qty: int, returned_qty: int, adjusted_qty: int} */
    private function fetchPeriodMovementStats(int $productId, string $from, string $to): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT type, reference_type, SUM(quantity) AS total, COUNT(*) AS cnt
             FROM stock_movements
             WHERE product_id = ? AND DATE(created_at) BETWEEN ? AND ?
             GROUP BY type, reference_type'
        );
        $stmt->execute([$productId, $from, $to]);

        $stats = [
            'stock_in' => 0,
            'stock_out' => 0,
            'sold_qty' => 0,
            'returned_qty' => 0,
            'adjusted_qty' => 0,
        ];

        foreach ($stmt->fetchAll() as $row) {
            $type = (string) $row['type'];
            $refType = $row['reference_type'] !== null ? (string) $row['reference_type'] : null;
            $total = (int) $row['total'];
            $cnt = (int) $row['cnt'];

            if ($type === 'in') {
                if ($refType === null) {
                    $stats['stock_in'] += $total;
                } else {
                    $stats['returned_qty'] += $total;
                }
            } elseif ($type === 'out') {
                $stats['stock_out'] += $total;
            } elseif ($type === 'sale') {
                $stats['sold_qty'] += $total;
            } elseif ($type === 'adjustment') {
                $stats['adjusted_qty'] += $cnt;
            }
        }

        return $stats;
    }

    private function fetchReservedInOpenSessions(int $productId): int
    {
        $stmt = $this->pdo->prepare(
            'SELECT COALESCE(SUM(si.quantity), 0) AS total
             FROM session_items si
             JOIN sessions s ON s.id = si.session_id
             WHERE si.product_id = ? AND si.is_set_item = 0
               AND s.status IN (\'active\', \'paused\')'
        );
        $stmt->execute([$productId]);

        return (int) ($stmt->fetchColumn() ?: 0);
    }

    /** @return array{qty: int, revenue: float, lines: int} */
    private function fetchOrderStats(int $productId, string $from, string $to): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT COALESCE(SUM(si.quantity), 0) AS qty,
                    COALESCE(SUM(si.quantity * si.unit_price), 0) AS revenue,
                    COUNT(*) AS line_count
             FROM session_items si
             JOIN sessions s ON s.id = si.session_id
             WHERE si.product_id = ? AND si.is_set_item = 0
               AND ' . self::CLOSED_ORDER_WHERE . '
               AND DATE(s.closed_at) BETWEEN ? AND ?'
        );
        $stmt->execute([$productId, $from, $to]);
        $row = $stmt->fetch() ?: [];

        return [
            'qty' => (int) ($row['qty'] ?? 0),
            'revenue' => (float) ($row['revenue'] ?? 0),
            'lines' => (int) ($row['line_count'] ?? 0),
        ];
    }

    /** @return list<array<string, mixed>> */
    private function fetchDailySales(int $productId, string $from, string $to): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT DATE(s.closed_at) AS date,
                    SUM(si.quantity) AS qty,
                    SUM(si.quantity * si.unit_price) AS revenue
             FROM session_items si
             JOIN sessions s ON s.id = si.session_id
             WHERE si.product_id = ? AND si.is_set_item = 0
               AND ' . self::CLOSED_ORDER_WHERE . '
               AND DATE(s.closed_at) BETWEEN ? AND ?
             GROUP BY DATE(s.closed_at)
             ORDER BY date DESC'
        );
        $stmt->execute([$productId, $from, $to]);

        return array_map(static fn (array $row): array => [
            'date' => (string) $row['date'],
            'qty' => (int) $row['qty'],
            'revenue' => (float) $row['revenue'],
        ], $stmt->fetchAll());
    }

    /** @return list<array<string, mixed>> */
    private function fetchHourlySales(int $productId, string $date): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT HOUR(s.closed_at) AS hour,
                    SUM(si.quantity) AS qty,
                    SUM(si.quantity * si.unit_price) AS revenue
             FROM session_items si
             JOIN sessions s ON s.id = si.session_id
             WHERE si.product_id = ? AND si.is_set_item = 0
               AND ' . self::CLOSED_ORDER_WHERE . '
               AND DATE(s.closed_at) = ?
             GROUP BY HOUR(s.closed_at)
             ORDER BY hour'
        );
        $stmt->execute([$productId, $date]);

        return array_map(static fn (array $row): array => [
            'hour' => (int) $row['hour'],
            'qty' => (int) $row['qty'],
            'revenue' => (float) $row['revenue'],
        ], $stmt->fetchAll());
    }

    /** @return list<array<string, mixed>> */
    private function fetchSalesLines(int $productId, string $from, string $to): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT si.session_id, s.closed_at, s.order_state, t.name AS table_name,
                    si.quantity AS qty, si.unit_price,
                    (si.quantity * si.unit_price) AS line_total
             FROM session_items si
             JOIN sessions s ON s.id = si.session_id
             LEFT JOIN tables t ON t.id = s.table_id
             WHERE si.product_id = ? AND si.is_set_item = 0
               AND ' . self::CLOSED_ORDER_WHERE . '
               AND DATE(s.closed_at) BETWEEN ? AND ?
             ORDER BY s.closed_at DESC
             LIMIT 200'
        );
        $stmt->execute([$productId, $from, $to]);

        return array_map(static fn (array $row): array => [
            'session_id' => (int) $row['session_id'],
            'closed_at' => $row['closed_at'],
            'table_name' => $row['table_name'],
            'qty' => (int) $row['qty'],
            'unit_price' => (float) $row['unit_price'],
            'line_total' => (float) $row['line_total'],
            'order_state' => (string) $row['order_state'],
        ], $stmt->fetchAll());
    }

    /** @return list<array<string, mixed>> */
    private function fetchMovementsWithBalance(int $productId): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT sm.*, COALESCE(NULLIF(u.full_name, \'\'), u.username) AS created_by_name
             FROM stock_movements sm
             LEFT JOIN users u ON u.id = sm.created_by
             WHERE sm.product_id = ?
             ORDER BY sm.created_at ASC, sm.id ASC'
        );
        $stmt->execute([$productId]);

        $rows = $stmt->fetchAll();
        $needsReplay = $rows !== [] && ($rows[0]['balance_after'] ?? null) === null;

        $result = [];
        $balance = 0;

        foreach ($rows as $row) {
            $formatted = $this->stock->formatMovementRow($row);

            if ($needsReplay) {
                $type = (string) $row['type'];
                $qty = (int) $row['quantity'];
                $before = $balance;
                $balance = match ($type) {
                    'in' => $balance + $qty,
                    'out', 'sale' => $balance - $qty,
                    'adjustment' => $qty,
                    default => $balance,
                };
                $formatted['balance_before'] = $before;
                $formatted['balance_after'] = $balance;
                if (($formatted['delta'] ?? 0) === 0 && $type === 'adjustment') {
                    $formatted['delta'] = $balance - $before;
                }
            }

            $result[] = $formatted;
        }

        return array_reverse($result);
    }
}
