<?php

declare(strict_types=1);

namespace App\Modules\Sessions;

use App\Modules\Coupons\CouponsController;
use App\Modules\SessionSets\SessionSetsController;
use App\Modules\Shifts\ShiftService;
use App\Modules\Shifts\ShiftsController;
use App\Modules\Stock\StockController;
use App\Support\ApiResponse;
use App\Support\BusinessBillingColumns;
use App\Support\BillingCalculator;
use App\Support\DatabaseClock;
use App\Support\DbSchema;
use App\Support\DiscountCalculator;
use App\Support\LoyaltyService;
use App\Support\PromotionService;
use App\Support\SessionCloseRules;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class SessionsController
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly BillingCalculator $billing,
        private readonly DatabaseClock $clock,
        private readonly StockController $stock,
        private readonly ReceiptService $receipts,
        private readonly SessionSetsController $sessionSets,
        private readonly ShiftService $shifts,
        private readonly PromotionService $promotions,
        private readonly LoyaltyService $loyalty,
    ) {
    }

    public function active(Request $request, Response $response): Response
    {
        $stmt = $this->pdo->query(
            "SELECT s.*, t.name AS table_name, t.status AS table_status,
                    c.name AS customer_name, c.phone AS customer_phone,
                    cp.code AS coupon_code
             FROM sessions s
             LEFT JOIN tables t ON t.id = s.table_id
             LEFT JOIN customers c ON c.id = s.customer_id
             LEFT JOIN coupons cp ON cp.id = s.coupon_id
             WHERE s.status IN ('active', 'paused')
             ORDER BY s.opened_at"
        );
        $sessions = $stmt->fetchAll();
        foreach ($sessions as &$session) {
            $session = $this->enrichSession($session);
        }
        return ApiResponse::success($sessions);
    }

    public function show(Request $request, Response $response, array $args): Response
    {
        $session = $this->findSession((int) $args['id']);
        if (!$session) {
            return ApiResponse::error('Session not found', 404);
        }
        return ApiResponse::success([
            'server_now' => $this->clock->nowIso(),
            'session' => $this->enrichSession($session),
        ]);
    }

    public function store(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');
        if ($denied = ShiftsController::assertCashierHasOpenShift($this->shifts, $user)) {
            return $denied;
        }
        $sessionType = ($body['session_type'] ?? 'table') === 'counter' ? 'counter' : 'table';
        $customerId = isset($body['customer_id']) && (int) $body['customer_id'] > 0 ? (int) $body['customer_id'] : null;

        if ($customerId !== null && !$this->customerExists($customerId)) {
            return ApiResponse::error('Customer not found', 404);
        }

        if ($sessionType === 'counter') {
            $this->pdo->prepare(
                'INSERT INTO sessions (business_id, table_id, session_type, customer_id, opened_by, status, opened_at, hourly_rate_snapshot, created_at, updated_at)
                 VALUES (1, NULL, \'counter\', ?, ?, \'active\', NOW(), 0, NOW(), NOW())'
            )->execute([$customerId, (int) $user['id']]);
            $sessionId = (int) $this->pdo->lastInsertId();

            return ApiResponse::success($this->enrichSession($this->findSession($sessionId)), [], 201);
        }

        if (!v::key('table_id', v::intVal()->positive())->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $tableId = (int) $body['table_id'];
        $table = $this->pdo->prepare('SELECT * FROM tables WHERE id = ? AND is_active = 1');
        $table->execute([$tableId]);
        $tableRow = $table->fetch();
        if (!$tableRow) {
            return ApiResponse::error('Table not found', 404);
        }
        if ($tableRow['status'] !== 'empty') {
            return ApiResponse::error('Table is not empty', 409);
        }

        $check = $this->pdo->prepare("SELECT id FROM sessions WHERE table_id = ? AND status IN ('active','paused')");
        $check->execute([$tableId]);
        if ($check->fetch()) {
            return ApiResponse::error('Table already has active session', 409);
        }

        $setId = isset($body['set_id']) ? (int) $body['set_id'] : null;
        $setRow = $setId > 0 ? $this->sessionSets->findSet($setId) : null;
        if ($setId > 0 && $setRow === null) {
            return ApiResponse::error('Set not found', 404);
        }

        $setName = null;
        $setPrice = null;
        $plannedMinutes = isset($body['planned_minutes']) && (int) $body['planned_minutes'] > 0
            ? (int) $body['planned_minutes']
            : null;

        if ($setRow !== null) {
            $setName = (string) $setRow['name'];
            $setPrice = (float) $setRow['fixed_price'];
            if (!empty($setRow['planned_minutes'])) {
                $plannedMinutes = (int) $setRow['planned_minutes'];
            }
            $hourlyRate = 0.0;
            $tariffIdFinal = null;
            $tariffName = null;
        } else {
            $tariffId = isset($body['tariff_id']) ? (int) $body['tariff_id'] : null;
            $resolved = $this->resolveTableTariff($tableId, $tariffId);
            if ($resolved === false) {
                return ApiResponse::error('Tariff is required', 422, ['code' => 'tariff_required']);
            }

            [$hourlyRate, $tariffIdFinal, $tariffName] = $resolved;
        }

        $timing = $this->businessTiming();
        if ($setRow === null && $plannedMinutes !== null) {
            if ($plannedMinutes < $timing['min_open_minutes']) {
                return ApiResponse::error(
                    'Minimum açılış müddəti ' . $timing['min_open_minutes'] . ' dəqiqədir',
                    422,
                    ['code' => 'min_open_minutes', 'min' => $timing['min_open_minutes']]
                );
            }
            if ($plannedMinutes > 180) {
                return ApiResponse::error(
                    'Maksimum açılış müddəti 3 saatdır (180 dəqiqə)',
                    422,
                    ['code' => 'max_open_minutes', 'max' => 180]
                );
            }
            $overMin = $plannedMinutes - $timing['min_open_minutes'];
            if ($overMin % $timing['extend_step_minutes'] !== 0) {
                return ApiResponse::error(
                    'Müddət ' . $timing['min_open_minutes'] . ' dəq minimum, sonra hər '
                    . $timing['extend_step_minutes'] . ' dəq addım ilə seçilməlidir',
                    422,
                    ['code' => 'open_minutes_step', 'step' => $timing['extend_step_minutes']]
                );
            }
        }

        $this->pdo->beginTransaction();
        try {
            $this->pdo->prepare(
                'INSERT INTO sessions (business_id, table_id, session_type, customer_id, opened_by, status, opened_at, hourly_rate_snapshot, tariff_id, tariff_name_snapshot, set_id, set_name_snapshot, set_price_snapshot, planned_minutes, created_at, updated_at)
                 VALUES (1, ?, \'table\', ?, ?, \'active\', NOW(), ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())'
            )->execute([
                $tableId,
                $customerId,
                (int) $user['id'],
                $hourlyRate,
                $tariffIdFinal,
                $tariffName,
                $setId > 0 ? $setId : null,
                $setName,
                $setPrice,
                $plannedMinutes,
            ]);
            $sessionId = (int) $this->pdo->lastInsertId();
            if ($setRow !== null) {
                $this->applySessionSetItems($sessionId, $setRow, (int) $user['id']);
            }
            $this->pdo->prepare("UPDATE tables SET status = 'active', updated_at = NOW() WHERE id = ?")->execute([$tableId]);
            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            throw $e;
        }

        return ApiResponse::success($this->enrichSession($this->findSession($sessionId)), [], 201);
    }

    public function setDiscount(Request $request, Response $response, array $args): Response
    {
        $user = $request->getAttribute('user');
        if ($denied = ShiftsController::assertCashierHasOpenShift($this->shifts, $user)) {
            return $denied;
        }

        $sessionId = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        $session = $this->findSession($sessionId);
        if (!$session || !in_array($session['status'], ['active', 'paused'], true)) {
            return ApiResponse::error('Session not active', 400);
        }

        $type = $body['discount_type'] ?? 'none';
        if (!in_array($type, ['none', 'fixed', 'percent'], true)) {
            return ApiResponse::error('Invalid discount type', 422);
        }

        $value = (float) ($body['discount_value'] ?? 0);
        if ($type === 'none') {
            $value = 0;
        }

        $appliesTo = $body['discount_applies_to'] ?? 'time_only';
        if (!in_array($appliesTo, ['all', 'time_only'], true)) {
            return ApiResponse::error('Invalid discount scope', 422);
        }

        $bill = $this->calculateBill($session);
        $timeCharge = (float) $bill['time_charge'];
        $subtotal = $timeCharge + (float) $bill['products_total'];
        $base = $appliesTo === 'time_only' ? $timeCharge : $subtotal;

        if ($type !== 'none') {
            $isGift = ($session['session_type'] ?? 'table') === 'counter'
                && $type === 'percent'
                && $value >= 100
                && $appliesTo === 'all';
            $limitError = $this->promotions->validateManualDiscount($user, $type, $value, $base, $isGift);
            if ($limitError !== null) {
                return ApiResponse::error($limitError, 422);
            }
        }

        $discountAmount = $type === 'none'
            ? 0.0
            : DiscountCalculator::amount($base, $type, $value);

        $this->pdo->prepare(
            'UPDATE sessions SET discount_type = ?, discount_value = ?, discount = ?, discount_applies_to = ?, coupon_id = NULL, promotion_id = NULL, updated_at = NOW() WHERE id = ?'
        )->execute([$type, $value, $discountAmount, $appliesTo, $sessionId]);

        return ApiResponse::success($this->enrichSession($this->findSession($sessionId)));
    }

    public function assignCustomer(Request $request, Response $response, array $args): Response
    {
        $user = $request->getAttribute('user');
        if ($denied = ShiftsController::assertCashierHasOpenShift($this->shifts, $user)) {
            return $denied;
        }

        $sessionId = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        if (!array_key_exists('customer_id', $body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $session = $this->findSession($sessionId);
        if (!$session || !in_array($session['status'], ['active', 'paused'], true)) {
            return ApiResponse::error('Session not active', 400);
        }

        $raw = $body['customer_id'];
        $customerId = null;
        if ($raw !== null && $raw !== '' && (int) $raw > 0) {
            $customerId = (int) $raw;
            if (!$this->customerExists($customerId)) {
                return ApiResponse::error('Customer not found', 404);
            }
        }

        $this->pdo->prepare('UPDATE sessions SET customer_id = ?, updated_at = NOW() WHERE id = ?')
            ->execute([$customerId, $sessionId]);

        return ApiResponse::success($this->enrichSession($this->findSession($sessionId)));
    }

    public function applyCoupon(Request $request, Response $response, array $args): Response
    {
        $user = $request->getAttribute('user');
        if ($denied = ShiftsController::assertCashierHasOpenShift($this->shifts, $user)) {
            return $denied;
        }

        $sessionId = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        if (!v::key('code', v::stringType()->notEmpty())->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $session = $this->findSession($sessionId);
        if (!$session || !in_array($session['status'], ['active', 'paused'], true)) {
            return ApiResponse::error('Session not active', 400);
        }

        $code = strtoupper(trim($body['code']));
        $stmt = $this->pdo->prepare('SELECT * FROM coupons WHERE code = ?');
        $stmt->execute([$code]);
        $coupon = $stmt->fetch();
        if (!$coupon) {
            return ApiResponse::error('Kupon tapılmadı', 404);
        }

        $coupons = new CouponsController($this->pdo);
        $error = $coupons->validateCoupon($coupon);
        if ($error !== null) {
            return ApiResponse::error($error, 400);
        }

        $bill = $this->calculateBill($session);
        $timeCharge = (float) $bill['time_charge'];
        $type = $coupon['discount_type'];
        $value = (float) $coupon['discount_value'];
        $discountAmount = DiscountCalculator::amount($timeCharge, $type, $value);

        $this->pdo->prepare(
            'UPDATE sessions SET discount_type = ?, discount_value = ?, discount = ?, discount_applies_to = \'time_only\', coupon_id = ?, promotion_id = NULL, updated_at = NOW() WHERE id = ?'
        )->execute([$type, $value, $discountAmount, (int) $coupon['id'], $sessionId]);

        return ApiResponse::success($this->enrichSession($this->findSession($sessionId)));
    }

    public function clearDiscount(Request $request, Response $response, array $args): Response
    {
        $user = $request->getAttribute('user');
        if ($denied = ShiftsController::assertCashierHasOpenShift($this->shifts, $user)) {
            return $denied;
        }

        $sessionId = (int) $args['id'];
        $session = $this->findSession($sessionId);
        if (!$session || !in_array($session['status'], ['active', 'paused'], true)) {
            return ApiResponse::error('Session not active', 400);
        }

        $this->pdo->prepare(
            'UPDATE sessions SET discount_type = \'none\', discount_value = 0, discount = 0, coupon_id = NULL, promotion_id = NULL, updated_at = NOW() WHERE id = ?'
        )->execute([$sessionId]);

        return ApiResponse::success($this->enrichSession($this->findSession($sessionId)));
    }

    public function addItem(Request $request, Response $response, array $args): Response
    {
        $sessionId = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');
        if ($denied = ShiftsController::assertCashierHasOpenShift($this->shifts, $user)) {
            return $denied;
        }

        if (!v::key('product_id', v::intVal())->key('quantity', v::intVal()->positive())->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $session = $this->findSession($sessionId);
        if (!$session || !in_array($session['status'], ['active', 'paused'], true)) {
            return ApiResponse::error('Session not active', 400);
        }

        $productId = (int) $body['product_id'];
        $qty = (int) $body['quantity'];

        $pstmt = $this->pdo->prepare('SELECT * FROM products WHERE id = ? AND is_active = 1');
        $pstmt->execute([$productId]);
        $product = $pstmt->fetch();
        if (!$product) {
            return ApiResponse::error('Product not found', 404);
        }

        $this->pdo->beginTransaction();
        try {
            $existing = $this->pdo->prepare(
                'SELECT id, quantity FROM session_items WHERE session_id = ? AND product_id = ? LIMIT 1'
            );
            $existing->execute([$sessionId, $productId]);
            $row = $existing->fetch();

            $this->stock->applyStockChange($productId, 'sale', $qty, 'sale', 'session', $sessionId, (int) $user['id']);

            if ($row) {
                $newQty = (int) $row['quantity'] + $qty;
                $this->pdo->prepare('UPDATE session_items SET quantity = ? WHERE id = ?')
                    ->execute([$newQty, (int) $row['id']]);
            } else {
                $this->pdo->prepare(
                    'INSERT INTO session_items (session_id, product_id, product_name, quantity, unit_price, is_set_item, created_at)
                     VALUES (?, ?, ?, ?, ?, 0, NOW())'
                )->execute([$sessionId, $productId, $product['name'], $qty, (float) $product['price']]);
            }
            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            return ApiResponse::error($e->getMessage(), 400);
        }

        return ApiResponse::success($this->enrichSession($this->findSession($sessionId)));
    }

    public function updateItem(Request $request, Response $response, array $args): Response
    {
        $sessionId = (int) $args['id'];
        $itemId = (int) $args['itemId'];
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');
        if ($denied = ShiftsController::assertCashierHasOpenShift($this->shifts, $user)) {
            return $denied;
        }

        if (!v::key('quantity', v::intVal())->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $session = $this->findSession($sessionId);
        if (!$session || !in_array($session['status'], ['active', 'paused'], true)) {
            return ApiResponse::error('Session not active', 400);
        }

        $itemStmt = $this->pdo->prepare('SELECT * FROM session_items WHERE id = ? AND session_id = ?');
        $itemStmt->execute([$itemId, $sessionId]);
        $item = $itemStmt->fetch();
        if (!$item) {
            return ApiResponse::error('Item not found', 404);
        }

        $newQty = (int) $body['quantity'];
        $oldQty = (int) $item['quantity'];
        $productId = (int) $item['product_id'];

        $this->pdo->beginTransaction();
        try {
            if ($newQty <= 0) {
                if ($productId > 0) {
                    $this->stock->applyStockChange($productId, 'in', $oldQty, 'return', 'session', $sessionId, (int) $user['id']);
                }
                $this->pdo->prepare('DELETE FROM session_items WHERE id = ?')->execute([$itemId]);
            } else {
                $delta = $newQty - $oldQty;
                if ($delta !== 0 && $productId > 0) {
                    if ($delta > 0) {
                        $this->stock->applyStockChange($productId, 'sale', $delta, 'sale', 'session', $sessionId, (int) $user['id']);
                    } else {
                        $this->stock->applyStockChange($productId, 'in', abs($delta), 'return', 'session', $sessionId, (int) $user['id']);
                    }
                }
                $this->pdo->prepare('UPDATE session_items SET quantity = ? WHERE id = ?')->execute([$newQty, $itemId]);
            }
            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            return ApiResponse::error($e->getMessage(), 400);
        }

        return ApiResponse::success($this->enrichSession($this->findSession($sessionId)));
    }

    public function removeItem(Request $request, Response $response, array $args): Response
    {
        $sessionId = (int) $args['id'];
        $itemId = (int) $args['itemId'];
        $user = $request->getAttribute('user');
        if ($denied = ShiftsController::assertCashierHasOpenShift($this->shifts, $user)) {
            return $denied;
        }

        $session = $this->findSession($sessionId);
        if (!$session || !in_array($session['status'], ['active', 'paused'], true)) {
            return ApiResponse::error('Session not active', 400);
        }

        $itemStmt = $this->pdo->prepare('SELECT * FROM session_items WHERE id = ? AND session_id = ?');
        $itemStmt->execute([$itemId, $sessionId]);
        $item = $itemStmt->fetch();
        if (!$item) {
            return ApiResponse::error('Item not found', 404);
        }

        if (!empty($item['is_set_item'])) {
            return ApiResponse::error('Paket məhsulları səbətdən silinə bilməz', 400);
        }

        $this->pdo->beginTransaction();
        try {
            $productId = (int) ($item['product_id'] ?? 0);
            $qty = (int) $item['quantity'];
            if ($productId > 0 && $qty > 0) {
                $this->stock->applyStockChange($productId, 'in', $qty, 'return', 'session', $sessionId, (int) $user['id']);
            }
            $this->pdo->prepare('DELETE FROM session_items WHERE id = ? AND session_id = ?')->execute([$itemId, $sessionId]);
            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            return ApiResponse::error($e->getMessage(), 400);
        }

        return ApiResponse::success($this->enrichSession($this->findSession($sessionId)));
    }

    public function pause(Request $request, Response $response, array $args): Response
    {
        return $this->togglePause($request, (int) $args['id'], true);
    }

    public function resume(Request $request, Response $response, array $args): Response
    {
        return $this->togglePause($request, (int) $args['id'], false);
    }

    public function extendPlannedTime(Request $request, Response $response, array $args): Response
    {
        $sessionId = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');
        if ($denied = ShiftsController::assertCashierHasOpenShift($this->shifts, $user)) {
            return $denied;
        }

        $session = $this->findSession($sessionId);
        if (!$session || !in_array($session['status'], ['active', 'paused'], true)) {
            return ApiResponse::error('Session not active', 400);
        }

        $currentPlanned = isset($session['planned_minutes']) ? (int) $session['planned_minutes'] : 0;
        if ($currentPlanned <= 0) {
            return ApiResponse::error('Müddətsiz sessiya uzadıla bilməz', 400);
        }

        if (!empty($session['set_id']) || (float) ($session['set_price_snapshot'] ?? 0) > 0) {
            return ApiResponse::error('Paket sessiyasında müddət uzadıla bilməz — sabit paket qiyməti', 400);
        }

        $timing = $this->businessTiming();
        $add = (int) ($body['add_minutes'] ?? $timing['extend_step_minutes']);
        if ($add !== $timing['extend_step_minutes']) {
            return ApiResponse::error(
                'Yalnız ' . $timing['extend_step_minutes'] . ' dəqiqəlik uzatma mümkündür',
                422
            );
        }

        $bill = $this->calculateBill($session);
        $activeSeconds = (int) $bill['active_seconds'];
        $minSeconds = $timing['min_open_minutes'] * 60;
        $remaining = $bill['remaining_seconds'] ?? null;
        $firstHourDone = $activeSeconds >= $minSeconds;
        $expired = $remaining !== null && $remaining <= 0;

        if (!$firstHourDone && !$expired) {
            return ApiResponse::error(
                'İlk ' . $timing['min_open_minutes'] . ' dəqiqə bitməyib — uzatma hələ aktiv deyil',
                400
            );
        }

        $newPlanned = $currentPlanned + $add;
        $this->pdo->prepare('UPDATE sessions SET planned_minutes = ?, updated_at = NOW() WHERE id = ?')
            ->execute([$newPlanned, $sessionId]);

        return ApiResponse::success($this->enrichSession($this->findSession($sessionId)));
    }

    private function togglePause(Request $request, int $sessionId, bool $pause): Response
    {
        $user = $request->getAttribute('user');
        if ($denied = ShiftsController::assertCashierHasOpenShift($this->shifts, $user)) {
            return $denied;
        }

        $session = $this->findSession($sessionId);
        if (!$session) {
            return ApiResponse::error('Session not found', 404);
        }

        if (($session['session_type'] ?? 'table') === 'counter') {
            return ApiResponse::error('Counter sales cannot be paused', 400);
        }

        if ($pause && $session['status'] === 'active') {
            $this->pdo->prepare("UPDATE sessions SET status = 'paused', updated_at = NOW() WHERE id = ?")->execute([$sessionId]);
            $this->pdo->prepare('INSERT INTO session_pauses (session_id, paused_at) VALUES (?, NOW())')->execute([$sessionId]);
            if (!empty($session['table_id'])) {
                $this->pdo->prepare("UPDATE tables SET status = 'paused', updated_at = NOW() WHERE id = ?")->execute([$session['table_id']]);
            }
        } elseif (!$pause && $session['status'] === 'paused') {
            $this->pdo->prepare("UPDATE sessions SET status = 'active', updated_at = NOW() WHERE id = ?")->execute([$sessionId]);
            $this->pdo->prepare(
                'UPDATE session_pauses SET resumed_at = NOW() WHERE session_id = ? AND resumed_at IS NULL ORDER BY id DESC LIMIT 1'
            )->execute([$sessionId]);
            if (!empty($session['table_id'])) {
                $this->pdo->prepare("UPDATE tables SET status = 'active', updated_at = NOW() WHERE id = ?")->execute([$session['table_id']]);
            }
        } else {
            return ApiResponse::error('Invalid pause state', 400);
        }

        return ApiResponse::success($this->enrichSession($this->findSession($sessionId)));
    }

    public function preview(Request $request, Response $response, array $args): Response
    {
        $session = $this->findSession((int) $args['id']);
        if (!$session) {
            return ApiResponse::error('Session not found', 404);
        }
        return ApiResponse::success($this->calculateBill($session));
    }

    public function close(Request $request, Response $response, array $args): Response
    {
        $sessionId = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');

        $validation = v::key('method', v::in(['cash', 'card', 'mixed']));
        if (!$validation->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $session = $this->findSession($sessionId);
        if (!$session || $session['status'] === 'closed') {
            return ApiResponse::error('Session not found or already closed', 400);
        }
        if ($denied = ShiftsController::assertCashierHasOpenShift($this->shifts, $user)) {
            return $denied;
        }

        $openShift = $this->shifts->getOpenShift((int) $user['business_id']);
        $shiftId = $openShift ? (int) $openShift['id'] : null;

        $session = $this->syncDiscount($session);
        $closedAt = $this->clock->now();
        $bill = $this->calculateBill($session, closingAt: $closedAt);

        $redeemMinutes = max(0, (int) ($body['redeem_bonus_minutes'] ?? 0));
        $redeemWallet = max(0, (float) ($body['redeem_bonus_wallet'] ?? 0));
        $customerId = (int) ($session['customer_id'] ?? 0);
        if (($redeemMinutes > 0 || $redeemWallet > 0) && $customerId <= 0) {
            return ApiResponse::error('Bonus üçün müştəri təyin edilməlidir', 422);
        }
        if (($redeemMinutes > 0 || $redeemWallet > 0) && !$this->loyalty->tablesExist()) {
            return ApiResponse::error('Loyallıq cədvəlləri mövcud deyil — miqrasiya işlədin', 503);
        }
        $balance = $customerId > 0 ? $this->loyalty->getBalance($customerId) : null;
        $bill = $this->loyalty->applyBonusToBill(
            $bill,
            $redeemMinutes,
            $redeemWallet,
            (float) ($session['hourly_rate_snapshot'] ?? 0),
            $balance
        );

        $cash = (float) ($body['cash_amount'] ?? 0);
        $card = (float) ($body['card_amount'] ?? 0);
        $total = (float) $bill['total_amount'];

        if ($body['method'] === 'cash') {
            $cash = $total;
            $card = 0;
        } elseif ($body['method'] === 'card') {
            $cash = 0;
            $card = $total;
        }

        if (round($cash + $card, 2) < round($total, 2)) {
            return ApiResponse::error('Payment amounts do not match total', 422);
        }

        $bonusUsed = (int) ($bill['bonus_minutes_used'] ?? 0) > 0 || (float) ($bill['bonus_wallet_used'] ?? 0) > 0;
        if ($bonusUsed && !DbSchema::hasColumn($this->pdo, 'sessions', 'bonus_wallet_used')) {
            return ApiResponse::error('Bonus ödənişi üçün miqrasiya işlədin', 503);
        }

        $isCounter = ($session['session_type'] ?? 'table') === 'counter';
        if ($isCounter) {
            $itemStmt = $this->pdo->prepare('SELECT COUNT(*) FROM session_items WHERE session_id = ?');
            $itemStmt->execute([$sessionId]);
            $itemCount = (int) $itemStmt->fetchColumn();
            $giftNote = trim((string) ($body['gift_note'] ?? ''));
            $zeroError = SessionCloseRules::counterZeroTotalError(
                $itemCount,
                $total,
                (float) $bill['discount'],
                (float) ($bill['bonus_wallet_used'] ?? 0),
                (int) ($bill['bonus_minutes_used'] ?? 0),
                $giftNote
            );
            if ($zeroError !== null) {
                return ApiResponse::error($zeroError, 422);
            }
            $hasGift = (float) $bill['discount'] > 0 && round($total, 2) <= 0 && $giftNote !== '';
            if ($hasGift && !DbSchema::hasColumn($this->pdo, 'sessions', 'gift_note')) {
                return ApiResponse::error('Hədiyyə qeydi üçün miqrasiya işlədin', 503);
            }
            if ($itemCount > 0 && round($cash + $card, 2) < round($total, 2)) {
                return ApiResponse::error('Birbaşa satış üçün tam ödəniş tələb olunur', 422);
            }
        }

        $this->pdo->beginTransaction();
        try {
            $sets = [
                "status = 'closed'",
                'closed_at = ?',
                'closed_by = ?',
                'time_charge = ?',
                'products_total = ?',
                'discount = ?',
                'total_amount = ?',
                'active_seconds = ?',
            ];
            $closeParams = [
                $closedAt,
                (int) $user['id'],
                $bill['time_charge'],
                $bill['products_total'],
                $bill['discount'],
                $total,
                $bill['active_seconds'],
            ];
            if (DbSchema::hasColumn($this->pdo, 'sessions', 'bonus_minutes_used')) {
                $sets[] = 'bonus_minutes_used = ?';
                $sets[] = 'bonus_wallet_used = ?';
                $closeParams[] = (int) ($bill['bonus_minutes_used'] ?? 0);
                $closeParams[] = (float) ($bill['bonus_wallet_used'] ?? 0);
            }
            if (DbSchema::hasColumn($this->pdo, 'sessions', 'gift_note')) {
                $sets[] = 'gift_note = ?';
                $giftNoteToStore = trim((string) ($body['gift_note'] ?? ''));
                $closeParams[] = $giftNoteToStore !== '' ? $giftNoteToStore : null;
            }
            $sets[] = 'updated_at = NOW()';
            $closeParams[] = $sessionId;
            $this->pdo->prepare(
                'UPDATE sessions SET ' . implode(', ', $sets) . ' WHERE id = ?'
            )->execute($closeParams);

            $this->pdo->prepare(
                'INSERT INTO payments (session_id, shift_id, method, cash_amount, card_amount, total_amount, created_at)
                 VALUES (?, ?, ?, ?, ?, ?, NOW())'
            )->execute([$sessionId, $shiftId, $body['method'], $cash, $card, $total]);

            if (!empty($session['table_id'])) {
                $this->pdo->prepare("UPDATE tables SET status = 'empty', updated_at = NOW() WHERE id = ?")
                    ->execute([$session['table_id']]);
            }

            if ($customerId > 0) {
                $this->loyalty->commitRedemption(
                    $customerId,
                    $sessionId,
                    (int) ($bill['bonus_minutes_used'] ?? 0),
                    (float) ($bill['bonus_wallet_used'] ?? 0),
                    (int) $user['id']
                );
            }

            if (!empty($session['coupon_id']) && (float) $bill['discount'] > 0) {
                $couponId = (int) $session['coupon_id'];
                $this->pdo->prepare('UPDATE coupons SET used_count = used_count + 1, updated_at = NOW() WHERE id = ?')
                    ->execute([$couponId]);
                $this->pdo->prepare(
                    'INSERT INTO coupon_redemptions (coupon_id, session_id, discount_amount, redeemed_at) VALUES (?, ?, ?, NOW())'
                )->execute([$couponId, $sessionId, $bill['discount']]);
            }

            $openPause = $this->pdo->prepare('SELECT id FROM session_pauses WHERE session_id = ? AND resumed_at IS NULL');
            $openPause->execute([$sessionId]);
            if ($openPause->fetch()) {
                $this->pdo->prepare(
                    'UPDATE session_pauses SET resumed_at = NOW() WHERE session_id = ? AND resumed_at IS NULL'
                )->execute([$sessionId]);
            }

            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            throw $e;
        }

        $closed = $this->findSession($sessionId);
        $receipt = $this->receipts->buildReceipt($closed, $bill, $body['method'], $cash, $card);

        return ApiResponse::success([
            'session' => $this->enrichSession($closed),
            'bill' => $bill,
            'receipt' => $receipt,
        ]);
    }

    private function findSession(int $id): ?array
    {
        $stmt = $this->pdo->prepare(
            'SELECT s.*, t.name AS table_name,
                    c.name AS customer_name, c.phone AS customer_phone, c.customer_group_id,
                    cp.code AS coupon_code, cp.name AS coupon_name
             FROM sessions s
             LEFT JOIN tables t ON t.id = s.table_id
             LEFT JOIN customers c ON c.id = s.customer_id
             LEFT JOIN coupons cp ON cp.id = s.coupon_id
             WHERE s.id = ?'
        );
        $stmt->execute([$id]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    private function customerExists(int $id): bool
    {
        $stmt = $this->pdo->prepare('SELECT id FROM customers WHERE id = ? AND is_active = 1');
        $stmt->execute([$id]);

        return (bool) $stmt->fetch();
    }

    private function syncDiscount(array $session): array
    {
        $type = $session['discount_type'] ?? 'none';
        if ($type === 'none') {
            return $session;
        }
        $bill = $this->calculateBill($session);
        $timeCharge = (float) $bill['time_charge'];
        $subtotal = $timeCharge + (float) $bill['products_total'];
        $appliesTo = $session['discount_applies_to'] ?? 'time_only';
        $base = $appliesTo === 'time_only' ? $timeCharge : $subtotal;
        $value = (float) ($session['discount_value'] ?? 0);
        $amount = DiscountCalculator::amount($base, $type, $value);
        if (abs($amount - (float) ($session['discount'] ?? 0)) > 0.001) {
            $this->pdo->prepare('UPDATE sessions SET discount = ?, updated_at = NOW() WHERE id = ?')
                ->execute([$amount, (int) $session['id']]);
            $session['discount'] = $amount;
        }

        return $session;
    }

    private function getPauses(int $sessionId): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM session_pauses WHERE session_id = ? ORDER BY id');
        $stmt->execute([$sessionId]);
        return $stmt->fetchAll();
    }

    private function getItems(int $sessionId): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT si.*, p.image_url, pc.name AS category_name
             FROM session_items si
             LEFT JOIN products p ON p.id = si.product_id
             LEFT JOIN product_categories pc ON pc.id = p.category_id
             WHERE si.session_id = ?
             ORDER BY si.id'
        );
        $stmt->execute([$sessionId]);
        return $stmt->fetchAll();
    }

    private function enrichSession(array $session): array
    {
        $session = $this->syncDiscount($session);
        $session['pauses'] = $this->getPauses((int) $session['id']);
        $session['items'] = $this->getItems((int) $session['id']);
        $session['bill_preview'] = $this->calculateBill($session);
        $promo = $this->promotions->findBestForSession($session, (float) ($session['bill_preview']['time_charge'] ?? 0));
        $session['active_promotion'] = $promo ? [
            'id' => (int) $promo['id'],
            'name' => $promo['name'],
            'discount_type' => $promo['discount_type'],
            'discount_value' => (float) $promo['discount_value'],
        ] : null;
        $session['active_customer_group'] = $session['bill_preview']['active_customer_group'] ?? null;
        if (($session['session_type'] ?? 'table') === 'counter' && empty($session['table_name'])) {
            $session['table_name'] = 'Kassa satışı';
        }
        $bonus = $this->loyalty->getBalance((int) ($session['customer_id'] ?? 0));
        $session['customer_bonus_minutes'] = $bonus['bonus_minutes'];
        $session['customer_bonus_wallet'] = $bonus['bonus_wallet'];
        return $session;
    }

    private function calculateBill(array $session, ?string $closingAt = null): array
    {
        $pauses = $this->getPauses((int) $session['id']);
        $items = $this->getItems((int) $session['id']);
        $endAt = $closingAt ?? $session['closed_at'] ?? $this->clock->now();

        $activeSeconds = $this->billing->calculateActiveSeconds(
            $session['opened_at'],
            $endAt,
            $pauses
        );

        $isCounter = ($session['session_type'] ?? 'table') === 'counter';
        $bizSelect = BusinessBillingColumns::selectSql($this->pdo, [
            'billing_mode', 'billing_rounding', 'time_billing_enabled',
        ]);
        $biz = BusinessBillingColumns::withDefaults(
            $this->pdo->query("SELECT {$bizSelect} FROM businesses WHERE id = 1")->fetch()
        );
        $timing = BusinessBillingColumns::timingFromRow($this->pdo, $biz);
        $timeBilling = !$isCounter && (!isset($biz['time_billing_enabled']) || (bool) $biz['time_billing_enabled']);
        $setPrice = (float) ($session['set_price_snapshot'] ?? 0);
        if ($setPrice > 0) {
            $timeCharge = round($setPrice, 2);
            $productsTotal = $this->billing->calculateProductsTotal($items, true);
        } else {
            $plannedMinutes = isset($session['planned_minutes']) ? (int) $session['planned_minutes'] : 0;
            $timeCharge = $timeBilling
                ? $this->billing->calculateTimeCharge(
                    $activeSeconds,
                    (float) $session['hourly_rate_snapshot'],
                    $biz['billing_mode'] ?? 'per_minute',
                    (float) ($biz['billing_rounding'] ?? 0.01),
                    $timing['min_billing_minutes'],
                    $timing['billing_increment_minutes'],
                    $timing['billing_grace_minutes'],
                    $plannedMinutes > 0 ? $plannedMinutes : null
                )
                : 0.0;
            $productsTotal = $this->billing->calculateProductsTotal($items);
        }
        $subtotal = $timeCharge + $productsTotal;
        $discountType = $session['discount_type'] ?? 'none';
        $discountAppliesTo = $session['discount_applies_to'] ?? 'time_only';
        $resolved = $this->promotions->resolveDiscount($session, $timeCharge, $productsTotal);
        $discount = $resolved['amount'];
        $promotion = $resolved['promotion'];
        $customerGroup = $resolved['customer_group'];
        $spendRule = $resolved['spend_rule'] ?? null;
        $displayCustomerGroup = $this->promotions->displayCustomerGroup($session);
        if ($discountType !== 'none') {
            $base = $discountAppliesTo === 'time_only' ? $timeCharge : $subtotal;
            $discount = DiscountCalculator::amount($base, $discountType, (float) ($session['discount_value'] ?? 0));
            $promotion = null;
            $customerGroup = null;
            $spendRule = null;
        }
        $discountValue = (float) ($session['discount_value'] ?? 0);
        $total = round($subtotal - $discount, 2);

        if (!isset($plannedMinutes)) {
            $plannedMinutes = isset($session['planned_minutes']) ? (int) $session['planned_minutes'] : 0;
        }
        $hasPackage = $setPrice > 0;
        $remainingSeconds = $plannedMinutes > 0
            ? max(0, ($plannedMinutes * 60) - $activeSeconds)
            : null;

        return [
            'active_seconds' => $activeSeconds,
            'active_minutes' => (int) ceil($activeSeconds / 60),
            'time_charge' => $timeCharge,
            'products_total' => $productsTotal,
            'subtotal' => round($subtotal, 2),
            'discount' => $discount,
            'discount_type' => $discountType,
            'discount_value' => $discountValue,
            'discount_applies_to' => $discountAppliesTo,
            'promotion_id' => $promotion ? (int) $promotion['id'] : null,
            'promotion_name' => $promotion ? (string) $promotion['name'] : null,
            'promotion_discount_type' => $promotion ? (string) $promotion['discount_type'] : null,
            'promotion_discount_value' => $promotion ? (float) $promotion['discount_value'] : null,
            'active_promotion' => $promotion ? [
                'id' => (int) $promotion['id'],
                'name' => (string) $promotion['name'],
                'discount_type' => (string) $promotion['discount_type'],
                'discount_value' => (float) $promotion['discount_value'],
            ] : null,
            'customer_group_id' => $customerGroup ? (int) $customerGroup['id'] : null,
            'customer_group_name' => $customerGroup ? (string) $customerGroup['name'] : null,
            'customer_group_discount_type' => $customerGroup ? (string) $customerGroup['discount_type'] : null,
            'customer_group_discount_value' => $customerGroup ? (float) $customerGroup['discount_value'] : null,
            'customer_group_applies_to' => $customerGroup ? (string) ($customerGroup['applies_to'] ?? 'time_only') : null,
            'active_customer_group' => $displayCustomerGroup,
            'spend_rule_name' => $spendRule ? (string) ($spendRule['name'] ?? '') : null,
            'coupon_code' => $session['coupon_code'] ?? null,
            'total_amount' => $total,
            'items' => $items,
            'planned_minutes' => $plannedMinutes > 0 ? $plannedMinutes : null,
            'remaining_seconds' => $remainingSeconds,
            'is_countdown' => !$hasPackage && $plannedMinutes > 0,
            'is_package' => $hasPackage,
            'computed_at' => $this->clock->nowIso(),
        ];
    }

    /**
     * @return array{0: float, 1: ?int, 2: ?string}|false
     */
    private function resolveTableTariff(int $tableId, ?int $tariffId): array|false
    {
        $stmt = $this->pdo->prepare(
            'SELECT id, name, hourly_rate FROM table_tariffs
             WHERE table_id = ? AND is_active = 1
             ORDER BY sort_order, id'
        );
        $stmt->execute([$tableId]);
        $tariffs = $stmt->fetchAll();

        if ($tariffs === []) {
            $table = $this->pdo->prepare('SELECT hourly_rate FROM tables WHERE id = ?');
            $table->execute([$tableId]);
            $row = $table->fetch();
            if (!$row) {
                return false;
            }

            return [(float) $row['hourly_rate'], null, null];
        }

        if ($tariffId !== null && $tariffId > 0) {
            foreach ($tariffs as $tariff) {
                if ((int) $tariff['id'] === $tariffId) {
                    return [(float) $tariff['hourly_rate'], $tariffId, (string) $tariff['name']];
                }
            }

            return false;
        }

        if (count($tariffs) === 1) {
            $tariff = $tariffs[0];

            return [(float) $tariff['hourly_rate'], (int) $tariff['id'], (string) $tariff['name']];
        }

        return false;
    }

    private function applySessionSetItems(int $sessionId, array $set, int $userId): void
    {
        foreach ($set['items'] as $item) {
            $productId = (int) $item['product_id'];
            $qty = (int) $item['quantity'];
            $pstmt = $this->pdo->prepare('SELECT name FROM products WHERE id = ?');
            $pstmt->execute([$productId]);
            $product = $pstmt->fetch();
            if (!$product) {
                continue;
            }

            $this->stock->applyStockChange($productId, 'sale', $qty, 'sale', 'session', $sessionId, $userId);
            $this->pdo->prepare(
                'INSERT INTO session_items (session_id, product_id, product_name, quantity, unit_price, is_set_item, created_at)
                 VALUES (?, ?, ?, ?, 0, 1, NOW())'
            )->execute([$sessionId, $productId, $product['name'], $qty]);
        }
    }

    /**
     * @param array<string, mixed>|null $row
     * @return array{min_open_minutes: int, extend_step_minutes: int, min_billing_minutes: int, billing_increment_minutes: int, billing_grace_minutes: int}
     */
    private function businessTiming(?array $row = null): array
    {
        if ($row === null) {
            $select = BusinessBillingColumns::selectSql($this->pdo, ['id']);
            $row = $this->pdo->query("SELECT {$select} FROM businesses WHERE id = 1")->fetch();
        }

        return BusinessBillingColumns::timingFromRow($this->pdo, $row);
    }
}
