<?php

declare(strict_types=1);

namespace App\Support;

use Psr\Http\Message\ResponseInterface as Response;
use Slim\Psr7\Response as SlimResponse;

final class ApiResponse
{
    public static function success(mixed $data = null, array $meta = [], int $status = 200): Response
    {
        $response = new SlimResponse($status);
        $payload = ['success' => true, 'data' => $data, 'meta' => $meta];
        $response->getBody()->write((string) json_encode($payload, JSON_UNESCAPED_UNICODE));
        return $response->withHeader('Content-Type', 'application/json');
    }

    public static function error(string $message, int $status = 400, array $errors = []): Response
    {
        $response = new SlimResponse($status);
        $payload = ['success' => false, 'message' => $message, 'errors' => $errors];
        $response->getBody()->write((string) json_encode($payload, JSON_UNESCAPED_UNICODE));
        return $response->withHeader('Content-Type', 'application/json');
    }
}
