<?php

declare(strict_types=1);

namespace App\Middleware;

use App\Modules\Auth\JwtService;
use App\Support\ApiResponse;
use PDO;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface;

final class JwtAuthMiddleware implements MiddlewareInterface
{
    public function __construct(
        private readonly JwtService $jwt,
        private readonly PDO $pdo
    ) {
    }

    public function process(ServerRequestInterface $request, RequestHandlerInterface $handler): ResponseInterface
    {
        $header = $request->getHeaderLine('Authorization');
        if ($header === '') {
            $server = $request->getServerParams();
            $header = (string) ($server['HTTP_AUTHORIZATION'] ?? $server['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
        }
        if (!preg_match('/Bearer\s+(\S+)/', $header, $matches)) {
            return ApiResponse::error('Unauthorized', 401);
        }

        try {
            $payload = $this->jwt->decode($matches[1]);
        } catch (\Throwable) {
            return ApiResponse::error('Invalid or expired token', 401);
        }

        $stmt = $this->pdo->prepare('SELECT id, username, role, is_active, business_id FROM users WHERE id = ?');
        $stmt->execute([(int) $payload['sub']]);
        $user = $stmt->fetch();

        if (!$user || !(int) $user['is_active']) {
            return ApiResponse::error('User not found or inactive', 401);
        }

        return $handler->handle($request->withAttribute('user', $user));
    }
}
