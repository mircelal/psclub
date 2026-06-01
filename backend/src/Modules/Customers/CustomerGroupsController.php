<?php

declare(strict_types=1);

namespace App\Modules\Customers;

use App\Support\ApiResponse;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class CustomerGroupsController
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function index(Request $request, Response $response): Response
    {
        if (!$this->tableExists()) {
            return ApiResponse::success([]);
        }

        $stmt = $this->pdo->query(
            'SELECT cg.*,
                    (SELECT COUNT(*) FROM customers c WHERE c.customer_group_id = cg.id AND c.is_active = 1) AS member_count
             FROM customer_groups cg
             ORDER BY cg.sort_order, cg.id'
        );

        $rows = $stmt->fetchAll() ?: [];
        foreach ($rows as &$row) {
            $row['member_count'] = (int) ($row['member_count'] ?? 0);
            $row['discount_value'] = (float) ($row['discount_value'] ?? 0);
            $row['is_active'] = (bool) ($row['is_active'] ?? true);
        }
        unset($row);

        return ApiResponse::success($rows);
    }

    public function active(Request $request, Response $response): Response
    {
        if (!$this->tableExists()) {
            return ApiResponse::success([]);
        }

        $stmt = $this->pdo->query(
            'SELECT id, name, description, discount_type, discount_value, applies_to, color
             FROM customer_groups
             WHERE is_active = 1
             ORDER BY sort_order, id'
        );

        return ApiResponse::success($stmt->fetchAll() ?: []);
    }

    public function store(Request $request, Response $response): Response
    {
        if (!$this->tableExists()) {
            return ApiResponse::error('Customer groups not available — run migrations', 503);
        }

        $body = (array) $request->getParsedBody();
        if (!$this->validateBody($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $this->pdo->prepare(
            'INSERT INTO customer_groups (business_id, name, description, discount_type, discount_value, applies_to, color, is_active, sort_order, created_at, updated_at)
             VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())'
        )->execute([
            trim((string) $body['name']),
            $this->nullableString($body['description'] ?? null),
            $body['discount_type'],
            (float) $body['discount_value'],
            $body['applies_to'] ?? 'time_only',
            $this->nullableString($body['color'] ?? null),
            !empty($body['is_active']) ? 1 : 0,
            (int) ($body['sort_order'] ?? 0),
        ]);

        return ApiResponse::success(['id' => (int) $this->pdo->lastInsertId()], [], 201);
    }

    public function update(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $body = (array) $request->getParsedBody();

        $fields = [];
        $params = [];
        foreach (['name', 'description', 'discount_type', 'discount_value', 'applies_to', 'color', 'is_active', 'sort_order'] as $key) {
            if (!array_key_exists($key, $body)) {
                continue;
            }
            if ($key === 'name') {
                $fields[] = 'name = ?';
                $params[] = trim((string) $body['name']);
            } elseif ($key === 'is_active') {
                $fields[] = 'is_active = ?';
                $params[] = !empty($body['is_active']) ? 1 : 0;
            } elseif ($key === 'description' || $key === 'color') {
                $fields[] = "{$key} = ?";
                $params[] = $this->nullableString($body[$key]);
            } else {
                $fields[] = "{$key} = ?";
                $params[] = $body[$key];
            }
        }

        if ($fields === []) {
            return ApiResponse::error('No fields', 422);
        }

        $fields[] = 'updated_at = NOW()';
        $params[] = $id;
        $this->pdo->prepare('UPDATE customer_groups SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);

        return ApiResponse::success(['updated' => true]);
    }

    public function destroy(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $this->pdo->prepare('UPDATE customer_groups SET is_active = 0, updated_at = NOW() WHERE id = ?')->execute([$id]);

        return ApiResponse::success(['deleted' => true]);
    }

    private function validateBody(array $body): bool
    {
        return v::key('name', v::stringType()->notEmpty())
            ->key('discount_type', v::in(['percent', 'fixed']))
            ->key('discount_value', v::numericVal())
            ->validate($body);
    }

    private function nullableString(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }
        $trimmed = trim((string) $value);

        return $trimmed === '' ? null : $trimmed;
    }

    private function tableExists(): bool
    {
        $stmt = $this->pdo->query(
            "SELECT 1 FROM information_schema.TABLES
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'customer_groups' LIMIT 1"
        );

        return (bool) $stmt->fetchColumn();
    }
}
