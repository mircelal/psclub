<?php

declare(strict_types=1);

namespace App\Modules\Promotions;

use App\Support\ApiResponse;
use App\Support\DbSchema;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class SpendDiscountsController
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function index(Request $request, Response $response): Response
    {
        if (!$this->tableExists()) {
            return ApiResponse::success([]);
        }

        $stmt = $this->pdo->query('SELECT * FROM spend_discount_rules ORDER BY min_spend, id');
        $rows = $stmt->fetchAll() ?: [];
        foreach ($rows as &$row) {
            $row['min_spend'] = (float) $row['min_spend'];
            $row['discount_value'] = (float) $row['discount_value'];
            $row['is_active'] = (bool) $row['is_active'];
            $row['window_days'] = $row['window_days'] !== null ? (int) $row['window_days'] : null;
        }
        unset($row);

        return ApiResponse::success($rows);
    }

    public function store(Request $request, Response $response): Response
    {
        if (!$this->tableExists()) {
            return ApiResponse::error('Xərc endirimi mövcud deyil — miqrasiya işlədin', 503);
        }

        $body = (array) $request->getParsedBody();
        if (!$this->validateBody($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $window = $this->window($body);
        if ($window === null) {
            return ApiResponse::error('Pəncərə yanlışdır', 422);
        }

        $now = date('Y-m-d H:i:s');
        $this->pdo->prepare(
            'INSERT INTO spend_discount_rules
                (business_id, name, min_spend, window_type, window_days, discount_type, discount_value, applies_to, is_active, sort_order, created_at, updated_at)
             VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        )->execute([
            trim((string) $body['name']),
            round((float) $body['min_spend'], 2),
            $window['type'],
            $window['days'],
            $body['discount_type'],
            (float) $body['discount_value'],
            ($body['applies_to'] ?? 'all') === 'time_only' ? 'time_only' : 'all',
            !empty($body['is_active']) ? 1 : 0,
            (int) ($body['sort_order'] ?? 0),
            $now,
            $now,
        ]);

        return ApiResponse::success(['id' => (int) $this->pdo->lastInsertId()], [], 201);
    }

    public function update(Request $request, Response $response, array $args): Response
    {
        if (!$this->tableExists()) {
            return ApiResponse::error('Xərc endirimi mövcud deyil — miqrasiya işlədin', 503);
        }

        $id = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        $fields = [];
        $params = [];

        foreach (['name', 'min_spend', 'discount_type', 'discount_value', 'applies_to', 'is_active', 'sort_order'] as $key) {
            if (!array_key_exists($key, $body)) {
                continue;
            }
            if ($key === 'name') {
                $fields[] = 'name = ?';
                $params[] = trim((string) $body['name']);
            } elseif ($key === 'is_active') {
                $fields[] = 'is_active = ?';
                $params[] = !empty($body['is_active']) ? 1 : 0;
            } elseif ($key === 'applies_to') {
                $fields[] = 'applies_to = ?';
                $params[] = $body['applies_to'] === 'time_only' ? 'time_only' : 'all';
            } else {
                $fields[] = "{$key} = ?";
                $params[] = $body[$key];
            }
        }

        if (array_key_exists('window_type', $body) || array_key_exists('window_days', $body)) {
            $window = $this->window($body);
            if ($window === null) {
                return ApiResponse::error('Pəncərə yanlışdır', 422);
            }
            $fields[] = 'window_type = ?';
            $params[] = $window['type'];
            $fields[] = 'window_days = ?';
            $params[] = $window['days'];
        }

        if ($fields === []) {
            return ApiResponse::error('No fields', 422);
        }

        $fields[] = 'updated_at = ?';
        $params[] = date('Y-m-d H:i:s');
        $params[] = $id;
        $this->pdo->prepare('UPDATE spend_discount_rules SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);

        return ApiResponse::success(['id' => $id]);
    }

    public function destroy(Request $request, Response $response, array $args): Response
    {
        if (!$this->tableExists()) {
            return ApiResponse::error('Xərc endirimi mövcud deyil — miqrasiya işlədin', 503);
        }

        $id = (int) $args['id'];
        $this->pdo->prepare('UPDATE spend_discount_rules SET is_active = 0, updated_at = ? WHERE id = ?')
            ->execute([date('Y-m-d H:i:s'), $id]);

        return ApiResponse::success(['id' => $id]);
    }

    /**
     * @param array<string, mixed> $body
     * @return array{type: string, days: ?int}|null
     */
    private function window(array $body): ?array
    {
        $type = (string) ($body['window_type'] ?? 'lifetime');
        if (!in_array($type, ['lifetime', 'calendar_month', 'rolling_days'], true)) {
            return null;
        }
        if ($type === 'rolling_days') {
            $days = (int) ($body['window_days'] ?? 0);
            if ($days < 1) {
                return null;
            }

            return ['type' => $type, 'days' => $days];
        }

        return ['type' => $type, 'days' => null];
    }

    /**
     * @param array<string, mixed> $body
     */
    private function validateBody(array $body): bool
    {
        return v::key('name', v::stringType()->notEmpty())
            ->key('min_spend', v::numericVal())
            ->key('discount_type', v::in(['percent', 'fixed']))
            ->key('discount_value', v::numericVal())
            ->validate($body);
    }

    private function tableExists(): bool
    {
        return DbSchema::hasTable($this->pdo, 'spend_discount_rules');
    }
}
