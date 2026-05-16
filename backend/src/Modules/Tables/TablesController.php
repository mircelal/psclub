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
        $this->syncTableStatusesFromSessions();

        $stmt = $this->pdo->query(
            'SELECT t.*, s.id AS session_id, s.status AS session_status, s.opened_at,
                    s.planned_minutes, s.hourly_rate_snapshot AS session_hourly_rate,
                    s.tariff_name_snapshot AS session_tariff_name,
                    s.set_name_snapshot AS session_set_name,
                    s.set_price_snapshot AS session_set_price
             FROM tables t
             LEFT JOIN sessions s ON s.table_id = t.id AND s.status IN (\'active\', \'paused\')
             WHERE t.is_active = 1
             ORDER BY t.sort_order, t.id'
        );
        $rows = $stmt->fetchAll();
        $tariffsByTable = $this->loadTariffsGrouped();
        $biz = $this->pdo->query('SELECT billing_mode, billing_rounding, time_billing_enabled FROM businesses WHERE id = 1')->fetch();

        foreach ($rows as &$row) {
            $row['tariffs'] = $tariffsByTable[(int) $row['id']] ?? [];
            if (!empty($row['session_id'])) {
                $preview = $this->buildBillPreview((int) $row['session_id'], $row, $biz);
                $row['bill_preview'] = $preview;
                $row['session_items'] = $preview['items'] ?? [];
            }
        }

        return ApiResponse::success($rows);
    }

    private function loadTariffsGrouped(): array
    {
        $stmt = $this->pdo->query(
            'SELECT id, table_id, name, hourly_rate, sort_order
             FROM table_tariffs
             WHERE is_active = 1
             ORDER BY table_id, sort_order, id'
        );
        $grouped = [];
        foreach ($stmt->fetchAll() as $tariff) {
            $tableId = (int) $tariff['table_id'];
            $grouped[$tableId][] = [
                'id' => (int) $tariff['id'],
                'name' => $tariff['name'],
                'hourly_rate' => (float) $tariff['hourly_rate'],
                'sort_order' => (int) $tariff['sort_order'],
            ];
        }

        return $grouped;
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

        $setPrice = (float) ($tableRow['session_set_price'] ?? 0);
        if ($setPrice > 0) {
            $timeCharge = round($setPrice, 2);
            $productsTotal = $this->billing->calculateProductsTotal($items, true);
        } else {
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
        }
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

        $tariffs = $this->normalizeTariffsInput($body['tariffs'] ?? null, $body);
        if ($tariffs === []) {
            return ApiResponse::error('At least one tariff is required', 422);
        }

        $firstRate = (float) $tariffs[0]['hourly_rate'];

        $this->pdo->beginTransaction();
        try {
            $stmt = $this->pdo->prepare(
                'INSERT INTO tables (business_id, name, hourly_rate, status, sort_order, is_active, created_at, updated_at)
                 VALUES (1, ?, ?, \'empty\', ?, 1, NOW(), NOW())'
            );
            $stmt->execute([
                $body['name'],
                $firstRate,
                (int) ($body['sort_order'] ?? 0),
            ]);
            $tableId = (int) $this->pdo->lastInsertId();
            $this->syncTariffs($tableId, $tariffs);
            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            throw $e;
        }

        return ApiResponse::success(['id' => $tableId], [], 201);
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

        if (array_key_exists('tariffs', $body)) {
            $tariffs = $this->normalizeTariffsInput($body['tariffs'], $body);
            if ($tariffs === []) {
                return ApiResponse::error('At least one tariff is required', 422);
            }
            $fields[] = 'hourly_rate = ?';
            $params[] = (float) $tariffs[0]['hourly_rate'];
        }

        if ($fields !== []) {
            $fields[] = 'updated_at = NOW()';
            $params[] = $id;
            $this->pdo->prepare('UPDATE tables SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);
        }

        if (array_key_exists('tariffs', $body)) {
            $this->syncTariffs($id, $this->normalizeTariffsInput($body['tariffs'], $body));
        }

        if ($fields === [] && !array_key_exists('tariffs', $body)) {
            return ApiResponse::error('No fields', 422);
        }

        return ApiResponse::success(['updated' => true]);
    }

    public function destroy(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $this->pdo->prepare('UPDATE tables SET is_active = 0, updated_at = NOW() WHERE id = ?')->execute([$id]);
        return ApiResponse::success(['deleted' => true]);
    }

    /** @return list<array{name: string, hourly_rate: float, sort_order: int}> */
    private function normalizeTariffsInput(mixed $tariffs, array $body): array
    {
        if (is_array($tariffs) && $tariffs !== []) {
            $normalized = [];
            $order = 0;
            foreach ($tariffs as $row) {
                if (!is_array($row)) {
                    continue;
                }
                $name = trim((string) ($row['name'] ?? ''));
                if ($name === '') {
                    continue;
                }
                $rate = (float) ($row['hourly_rate'] ?? 0);
                if ($rate <= 0) {
                    continue;
                }
                $normalized[] = [
                    'name' => $name,
                    'hourly_rate' => $rate,
                    'sort_order' => (int) ($row['sort_order'] ?? $order++),
                ];
            }

            return $normalized;
        }

        if (isset($body['hourly_rate']) && (float) $body['hourly_rate'] > 0) {
            return [[
                'name' => 'Standart',
                'hourly_rate' => (float) $body['hourly_rate'],
                'sort_order' => 0,
            ]];
        }

        return [];
    }

    /**
     * Masa statusunu açıq sessiyalarla uyğunlaşdırır (köhnə/uyğunsuz qeydləri düzəldir).
     */
    private function syncTableStatusesFromSessions(): void
    {
        $this->pdo->exec(
            "UPDATE tables t
             INNER JOIN sessions s ON s.table_id = t.id AND s.status IN ('active', 'paused')
             SET t.status = s.status, t.updated_at = NOW()
             WHERE t.is_active = 1 AND (t.status NOT IN ('active', 'paused') OR t.status <> s.status)"
        );

        $this->pdo->exec(
            "UPDATE tables t
             SET t.status = 'empty', t.updated_at = NOW()
             WHERE t.is_active = 1
               AND t.status IN ('active', 'paused')
               AND NOT EXISTS (
                   SELECT 1 FROM sessions s
                   WHERE s.table_id = t.id AND s.status IN ('active', 'paused')
               )"
        );

        // Tərk edilmiş boş birbaşa satışlar (masa deyil) — 30 dəq+ heç nə əlavə olunmayıb
        $this->pdo->exec(
            "UPDATE sessions
             SET status = 'closed', closed_at = NOW(), time_charge = 0, products_total = 0,
                 total_amount = 0, active_seconds = 0, updated_at = NOW()
             WHERE status IN ('active', 'paused')
               AND table_id IS NULL
               AND opened_at < DATE_SUB(NOW(), INTERVAL 30 MINUTE)
               AND NOT EXISTS (SELECT 1 FROM session_items si WHERE si.session_id = sessions.id)"
        );
    }

    /** @param list<array{name: string, hourly_rate: float, sort_order: int}> $tariffs */
    private function syncTariffs(int $tableId, array $tariffs): void
    {
        $this->pdo->prepare('DELETE FROM table_tariffs WHERE table_id = ?')->execute([$tableId]);
        $stmt = $this->pdo->prepare(
            'INSERT INTO table_tariffs (table_id, name, hourly_rate, sort_order, is_active, created_at, updated_at)
             VALUES (?, ?, ?, ?, 1, NOW(), NOW())'
        );
        foreach ($tariffs as $tariff) {
            $stmt->execute([
                $tableId,
                $tariff['name'],
                $tariff['hourly_rate'],
                $tariff['sort_order'],
            ]);
        }
    }
}
