<?php

declare(strict_types=1);

namespace App\Modules\Promotions;

use App\Support\ApiResponse;
use App\Support\DbSchema;
use App\Support\PromotionService;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class PromotionsController
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly PromotionService $promotions
    ) {
    }

    public function index(Request $request, Response $response): Response
    {
        if (!$this->tableExists()) {
            return ApiResponse::success([]);
        }

        $stmt = $this->pdo->query(
            'SELECT * FROM promotions ORDER BY sort_order, id'
        );

        return ApiResponse::success($this->decodeRows($stmt->fetchAll() ?: []));
    }

    public function active(Request $request, Response $response): Response
    {
        return ApiResponse::success($this->decodeRows($this->promotions->listActive()));
    }

    public function store(Request $request, Response $response): Response
    {
        if (!$this->tableExists()) {
            return ApiResponse::error('Promotions not available — run migrations', 503);
        }

        $body = (array) $request->getParsedBody();
        if (!$this->validateBody($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $scheduleError = $this->scheduleColumnError($body);
        if ($scheduleError !== null) {
            return ApiResponse::error($scheduleError, 503);
        }

        $tariffJson = $this->encodeTariffNames($body);
        $columns = 'business_id, name, discount_type, discount_value, applies_to, scope, tariff_names, is_active, valid_from, valid_until, sort_order, created_at, updated_at';
        $placeholders = '1, ?, ?, ?, \'time_only\', ?, ?, ?, ?, ?, ?, NOW(), NOW()';
        $params = [
            trim((string) $body['name']),
            $body['discount_type'],
            (float) $body['discount_value'],
            $body['scope'],
            $tariffJson,
            !empty($body['is_active']) ? 1 : 0,
            $this->nullableDate($body['valid_from'] ?? null),
            $this->nullableDate($body['valid_until'] ?? null),
            (int) ($body['sort_order'] ?? 0),
        ];
        if ($this->scheduleReady()) {
            $columns .= ', valid_days, valid_hours';
            $placeholders .= ', ?, ?';
            $params[] = PromotionService::encodeValidDays($body['valid_days'] ?? null);
            $params[] = PromotionService::encodeValidHours($body['valid_hours'] ?? null);
        }

        $this->pdo->prepare(
            "INSERT INTO promotions ({$columns}) VALUES ({$placeholders})"
        )->execute($params);

        return ApiResponse::success(['id' => (int) $this->pdo->lastInsertId()], [], 201);
    }

    public function update(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $body = (array) $request->getParsedBody();

        $fields = [];
        $params = [];
        $scheduleError = $this->scheduleColumnError($body);
        if ($scheduleError !== null) {
            return ApiResponse::error($scheduleError, 503);
        }

        foreach (['name', 'discount_type', 'discount_value', 'scope', 'is_active', 'valid_from', 'valid_until', 'valid_days', 'valid_hours', 'sort_order'] as $key) {
            if (!array_key_exists($key, $body)) {
                continue;
            }
            if (in_array($key, ['valid_days', 'valid_hours'], true) && !$this->scheduleReady()) {
                continue;
            }
            if ($key === 'is_active') {
                $fields[] = 'is_active = ?';
                $params[] = !empty($body['is_active']) ? 1 : 0;
                continue;
            }
            if (in_array($key, ['valid_from', 'valid_until'], true)) {
                $fields[] = "{$key} = ?";
                $params[] = $this->nullableDate($body[$key]);
                continue;
            }
            if ($key === 'valid_days') {
                $fields[] = 'valid_days = ?';
                $params[] = PromotionService::encodeValidDays($body[$key]);
                continue;
            }
            if ($key === 'valid_hours') {
                $fields[] = 'valid_hours = ?';
                $params[] = PromotionService::encodeValidHours($body[$key]);
                continue;
            }
            $fields[] = "{$key} = ?";
            $params[] = $body[$key];
        }

        if (array_key_exists('tariff_names', $body) || (array_key_exists('scope', $body) && ($body['scope'] ?? '') === 'tariffs')) {
            $fields[] = 'tariff_names = ?';
            $params[] = $this->encodeTariffNames($body);
        }

        if ($fields === []) {
            return ApiResponse::error('No fields', 422);
        }

        $fields[] = 'updated_at = NOW()';
        $params[] = $id;
        $this->pdo->prepare('UPDATE promotions SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);

        return ApiResponse::success(['id' => $id]);
    }

    public function destroy(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $this->pdo->prepare('UPDATE promotions SET is_active = 0, updated_at = NOW() WHERE id = ?')->execute([$id]);

        return ApiResponse::success(['id' => $id]);
    }

    private function validateBody(array $body): bool
    {
        return v::key('name', v::stringType()->notEmpty())
            ->key('discount_type', v::in(['percent', 'fixed']))
            ->key('discount_value', v::numericVal())
            ->key('scope', v::in(['all_tables', 'tariffs']))
            ->validate($body);
    }

    /**
     * @param array<string, mixed> $body
     */
    private function encodeTariffNames(array $body): ?string
    {
        if (($body['scope'] ?? 'all_tables') !== 'tariffs') {
            return null;
        }
        $names = $body['tariff_names'] ?? [];
        if (is_string($names)) {
            return $names;
        }
        if (!is_array($names)) {
            return '[]';
        }
        $clean = array_values(array_filter(array_map(static fn ($n) => trim((string) $n), $names)));

        return json_encode($clean, JSON_UNESCAPED_UNICODE);
    }

    private function nullableDate(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        return (string) $value;
    }

    /**
     * @param list<array<string, mixed>> $rows
     * @return list<array<string, mixed>>
     */
    private function decodeRows(array $rows): array
    {
        foreach ($rows as &$row) {
            $decoded = json_decode((string) ($row['tariff_names'] ?? '[]'), true);
            $row['tariff_names'] = is_array($decoded) ? $decoded : [];
            $decodedDays = json_decode((string) ($row['valid_days'] ?? '[]'), true);
            $row['valid_days'] = is_array($decodedDays) ? $decodedDays : [];
            $decodedHours = json_decode((string) ($row['valid_hours'] ?? '[]'), true);
            $row['valid_hours'] = is_array($decodedHours) ? $decodedHours : [];
            $row['is_active'] = (bool) ($row['is_active'] ?? false);
        }

        return $rows;
    }

    /**
     * @param array<string, mixed> $body
     */
    private function scheduleColumnError(array $body): ?string
    {
        if ($this->scheduleReady() || !$this->scheduleRequested($body)) {
            return null;
        }

        return 'Kampaniya günü üçün miqrasiya işlədin';
    }

    /**
     * @param array<string, mixed> $body
     */
    private function scheduleRequested(array $body): bool
    {
        $days = $body['valid_days'] ?? null;
        $hours = $body['valid_hours'] ?? null;
        if (is_array($days) && $days !== []) {
            return true;
        }
        if (is_array($hours) && $hours !== []) {
            return true;
        }

        return false;
    }

    private function scheduleReady(): bool
    {
        return DbSchema::hasColumn($this->pdo, 'promotions', 'valid_days')
            && DbSchema::hasColumn($this->pdo, 'promotions', 'valid_hours');
    }

    private function tableExists(): bool
    {
        $stmt = $this->pdo->query(
            "SELECT 1 FROM information_schema.TABLES
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'promotions' LIMIT 1"
        );

        return (bool) $stmt->fetchColumn();
    }
}
