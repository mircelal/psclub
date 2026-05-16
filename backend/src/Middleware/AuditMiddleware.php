<?php

declare(strict_types=1);

namespace App\Middleware;

use App\Modules\Audit\AuditService;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface;

final class AuditMiddleware implements MiddlewareInterface
{
    public function __construct(private readonly AuditService $audit)
    {
    }

    public function process(ServerRequestInterface $request, RequestHandlerInterface $handler): ResponseInterface
    {
        $response = $handler->handle($request);

        $method = $request->getMethod();
        if (!in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE'], true)) {
            return $response;
        }

        if ($response->getStatusCode() >= 400) {
            return $response;
        }

        $user = $request->getAttribute('user');
        if (!$user) {
            return $response;
        }

        $this->audit->logFromRequest($request, $user);

        return $response;
    }
}
