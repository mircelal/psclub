<?php

declare(strict_types=1);

namespace App\Modules\Stock;

use App\Support\ApiResponse;
use App\Support\SchemaMigrator;
use App\Support\StockMovementLabels;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class StockController
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function movements(Request $request, Response $response): Response
    {
        $params = $request->getQueryParams();
        $productId = isset($params['product_id']) ? (int) $params['product_id'] : null;
        $limit = min(500, max(1, (int) ($params['limit'] ?? 200)));

        $sql = 'SELECT sm.*, p.name AS product_name,
                       COALESCE(NULLIF(u.full_name, \'\'), u.username) AS created_by_name
             FROM stock_movements sm
             JOIN products p ON p.id = sm.product_id
             LEFT JOIN users u ON u.id = sm.created_by';
        $bindings = [];

        if ($productId !== null && $productId > 0) {
            $sql .= ' WHERE sm.product_id = ?';
            $bindings[] = $productId;
        }

        $sql .= ' ORDER BY sm.created_at DESC, sm.id DESC LIMIT ' . $limit;

        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($bindings);

        $rows = array_map(fn (array $row): array => $this->formatMovementRow($row), $stmt->fetchAll());

        return ApiResponse::success($rows);
    }

    public function storeMovement(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');
        $validation = v::key('product_id', v::intVal()->positive())
            ->key('type', v::in(['in', 'out', 'adjustment']))
            ->key('quantity', v::intVal()->positive());
        if (!$validation->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $type = (string) $body['type'];
        $qty = (int) $body['quantity'];
        $actor = StockMovementLabels::actorLabel($user['full_name'] ?? null, $user['username'] ?? null);
        $customNote = trim((string) ($body['note'] ?? ''));
        $note = $customNote !== '' ? $customNote : match ($type) {
            'in' => $actor . ': anbara +' . $qty,
            'out' => $actor . ': anbardan −' . $qty,
            'adjustment' => $actor . ': stok düzəlişi → ' . $qty,
            default => $actor . ': stok əməliyyatı',
        };

        $this->pdo->beginTransaction();
        try {
            $this->applyStockChange(
                (int) $body['product_id'],
                $type,
                $qty,
                $type,
                'manual',
                null,
                (int) $user['id'],
                $note
            );
            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            return ApiResponse::error($e->getMessage(), 400);
        }

        return ApiResponse::success(['ok' => true], [], 201);
    }

    public function alerts(Request $request, Response $response): Response
    {
        $biz = $this->pdo->query('SELECT min_stock_threshold FROM businesses WHERE id = 1')->fetch();
        $threshold = (int) ($biz['min_stock_threshold'] ?? 5);

        $stmt = $this->pdo->prepare(
            'SELECT p.id, p.name, ps.quantity
             FROM products p
             JOIN product_stock ps ON ps.product_id = p.id
             WHERE p.is_active = 1 AND ps.quantity <= ?'
        );
        $stmt->execute([$threshold]);

        return ApiResponse::success($stmt->fetchAll());
    }

    public function applyStockChange(
        int $productId,
        string $type,
        int $quantity,
        string $movementType,
        ?string $refType,
        ?int $refId,
        ?int $userId,
        ?string $note = null
    ): void {
        if ($quantity < 0) {
            throw new \RuntimeException('Invalid quantity');
        }

        $stmt = $this->pdo->prepare('SELECT quantity FROM product_stock WHERE product_id = ? FOR UPDATE');
        $stmt->execute([$productId]);
        $row = $stmt->fetch();
        if (!$row) {
            throw new \RuntimeException('Product stock not found');
        }

        $current = (int) $row['quantity'];
        $delta = match ($type) {
            'in' => $quantity,
            'out', 'sale' => -$quantity,
            'adjustment' => $quantity - $current,
            default => 0,
        };
        $newQty = $current + $delta;
        if ($newQty < 0) {
            throw new \RuntimeException('Insufficient stock');
        }

        $this->pdo->prepare('UPDATE product_stock SET quantity = ?, updated_at = NOW() WHERE product_id = ?')
            ->execute([$newQty, $productId]);

        $stockType = match ($movementType) {
            'return', 'refund', 'order_delete' => 'in',
            'sale' => 'sale',
            'out' => 'out',
            'adjustment' => 'adjustment',
            'in' => 'in',
            default => 'in',
        };

        $storedQty = $type === 'adjustment' ? $newQty : $quantity;
        $createdBy = ($userId !== null && $userId > 0) ? $userId : null;

        if (SchemaMigrator::columnExists($this->pdo, 'stock_movements', 'delta')) {
            $this->pdo->prepare(
                'INSERT INTO stock_movements
                 (business_id, product_id, type, quantity, delta, balance_before, balance_after,
                  reference_type, reference_id, note, created_by, created_at)
                 VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())'
            )->execute([
                $productId,
                $stockType,
                abs($storedQty),
                $delta,
                $current,
                $newQty,
                $refType,
                $refId,
                $note,
                $createdBy,
            ]);
        } else {
            $this->pdo->prepare(
                'INSERT INTO stock_movements (business_id, product_id, type, quantity, reference_type, reference_id, note, created_by, created_at)
                 VALUES (1, ?, ?, ?, ?, ?, ?, ?, NOW())'
            )->execute([
                $productId,
                $stockType,
                abs($storedQty),
                $refType,
                $refId,
                $note,
                $createdBy,
            ]);
        }
    }

    /** @param array<string, mixed> $row */
    public function formatMovementRow(array $row): array
    {
        $type = (string) $row['type'];
        $qty = (int) $row['quantity'];

        $delta = array_key_exists('delta', $row) && $row['delta'] !== null
            ? (int) $row['delta']
            : match ($type) {
                'in' => $qty,
                'out', 'sale' => -$qty,
                'adjustment' => 0,
                default => 0,
            };

        $balanceAfter = array_key_exists('balance_after', $row) && $row['balance_after'] !== null
            ? (int) $row['balance_after']
            : null;

        return [
            'id' => (int) $row['id'],
            'product_id' => (int) $row['product_id'],
            'product_name' => $row['product_name'] ?? null,
            'type' => $type,
            'reference_type' => $row['reference_type'],
            'reference_id' => $row['reference_id'] !== null ? (int) $row['reference_id'] : null,
            'quantity' => $qty,
            'delta' => $delta,
            'balance_before' => array_key_exists('balance_before', $row) && $row['balance_before'] !== null
                ? (int) $row['balance_before']
                : null,
            'balance_after' => $balanceAfter,
            'label_az' => StockMovementLabels::labelAz($type, $row['reference_type'], $row['reference_id']),
            'created_at' => $row['created_at'],
            'created_by_name' => $row['created_by_name'] ?? null,
            'note' => $row['note'],
        ];
    }
}
