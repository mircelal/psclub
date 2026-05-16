<?php

declare(strict_types=1);

use App\Middleware\AuditMiddleware;
use App\Middleware\JwtAuthMiddleware;
use App\Middleware\RoleGuardMiddleware;
use App\Modules\Audit\AuditController;
use App\Modules\Auth\AuthController;
use App\Modules\Coupons\CouponsController;
use App\Modules\Customers\CustomersController;
use App\Modules\Orders\OrdersController;
use App\Modules\Products\ProductMediaController;
use App\Modules\Products\ProductsController;
use App\Modules\Receipts\ReceiptsController;
use App\Modules\Reports\ReportsController;
use App\Modules\Sessions\SessionsController;
use App\Modules\SessionSets\SessionSetsController;
use App\Modules\Settings\BusinessMediaController;
use App\Modules\Settings\SettingsController;
use App\Modules\Stock\StockController;
use App\Modules\Tables\TablesController;
use App\Modules\Users\UsersController;
use Slim\App;
use Slim\Routing\RouteCollectorProxy;

return function (App $app): void {
    $app->get('/api/health', function ($request, $response) {
        $response->getBody()->write(json_encode(['status' => 'ok', 'time' => date('c')]));
        return $response->withHeader('Content-Type', 'application/json');
    });

    $app->post('/api/auth/login', [AuthController::class, 'login']);

    $app->get('/api/media/products/{filename}', [ProductMediaController::class, 'serve']);
    $app->get('/api/media/business/logo', [BusinessMediaController::class, 'serve']);

    $app->group('/api/auth', function (RouteCollectorProxy $group) {
        $group->get('/me', [AuthController::class, 'me']);
        $group->post('/logout', [AuthController::class, 'logout']);
    })->add(JwtAuthMiddleware::class);

    $adminGuard = new RoleGuardMiddleware(['admin']);

    $app->group('/api', function (RouteCollectorProxy $group) use ($adminGuard) {
        // Cashier + Admin
        $group->get('/tables', [TablesController::class, 'index']);
        $group->get('/product-categories', [ProductsController::class, 'indexCategories']);
        $group->get('/products', [ProductsController::class, 'index']);
        $group->get('/customers', [CustomersController::class, 'index']);
        $group->post('/customers', [CustomersController::class, 'store']);
        $group->get('/stock/alerts', [StockController::class, 'alerts']);
        $group->get('/session-sets', [SessionSetsController::class, 'index']);

        $group->get('/sessions/active', [SessionsController::class, 'active']);
        $group->get('/sessions/{id}', [SessionsController::class, 'show']);
        $group->post('/sessions', [SessionsController::class, 'store']);
        $group->post('/sessions/{id}/items', [SessionsController::class, 'addItem']);
        $group->patch('/sessions/{id}/items/{itemId}', [SessionsController::class, 'updateItem']);
        $group->delete('/sessions/{id}/items/{itemId}', [SessionsController::class, 'removeItem']);
        $group->patch('/sessions/{id}/pause', [SessionsController::class, 'pause']);
        $group->patch('/sessions/{id}/resume', [SessionsController::class, 'resume']);
        $group->patch('/sessions/{id}/discount', [SessionsController::class, 'setDiscount']);
        $group->post('/sessions/{id}/apply-coupon', [SessionsController::class, 'applyCoupon']);
        $group->delete('/sessions/{id}/discount', [SessionsController::class, 'clearDiscount']);
        $group->get('/sessions/{id}/preview', [SessionsController::class, 'preview']);
        $group->post('/sessions/{id}/close', [SessionsController::class, 'close']);

        $group->get('/settings', [SettingsController::class, 'index']);
        $group->get('/reports/daily', [ReportsController::class, 'daily']);
        $group->get('/receipts/{sessionId}/pdf', [ReceiptsController::class, 'pdf']);

        // Admin only
        $group->group('', function (RouteCollectorProxy $admin) {
            $admin->get('/users', [UsersController::class, 'index']);
            $admin->post('/users', [UsersController::class, 'store']);
            $admin->put('/users/{id}', [UsersController::class, 'update']);
            $admin->delete('/users/{id}', [UsersController::class, 'destroy']);

            $admin->post('/tables', [TablesController::class, 'store']);
            $admin->put('/tables/{id}', [TablesController::class, 'update']);
            $admin->delete('/tables/{id}', [TablesController::class, 'destroy']);

            $admin->post('/product-categories', [ProductsController::class, 'storeCategory']);
            $admin->post('/products', [ProductsController::class, 'store']);
            $admin->put('/products/{id}', [ProductsController::class, 'update']);
            $admin->post('/products/{id}/image', [ProductMediaController::class, 'upload']);
            $admin->delete('/products/{id}', [ProductsController::class, 'destroy']);

            $admin->post('/session-sets', [SessionSetsController::class, 'store']);
            $admin->put('/session-sets/{id}', [SessionSetsController::class, 'update']);
            $admin->delete('/session-sets/{id}', [SessionSetsController::class, 'destroy']);

            $admin->get('/coupons', [CouponsController::class, 'index']);
            $admin->post('/coupons', [CouponsController::class, 'store']);
            $admin->put('/coupons/{id}', [CouponsController::class, 'update']);
            $admin->delete('/coupons/{id}', [CouponsController::class, 'destroy']);

            $admin->get('/customers/{id}', [CustomersController::class, 'show']);
            $admin->put('/customers/{id}', [CustomersController::class, 'update']);
            $admin->delete('/customers/{id}', [CustomersController::class, 'destroy']);

            $admin->get('/stock/movements', [StockController::class, 'movements']);
            $admin->post('/stock/movements', [StockController::class, 'storeMovement']);

            $admin->put('/settings', [SettingsController::class, 'update']);
            $admin->post('/settings/logo', [BusinessMediaController::class, 'upload']);
            $admin->get('/reports/dashboard', [ReportsController::class, 'dashboard']);
            $admin->get('/reports/summary', [ReportsController::class, 'summary']);
            $admin->post('/reports/daily-close', [ReportsController::class, 'dailyClose']);
            $admin->get('/audit-logs', [AuditController::class, 'index']);

            $admin->get('/orders', [OrdersController::class, 'index']);
            $admin->get('/orders/{id}', [OrdersController::class, 'show']);
            $admin->put('/orders/{id}/adjust', [OrdersController::class, 'adjust']);
            $admin->post('/orders/{id}/refund', [OrdersController::class, 'refund']);
        })->add($adminGuard);
    })
        ->add(AuditMiddleware::class)
        ->add(JwtAuthMiddleware::class);
};
