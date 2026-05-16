<?php

declare(strict_types=1);

namespace App\Modules\Coupons;

use App\Support\ApiResponse;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class CouponsController
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function index(Request $request, Response $response): Response
    {
        $stmt = $this->pdo->query('SELECT * FROM coupons ORDER BY created_at DESC');
        return ApiResponse::success($stmt->fetchAll());
    }

    public function store(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        $validation = v::key('code', v::stringType()->notEmpty())
            ->key('discount_type', v::in(['percent', 'fixed']))
            ->key('discount_value', v::numericVal());
        if (!$validation->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $code = strtoupper(trim($body['code']));
        $dup = $this->pdo->prepare('SELECT id FROM coupons WHERE code = ?');
        $dup->execute([$code]);
        if ($dup->fetch()) {
            return ApiResponse::error('Bu kod artıq mövcuddur', 409);
        }

        $this->pdo->prepare(
            'INSERT INTO coupons (business_id, code, name, discount_type, discount_value, valid_from, valid_until, max_uses, used_count, is_active, created_at, updated_at)
             VALUES (1, ?, ?, ?, ?, ?, ?, ?, 0, 1, NOW(), NOW())'
        )->execute([
            $code,
            $body['name'] ?? null,
            $body['discount_type'],
            (float) $body['discount_value'],
            !empty($body['valid_from']) ? $body['valid_from'] : null,
            !empty($body['valid_until']) ? $body['valid_until'] : null,
            (int) ($body['max_uses'] ?? 0),
        ]);

        $id = (int) $this->pdo->lastInsertId();
        $stmt = $this->pdo->prepare('SELECT * FROM coupons WHERE id = ?');
        $stmt->execute([$id]);

        return ApiResponse::success($stmt->fetch(), [], 201);
    }

    public function update(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        $fields = [];
        $params = [];
        foreach (['name', 'discount_type', 'discount_value', 'valid_from', 'valid_until', 'max_uses', 'is_active'] as $key) {
            if (array_key_exists($key, $body)) {
                $fields[] = "{$key} = ?";
                $params[] = $body[$key];
            }
        }
        if (array_key_exists('code', $body)) {
            $fields[] = 'code = ?';
            $params[] = strtoupper(trim($body['code']));
        }
        if ($fields === []) {
            return ApiResponse::error('No fields', 422);
        }
        $fields[] = 'updated_at = NOW()';
        $params[] = $id;
        $this->pdo->prepare('UPDATE coupons SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);

        $stmt = $this->pdo->prepare('SELECT * FROM coupons WHERE id = ?');
        $stmt->execute([$id]);

        return ApiResponse::success($stmt->fetch() ?: ['updated' => true]);
    }

    public function destroy(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $this->pdo->prepare('UPDATE coupons SET is_active = 0, updated_at = NOW() WHERE id = ?')->execute([$id]);

        return ApiResponse::success(['deleted' => true]);
    }

    public function validateCoupon(array $coupon): ?string
    {
        if (!(bool) $coupon['is_active']) {
            return 'Kupon deaktivdir';
        }
        $now = time();
        if (!empty($coupon['valid_from']) && strtotime($coupon['valid_from']) > $now) {
            return 'Kupon hələ keçərli deyil';
        }
        if (!empty($coupon['valid_until']) && strtotime($coupon['valid_until']) < $now) {
            return 'Kuponun müddəti bitib';
        }
        $maxUses = (int) $coupon['max_uses'];
        if ($maxUses > 0 && (int) $coupon['used_count'] >= $maxUses) {
            return 'Kupon limiti dolub';
        }

        return null;
    }
}
