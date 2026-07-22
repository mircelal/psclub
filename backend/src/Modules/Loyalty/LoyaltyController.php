<?php

declare(strict_types=1);

namespace App\Modules\Loyalty;

use App\Support\ApiResponse;
use App\Support\LoyaltyService;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class LoyaltyController
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly LoyaltyService $loyalty
    ) {
    }

    public function indexTiers(Request $request, Response $response): Response
    {
        if (!$this->loyalty->tablesExist()) {
            return ApiResponse::success([]);
        }

        $stmt = $this->pdo->query('SELECT * FROM loyalty_tiers ORDER BY sort_order, spend_threshold, id');

        return ApiResponse::success($stmt->fetchAll() ?: []);
    }

    public function storeTier(Request $request, Response $response): Response
    {
        if (!$this->loyalty->tablesExist()) {
            return ApiResponse::error('Loyallıq mövcud deyil — miqrasiya işlədin', 503);
        }

        $body = (array) $request->getParsedBody();
        if (!$this->validateTierBody($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $this->pdo->prepare(
            'INSERT INTO loyalty_tiers
                (business_id, name, spend_threshold, reward_kind, reward_value, reference_hourly_rate, is_active, sort_order, created_at, updated_at)
             VALUES (1, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())'
        )->execute([
            trim((string) $body['name']),
            (float) $body['spend_threshold'],
            $body['reward_kind'],
            (float) $body['reward_value'],
            $this->nullableRate($body['reference_hourly_rate'] ?? null),
            !empty($body['is_active']) ? 1 : 0,
            (int) ($body['sort_order'] ?? 0),
        ]);

        return ApiResponse::success(['id' => (int) $this->pdo->lastInsertId()], [], 201);
    }

    public function updateTier(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        $fields = [];
        $params = [];

        foreach (['name', 'spend_threshold', 'reward_kind', 'reward_value', 'sort_order'] as $key) {
            if (!array_key_exists($key, $body)) {
                continue;
            }
            $fields[] = "{$key} = ?";
            $params[] = $key === 'name' ? trim((string) $body[$key]) : $body[$key];
        }

        if (array_key_exists('reference_hourly_rate', $body)) {
            $fields[] = 'reference_hourly_rate = ?';
            $params[] = $this->nullableRate($body['reference_hourly_rate']);
        }

        if (array_key_exists('is_active', $body)) {
            $fields[] = 'is_active = ?';
            $params[] = !empty($body['is_active']) ? 1 : 0;
        }

        if ($fields === []) {
            return ApiResponse::error('No fields', 422);
        }

        $fields[] = 'updated_at = NOW()';
        $params[] = $id;
        $this->pdo->prepare('UPDATE loyalty_tiers SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);

        return ApiResponse::success(['id' => $id]);
    }

    public function destroyTier(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $this->pdo->prepare('DELETE FROM loyalty_tiers WHERE id = ?')->execute([$id]);

        return ApiResponse::success(['deleted' => true]);
    }

    public function customerLoyalty(Request $request, Response $response, array $args): Response
    {
        $customerId = (int) $args['id'];
        if (!$this->customerExists($customerId)) {
            return ApiResponse::error('Müştəri tapılmadı', 404);
        }

        return ApiResponse::success([
            'balance' => $this->loyalty->getBalance($customerId),
            'ledger' => $this->loyalty->getLedger($customerId),
        ]);
    }

    public function grant(Request $request, Response $response, array $args): Response
    {
        $customerId = (int) $args['id'];
        if (!$this->customerExists($customerId)) {
            return ApiResponse::error('Müştəri tapılmadı', 404);
        }

        $body = (array) $request->getParsedBody();
        $validation = v::key('kind', v::in(['hours', 'wallet']))
            ->key('value', v::numericVal()->min(0.01));
        if (!$validation->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $user = $request->getAttribute('user');
        try {
            $result = $this->loyalty->adminGrant(
                $customerId,
                (string) $body['kind'],
                (float) $body['value'],
                isset($body['note']) ? trim((string) $body['note']) : null,
                (int) $user['id']
            );
        } catch (\InvalidArgumentException $e) {
            return ApiResponse::error($e->getMessage(), 422);
        }

        return ApiResponse::success([
            'granted' => $result,
            'balance' => $this->loyalty->getBalance($customerId),
        ]);
    }

    private function customerExists(int $id): bool
    {
        $stmt = $this->pdo->prepare('SELECT id FROM customers WHERE id = ? AND is_active = 1');
        $stmt->execute([$id]);

        return (bool) $stmt->fetch();
    }

    private function validateTierBody(array $body): bool
    {
        return v::key('name', v::stringType()->notEmpty())
            ->key('spend_threshold', v::numericVal()->min(10))
            ->key('reward_kind', v::in(['hours', 'hours_percent', 'wallet_percent', 'wallet_fixed']))
            ->key('reward_value', v::numericVal()->min(0.01))
            ->validate($body);
    }

    private function nullableRate(mixed $value): ?float
    {
        if ($value === null || $value === '') {
            return null;
        }
        $rate = (float) $value;

        return $rate > 0 ? $rate : null;
    }
}
