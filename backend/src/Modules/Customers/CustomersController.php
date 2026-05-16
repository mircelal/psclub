<?php

declare(strict_types=1);

namespace App\Modules\Customers;

use App\Support\ApiResponse;
use App\Support\PhoneNormalizer;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class CustomersController
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function index(Request $request, Response $response): Response
    {
        $q = trim((string) ($request->getQueryParams()['q'] ?? ''));
        if ($q !== '') {
            $like = '%' . $q . '%';
            $digits = preg_replace('/\D+/', '', $q) ?? '';
            $phoneLike = $digits !== '' ? '%' . $digits . '%' : $like;
            $stmt = $this->pdo->prepare(
                'SELECT * FROM customers WHERE is_active = 1 AND (name LIKE ? OR phone LIKE ? OR phone LIKE ? OR email LIKE ?)
                 ORDER BY name LIMIT 100'
            );
            $stmt->execute([$like, $like, $phoneLike, $like]);
        } else {
            $stmt = $this->pdo->query('SELECT * FROM customers WHERE is_active = 1 ORDER BY name LIMIT 500');
        }

        return ApiResponse::success($stmt->fetchAll());
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
            'INSERT INTO customers (business_id, name, phone, email, notes, is_active, created_at, updated_at)
             VALUES (1, ?, ?, ?, ?, 1, NOW(), NOW())'
        )->execute([
            trim($body['name']),
            $phone,
            $body['email'] ?? null,
            $body['notes'] ?? null,
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
        foreach (['email', 'notes', 'is_active'] as $key) {
            if (array_key_exists($key, $body)) {
                $fields[] = "{$key} = ?";
                $params[] = $body[$key];
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
