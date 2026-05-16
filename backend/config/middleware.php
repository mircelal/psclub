<?php

declare(strict_types=1);

use App\Middleware\CorsMiddleware;
use App\Middleware\JsonBodyParserMiddleware;
use Slim\App;

return function (App $app): void {
    $app->add(JsonBodyParserMiddleware::class);
    $app->add(CorsMiddleware::class);
    $app->addRoutingMiddleware();
    $errorMiddleware = $app->addErrorMiddleware(
        filter_var($_ENV['APP_DEBUG'] ?? true, FILTER_VALIDATE_BOOLEAN),
        true,
        true
    );
};
