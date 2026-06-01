<?php

declare(strict_types=1);

namespace App\Modules\Stock;

use App\Support\ApiResponse;
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
        $stmt = $this->pdo->query(
            'SELECT sm.*, p.name AS product_name, u.username AS created_by_name
             FROM stock_movements sm
             JOIN products p ON p.id = sm.product_id
             LEFT JOIN users u ON u.id = sm.created_by
             ORDER BY sm.created_at DESC LIMIT 100'
        );
        return ApiResponse::success($stmt->fetchAll());
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

        $this->pdo->beginTransaction();
        try {
            $this->applyStockChange(
                (int) $body['product_id'],
                $body['type'],
                (int) $body['quantity'],
                $body['type'],
                null,
                (int) $user['id'],
                $body['note'] ?? null
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

        $this->pdo->prepare(
            'INSERT INTO stock_movements (business_id, product_id, type, quantity, reference_type, reference_id, note, created_by, created_at)
             VALUES (1, ?, ?, ?, ?, ?, ?, ?, NOW())'
        )->execute([$productId, $stockType, abs($quantity), $refType, $refId, $note, $userId]);
    }
}
