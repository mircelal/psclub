<?php

declare(strict_types=1);

namespace App\Modules\Tables;

use App\Support\ApiResponse;
use App\Support\BillingCalculator;
use App\Support\DatabaseClock;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class TablesController
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly BillingCalculator $billing,
        private readonly DatabaseClock $clock
    ) {
    }

    public function index(Request $request, Response $response): Response
    {
        $stmt = $this->pdo->query(
            'SELECT t.*, s.id AS session_id, s.status AS session_status, s.opened_at,
                    s.planned_minutes, s.hourly_rate_snapshot AS session_hourly_rate
             FROM tables t
             LEFT JOIN sessions s ON s.table_id = t.id AND s.status IN (\'active\', \'paused\')
             WHERE t.is_active = 1
             ORDER BY t.sort_order, t.id'
        );
        $rows = $stmt->fetchAll();
        $biz = $this->pdo->query('SELECT billing_mode, billing_rounding, time_billing_enabled FROM businesses WHERE id = 1')->fetch();

        foreach ($rows as &$row) {
            if (!empty($row['session_id'])) {
                $preview = $this->buildBillPreview((int) $row['session_id'], $row, $biz);
                $row['bill_preview'] = $preview;
                $row['session_items'] = $preview['items'] ?? [];
            }
        }

        return ApiResponse::success($rows);
    }

    private function buildBillPreview(int $sessionId, array $tableRow, array $biz): array
    {
        $pauses = $this->pdo->prepare('SELECT * FROM session_pauses WHERE session_id = ? ORDER BY id');
        $pauses->execute([$sessionId]);
        $pauseRows = $pauses->fetchAll();

        $itemsStmt = $this->pdo->prepare('SELECT * FROM session_items WHERE session_id = ?');
        $itemsStmt->execute([$sessionId]);
        $items = $itemsStmt->fetchAll();

        $activeSeconds = $this->billing->calculateActiveSeconds(
            $tableRow['opened_at'],
            $this->clock->now(),
            $pauseRows
        );

        $hourlyRate = (float) ($tableRow['session_hourly_rate'] ?? $tableRow['hourly_rate']);
        $timeBilling = !isset($biz['time_billing_enabled']) || (bool) $biz['time_billing_enabled'];
        $timeCharge = $timeBilling
            ? $this->billing->calculateTimeCharge(
                $activeSeconds,
                $hourlyRate,
                $biz['billing_mode'] ?? 'per_minute',
                (float) ($biz['billing_rounding'] ?? 0.01)
            )
            : 0.0;
        $productsTotal = $this->billing->calculateProductsTotal($items);
        $total = round($timeCharge + $productsTotal, 2);
        $plannedMinutes = isset($tableRow['planned_minutes']) ? (int) $tableRow['planned_minutes'] : 0;

        $itemRows = array_map(static fn (array $i): array => [
            'product_name' => $i['product_name'],
            'quantity' => (int) $i['quantity'],
        ], $items);

        return [
            'active_seconds' => $activeSeconds,
            'active_minutes' => (int) ceil($activeSeconds / 60),
            'time_charge' => $timeCharge,
            'products_total' => $productsTotal,
            'total_amount' => $total,
            'planned_minutes' => $plannedMinutes > 0 ? $plannedMinutes : null,
            'remaining_seconds' => $plannedMinutes > 0 ? max(0, ($plannedMinutes * 60) - $activeSeconds) : null,
            'is_countdown' => $plannedMinutes > 0,
            'items' => $itemRows,
        ];
    }

    public function store(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        if (!v::key('name', v::stringType()->notEmpty())->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $stmt = $this->pdo->prepare(
            'INSERT INTO tables (business_id, name, hourly_rate, status, sort_order, is_active, created_at, updated_at)
             VALUES (1, ?, ?, \'empty\', ?, 1, NOW(), NOW())'
        );
        $stmt->execute([
            $body['name'],
            (float) ($body['hourly_rate'] ?? 5.0),
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

        foreach (['name', 'hourly_rate', 'sort_order', 'is_active'] as $key) {
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
        $this->pdo->prepare('UPDATE tables SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);

        return ApiResponse::success(['updated' => true]);
    }

    public function destroy(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $this->pdo->prepare('UPDATE tables SET is_active = 0, updated_at = NOW() WHERE id = ?')->execute([$id]);
        return ApiResponse::success(['deleted' => true]);
    }
}
