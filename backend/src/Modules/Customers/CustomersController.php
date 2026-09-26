<?php

declare(strict_types=1);

namespace App\Modules\Customers;

use App\Support\ApiResponse;
use App\Support\LoyaltyService;
use App\Support\PhoneNormalizer;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class CustomersController
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly LoyaltyService $loyalty,
    ) {
    }

    public function index(Request $request, Response $response): Response
    {
        $q = trim((string) ($request->getQueryParams()['q'] ?? ''));
        $filter = (string) ($request->getQueryParams()['filter'] ?? 'all');
        $allowedFilters = ['all', 'with_spending', 'with_sessions', 'no_sessions', 'active_now', 'top_spending'];
        if (!in_array($filter, $allowedFilters, true)) {
            $filter = 'all';
        }

        $sql = 'SELECT c.*,
                cg.name AS customer_group_name,
                cg.discount_type AS customer_group_discount_type,
                cg.discount_value AS customer_group_discount_value,
                cg.applies_to AS customer_group_applies_to,
                cg.color AS customer_group_color,
                COALESCE(SUM(CASE WHEN s.status = \'closed\' THEN s.total_amount ELSE 0 END), 0) AS total_spent,
                COALESCE(SUM(CASE WHEN s.status = \'closed\' THEN 1 ELSE 0 END), 0) AS closed_session_count,
                COUNT(s.id) AS session_count,
                COALESCE(SUM(CASE WHEN s.status IN (\'active\', \'paused\') THEN 1 ELSE 0 END), 0) AS open_session_count
            FROM customers c
            LEFT JOIN customer_groups cg ON cg.id = c.customer_group_id AND cg.is_active = 1
            LEFT JOIN sessions s ON s.customer_id = c.id
            WHERE c.is_active = 1';

        $params = [];
        if ($q !== '') {
            $like = '%' . $q . '%';
            $digits = preg_replace('/\D+/', '', $q) ?? '';
            $phoneLike = $digits !== '' ? '%' . $digits . '%' : $like;
            $sql .= ' AND (c.name LIKE ? OR c.phone LIKE ? OR c.phone LIKE ? OR c.email LIKE ?)';
            $params = [$like, $like, $phoneLike, $like];
        }

        $sql .= ' GROUP BY c.id, cg.id, cg.name, cg.discount_type, cg.discount_value, cg.applies_to, cg.color';

        $sql .= match ($filter) {
            'with_spending' => ' HAVING total_spent > 0',
            'with_sessions' => ' HAVING session_count > 0',
            'no_sessions' => ' HAVING session_count = 0',
            'active_now' => ' HAVING open_session_count > 0',
            default => '',
        };

        $sql .= match ($filter) {
            'top_spending' => ' ORDER BY total_spent DESC, c.name ASC',
            default => ' ORDER BY c.name ASC',
        };

        $sql .= ' LIMIT 500';

        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$row) {
            $row['total_spent'] = (float) ($row['total_spent'] ?? 0);
            $row['session_count'] = (int) ($row['session_count'] ?? 0);
            $row['closed_session_count'] = (int) ($row['closed_session_count'] ?? 0);
            $row['open_session_count'] = (int) ($row['open_session_count'] ?? 0);
        }
        unset($row);

        return ApiResponse::success($rows);
    }

    public function store(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        if (!v::key('name', v::stringType()->notEmpty())->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $phone = PhoneNormalizer::normalize($body['phone'] ?? null);
        if ($phone === null) {
            return ApiResponse::error('Telefon +994XXXXXXXXX formatında olmalıdır', 422);
        }

        if ($this->phoneExists($phone)) {
            return ApiResponse::error('Bu telefon nömrəsi artıq qeydiyyatdadır', 409);
        }

        $this->pdo->prepare(
            'INSERT INTO customers (business_id, name, phone, email, notes, customer_group_id, is_active, created_at, updated_at)
             VALUES (1, ?, ?, ?, ?, ?, 1, NOW(), NOW())'
        )->execute([
            trim($body['name']),
            $phone,
            $body['email'] ?? null,
            $body['notes'] ?? null,
            isset($body['customer_group_id']) && (int) $body['customer_group_id'] > 0
                ? (int) $body['customer_group_id']
                : null,
        ]);

        $id = (int) $this->pdo->lastInsertId();
        $stmt = $this->pdo->prepare('SELECT * FROM customers WHERE id = ?');
        $stmt->execute([$id]);

        return ApiResponse::success($stmt->fetch(), [], 201);
    }

    public function update(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        $fields = [];
        $params = [];

        if (array_key_exists('name', $body)) {
            $fields[] = 'name = ?';
            $params[] = trim((string) $body['name']);
        }
        if (array_key_exists('phone', $body)) {
            $phone = PhoneNormalizer::normalize($body['phone']);
            if ($phone === null) {
                return ApiResponse::error('Telefon +994XXXXXXXXX formatında olmalıdır', 422);
            }
            if ($this->phoneExists($phone, $id)) {
                return ApiResponse::error('Bu telefon nömrəsi artıq qeydiyyatdadır', 409);
            }
            $fields[] = 'phone = ?';
            $params[] = $phone;
        }
        foreach (['email', 'notes', 'is_active', 'customer_group_id'] as $key) {
            if (array_key_exists($key, $body)) {
                $fields[] = "{$key} = ?";
                $params[] = $key === 'customer_group_id'
                    ? (((int) ($body[$key] ?? 0)) > 0 ? (int) $body[$key] : null)
                    : $body[$key];
            }
        }
        if ($fields === []) {
            return ApiResponse::error('No fields', 422);
        }
        $fields[] = 'updated_at = NOW()';
        $params[] = $id;
        $this->pdo->prepare('UPDATE customers SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);

        $stmt = $this->pdo->prepare('SELECT * FROM customers WHERE id = ?');
        $stmt->execute([$id]);

        return ApiResponse::success($stmt->fetch() ?: ['updated' => true]);
    }

    public function show(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $stmt = $this->pdo->prepare(
            'SELECT c.*, cg.name AS customer_group_name, cg.discount_type AS customer_group_discount_type,
                    cg.discount_value AS customer_group_discount_value, cg.applies_to AS customer_group_applies_to,
                    cg.color AS customer_group_color
             FROM customers c
             LEFT JOIN customer_groups cg ON cg.id = c.customer_group_id AND cg.is_active = 1
             WHERE c.id = ? AND c.is_active = 1'
        );
        $stmt->execute([$id]);
        $customer = $stmt->fetch();
        if (!$customer) {
            return ApiResponse::error('Müştəri tapılmadı', 404);
        }

        $statsStmt = $this->pdo->prepare(
            'SELECT
                COUNT(*) AS session_count,
                SUM(CASE WHEN status = \'closed\' THEN 1 ELSE 0 END) AS closed_session_count,
                SUM(CASE WHEN status IN (\'active\', \'paused\') THEN 1 ELSE 0 END) AS open_session_count,
                COALESCE(SUM(CASE WHEN status = \'closed\' THEN total_amount ELSE 0 END), 0) AS total_spent,
                COALESCE(SUM(CASE WHEN status = \'closed\' THEN products_total ELSE 0 END), 0) AS products_spent,
                COALESCE(SUM(CASE WHEN status = \'closed\' THEN time_charge ELSE 0 END), 0) AS time_spent,
                COALESCE(SUM(CASE WHEN status = \'closed\' THEN active_seconds ELSE 0 END), 0) AS play_seconds
             FROM sessions
             WHERE customer_id = ?'
        );
        $statsStmt->execute([$id]);
        $stats = $statsStmt->fetch() ?: [];

        $sessionsStmt = $this->pdo->prepare(
            'SELECT s.id, s.session_type, s.status, s.opened_at, s.closed_at,
                    s.time_charge, s.products_total, s.discount, s.total_amount, s.active_seconds,
                    s.set_name_snapshot, s.planned_minutes,
                    t.name AS table_name
             FROM sessions s
             LEFT JOIN tables t ON t.id = s.table_id
             WHERE s.customer_id = ?
             ORDER BY s.opened_at DESC
             LIMIT 200'
        );
        $sessionsStmt->execute([$id]);

        return ApiResponse::success([
            'customer' => $customer,
            'loyalty' => [
                'balance' => $this->loyalty->getBalance($id),
                'ledger' => $this->loyalty->getLedger($id),
            ],
            'stats' => [
                'session_count' => (int) ($stats['session_count'] ?? 0),
                'closed_session_count' => (int) ($stats['closed_session_count'] ?? 0),
                'open_session_count' => (int) ($stats['open_session_count'] ?? 0),
                'total_spent' => (float) ($stats['total_spent'] ?? 0),
                'products_spent' => (float) ($stats['products_spent'] ?? 0),
                'time_spent' => (float) ($stats['time_spent'] ?? 0),
                'play_seconds' => (int) ($stats['play_seconds'] ?? 0),
            ],
            'sessions' => $sessionsStmt->fetchAll(),
        ]);
    }

    public function destroy(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $this->pdo->prepare('UPDATE customers SET is_active = 0, updated_at = NOW() WHERE id = ?')->execute([$id]);

        return ApiResponse::success(['deleted' => true]);
    }

    private function phoneExists(string $phone, ?int $excludeId = null): bool
    {
        if ($excludeId !== null) {
            $stmt = $this->pdo->prepare('SELECT id FROM customers WHERE phone = ? AND is_active = 1 AND id <> ? LIMIT 1');
            $stmt->execute([$phone, $excludeId]);
        } else {
            $stmt = $this->pdo->prepare('SELECT id FROM customers WHERE phone = ? AND is_active = 1 LIMIT 1');
            $stmt->execute([$phone]);
        }

        return (bool) $stmt->fetch();
    }
}
