<?php

declare(strict_types=1);

namespace App\Modules\Promotions;

use App\Support\ApiResponse;
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

        $scope = (string) $body['scope'];
        if ($scope === 'products' && $this->encodeProductIds($body) === null) {
            return ApiResponse::error('Ən azı bir məhsul seçin', 422);
        }
        if ($scope === 'tariffs' && $this->encodeTariffNames($body) === null) {
            return ApiResponse::error('Ən azı bir tarif seçin', 422);
        }

        $appliesTo = $scope === 'products' ? 'products' : 'time_only';
        $tariffJson = $scope === 'products' ? null : $this->encodeTariffNames($body);
        $productJson = $scope === 'products' ? $this->encodeProductIds($body) : null;

        $this->pdo->prepare(
            'INSERT INTO promotions (business_id, name, discount_type, discount_value, applies_to, scope, tariff_names, product_ids, is_active, valid_from, valid_until, valid_days, valid_hours, sort_order, created_at, updated_at)
             VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())'
        )->execute([
            trim((string) $body['name']),
            $body['discount_type'],
            (float) $body['discount_value'],
            $appliesTo,
            $scope,
            $tariffJson,
            $productJson,
            !empty($body['is_active']) ? 1 : 0,
            $this->nullableDate($body['valid_from'] ?? null),
            $this->nullableDate($body['valid_until'] ?? null),
            $this->encodeJsonList($body['valid_days'] ?? null),
            $this->encodeJsonHours($body['valid_hours'] ?? null),
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
        foreach (['name', 'discount_type', 'discount_value', 'scope', 'is_active', 'valid_from', 'valid_until', 'valid_days', 'valid_hours', 'sort_order'] as $key) {
            if (!array_key_exists($key, $body)) {
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
                $params[] = $this->encodeJsonList($body[$key]);
                continue;
            }
            if ($key === 'valid_hours') {
                $fields[] = 'valid_hours = ?';
                $params[] = $this->encodeJsonHours($body[$key]);
                continue;
            }
            if ($key === 'scope') {
                $fields[] = 'scope = ?';
                $params[] = $body[$key];
                $fields[] = 'applies_to = ?';
                $params[] = ($body[$key] ?? '') === 'products' ? 'products' : 'time_only';
                continue;
            }
            $fields[] = "{$key} = ?";
            $params[] = $body[$key];
        }

        $scope = $body['scope'] ?? null;
        if ($scope === 'products') {
            $encoded = $this->encodeProductIds($body);
            if ($encoded === null) {
                return ApiResponse::error('Ən azı bir məhsul seçin', 422);
            }
            $fields[] = 'product_ids = ?';
            $params[] = $encoded;
            $fields[] = 'tariff_names = ?';
            $params[] = null;
        } elseif ($scope === 'tariffs') {
            $fields[] = 'tariff_names = ?';
            $params[] = $this->encodeTariffNames($body);
            $fields[] = 'product_ids = ?';
            $params[] = null;
        } elseif ($scope === 'all_tables') {
            $fields[] = 'tariff_names = ?';
            $params[] = null;
            $fields[] = 'product_ids = ?';
            $params[] = null;
        } else {
            if (array_key_exists('tariff_names', $body)) {
                $fields[] = 'tariff_names = ?';
                $params[] = $this->encodeTariffNames(array_merge($body, ['scope' => 'tariffs']));
            }
            if (array_key_exists('product_ids', $body)) {
                $fields[] = 'product_ids = ?';
                $params[] = $this->encodeProductIds($body);
            }
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
        if (!$this->tableExists()) {
            return ApiResponse::error('Promotions not available — run migrations', 503);
        }

        $id = (int) $args['id'];
        $stmt = $this->pdo->prepare('SELECT id FROM promotions WHERE id = ? LIMIT 1');
        $stmt->execute([$id]);
        if (!$stmt->fetch()) {
            return ApiResponse::error('Endirim paketi tapılmadı', 404);
        }

        $this->pdo->prepare('DELETE FROM promotions WHERE id = ?')->execute([$id]);

        return ApiResponse::success(['deleted' => true, 'id' => $id]);
    }

    private function validateBody(array $body): bool
    {
        return v::key('name', v::stringType()->notEmpty())
            ->key('discount_type', v::in(['percent', 'fixed']))
            ->key('discount_value', v::numericVal())
            ->key('scope', v::in(['all_tables', 'tariffs', 'products']))
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
            return null;
        }
        $clean = array_values(array_filter(array_map(static fn ($n) => trim((string) $n), $names)));
        if ($clean === []) {
            return null;
        }

        return json_encode($clean, JSON_UNESCAPED_UNICODE);
    }

    /**
     * @param array<string, mixed> $body
     */
    private function encodeProductIds(array $body): ?string
    {
        $ids = $body['product_ids'] ?? [];
        if (is_string($ids)) {
            $decoded = json_decode($ids, true);
            $ids = is_array($decoded) ? $decoded : [];
        }
        if (!is_array($ids)) {
            return null;
        }
        $clean = [];
        foreach ($ids as $id) {
            $n = (int) $id;
            if ($n > 0) {
                $clean[$n] = $n;
            }
        }
        $clean = array_values($clean);
        if ($clean === []) {
            return null;
        }

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
            $decodedProducts = json_decode((string) ($row['product_ids'] ?? '[]'), true);
            $row['product_ids'] = is_array($decodedProducts)
                ? array_values(array_map(static fn ($id) => (int) $id, $decodedProducts))
                : [];
            $decodedDays = json_decode((string) ($row['valid_days'] ?? '[]'), true);
            $row['valid_days'] = is_array($decodedDays) ? $decodedDays : [];
            $decodedHours = json_decode((string) ($row['valid_hours'] ?? '[]'), true);
            $row['valid_hours'] = is_array($decodedHours) ? $decodedHours : [];
            $row['is_active'] = (bool) ($row['is_active'] ?? false);
        }

        return $rows;
    }

    /**
     * @param mixed $value
     */
    private function encodeJsonList(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }
        if (is_string($value)) {
            return $value;
        }
        if (!is_array($value)) {
            return null;
        }
        // Keep 0 (Monday) — bare array_filter() drops falsy ints.
        $mapped = array_map(static fn ($v) => (int) $v, $value);
        $clean = array_values(array_unique(array_filter($mapped, static fn ($v) => $v >= 0 && $v <= 6)));
        if ($clean === []) {
            return null;
        }

        return json_encode($clean, JSON_UNESCAPED_UNICODE);
    }

    /**
     * @param mixed $value
     */
    private function encodeJsonHours(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }
        if (is_string($value)) {
            return $value;
        }
        if (!is_array($value)) {
            return null;
        }
        $clean = [];
        foreach ($value as $range) {
            if (!is_array($range)) {
                continue;
            }
            $from = isset($range['from']) ? trim((string) $range['from']) : null;
            $until = isset($range['until']) ? trim((string) $range['until']) : null;
            if ($from === null || $until === null || $from === '' || $until === '') {
                continue;
            }
            $clean[] = ['from' => $from, 'until' => $until];
        }
        if ($clean === []) {
            return null;
        }

        return json_encode($clean, JSON_UNESCAPED_UNICODE);
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
