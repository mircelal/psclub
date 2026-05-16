<?php

declare(strict_types=1);

namespace App\Middleware;

use App\Support\ApiResponse;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface;

final class RoleGuardMiddleware implements MiddlewareInterface
{
    /** @param string[] $roles */
    public function __construct(private readonly array $roles)
    {
    }

    public function process(ServerRequestInterface $request, RequestHandlerInterface $handler): ResponseInterface
    {
        $user = $request->getAttribute('user');
        if (!$user || !in_array($user['role'], $this->roles, true)) {
            return ApiResponse::error('Forbidden', 403);
        }

        return $handler->handle($request);
    }
}
