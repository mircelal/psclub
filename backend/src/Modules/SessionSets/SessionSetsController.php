<?php

declare(strict_types=1);

namespace App\Modules\SessionSets;

use App\Support\ApiResponse;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class SessionSetsController
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function index(Request $request, Response $response): Response
    {
        $stmt = $this->pdo->query(
            'SELECT * FROM session_sets WHERE is_active = 1 ORDER BY sort_order, id'
        );
        $sets = $stmt->fetchAll();
        $itemsBySet = $this->loadItemsGrouped();

        foreach ($sets as &$set) {
            $set['items'] = $itemsBySet[(int) $set['id']] ?? [];
        }

        return ApiResponse::success($sets);
    }

    public function store(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        if (!v::key('name', v::stringType()->notEmpty())->key('fixed_price', v::numericVal())->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $items = $this->normalizeItems($body['items'] ?? []);
        if ($items === []) {
            return ApiResponse::error('At least one product is required', 422);
        }

        $planned = isset($body['planned_minutes']) && (int) $body['planned_minutes'] > 0
            ? (int) $body['planned_minutes']
            : null;

        $this->pdo->beginTransaction();
        try {
            $this->pdo->prepare(
                'INSERT INTO session_sets (business_id, name, description, fixed_price, planned_minutes, sort_order, is_active, created_at, updated_at)
                 VALUES (1, ?, ?, ?, ?, ?, 1, NOW(), NOW())'
            )->execute([
                trim((string) $body['name']),
                trim((string) ($body['description'] ?? '')) ?: null,
                (float) $body['fixed_price'],
                $planned,
                (int) ($body['sort_order'] ?? 0),
            ]);
            $setId = (int) $this->pdo->lastInsertId();
            $this->syncItems($setId, $items);
            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            throw $e;
        }

        return ApiResponse::success(['id' => $setId], [], 201);
    }

    public function update(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $body = (array) $request->getParsedBody();

        $fields = [];
        $params = [];
        foreach (['name', 'description', 'fixed_price', 'planned_minutes', 'sort_order', 'is_active'] as $key) {
            if (!array_key_exists($key, $body)) {
                continue;
            }
            $fields[] = "{$key} = ?";
            $params[] = $body[$key];
        }

        if ($fields === [] && !array_key_exists('items', $body)) {
            return ApiResponse::error('No fields', 422);
        }

        $this->pdo->beginTransaction();
        try {
            if ($fields !== []) {
                $fields[] = 'updated_at = NOW()';
                $params[] = $id;
                $this->pdo->prepare('UPDATE session_sets SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);
            }
            if (array_key_exists('items', $body)) {
                $items = $this->normalizeItems($body['items']);
                if ($items === []) {
                    $this->pdo->rollBack();
                    return ApiResponse::error('At least one product is required', 422);
                }
                $this->syncItems($id, $items);
            }
            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            throw $e;
        }

        return ApiResponse::success(['updated' => true]);
    }

    public function destroy(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $this->pdo->prepare('UPDATE session_sets SET is_active = 0, updated_at = NOW() WHERE id = ?')->execute([$id]);
        return ApiResponse::success(['deleted' => true]);
    }

    public function findSet(int $setId): ?array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM session_sets WHERE id = ? AND is_active = 1');
        $stmt->execute([$setId]);
        $set = $stmt->fetch();
        if (!$set) {
            return null;
        }
        $itemsBySet = $this->loadItemsGrouped();
        $set['items'] = $itemsBySet[$setId] ?? [];

        return $set;
    }

    private function loadItemsGrouped(): array
    {
        $stmt = $this->pdo->query(
            'SELECT si.set_id, si.product_id, si.quantity, p.name AS product_name, p.price AS product_price
             FROM session_set_items si
             INNER JOIN products p ON p.id = si.product_id
             ORDER BY si.id'
        );
        $grouped = [];
        foreach ($stmt->fetchAll() as $row) {
            $grouped[(int) $row['set_id']][] = [
                'product_id' => (int) $row['product_id'],
                'product_name' => $row['product_name'],
                'quantity' => (int) $row['quantity'],
                'product_price' => (float) $row['product_price'],
            ];
        }

        return $grouped;
    }

    /** @return list<array{product_id: int, quantity: int}> */
    private function normalizeItems(mixed $raw): array
    {
        if (!is_array($raw)) {
            return [];
        }
        $items = [];
        foreach ($raw as $row) {
            if (!is_array($row)) {
                continue;
            }
            $productId = (int) ($row['product_id'] ?? 0);
            $qty = (int) ($row['quantity'] ?? 1);
            if ($productId <= 0 || $qty <= 0) {
                continue;
            }
            $items[] = ['product_id' => $productId, 'quantity' => $qty];
        }

        return $items;
    }

    /** @param list<array{product_id: int, quantity: int}> $items */
    private function syncItems(int $setId, array $items): void
    {
        $this->pdo->prepare('DELETE FROM session_set_items WHERE set_id = ?')->execute([$setId]);
        $stmt = $this->pdo->prepare(
            'INSERT INTO session_set_items (set_id, product_id, quantity) VALUES (?, ?, ?)'
        );
        foreach ($items as $item) {
            $stmt->execute([$setId, $item['product_id'], $item['quantity']]);
        }
    }
}
