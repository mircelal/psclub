<?php

declare(strict_types=1);

use App\Middleware\CorsMiddleware;
use App\Middleware\JsonBodyParserMiddleware;
use Slim\App;

return function (App $app): void {
    // Slim: son $app->add() sorğuda ilk işləyir — CORS routing-dən əvvəl.
    $app->addRoutingMiddleware();
    $app->add(JsonBodyParserMiddleware::class);

    $app->addErrorMiddleware(
        filter_var($_ENV['APP_DEBUG'] ?? true, FILTER_VALIDATE_BOOLEAN),
        true,
        true
    );

    $app->add(CorsMiddleware::class);
};
