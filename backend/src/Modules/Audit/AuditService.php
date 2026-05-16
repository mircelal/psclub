<?php

declare(strict_types=1);

namespace App\Modules\Audit;

use PDO;
use Psr\Http\Message\ServerRequestInterface;

final class AuditService
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function log(
        int $businessId,
        ?int $actorId,
        string $action,
        ?string $entityType = null,
        ?int $entityId = null,
        ?array $payload = null,
        ?string $ip = null
    ): void {
        $stmt = $this->pdo->prepare(
            'INSERT INTO audit_logs (business_id, actor_id, action, entity_type, entity_id, payload, ip_address, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, NOW())'
        );
        $stmt->execute([
            $businessId,
            $actorId,
            $action,
            $entityType,
            $entityId,
            $payload ? json_encode($payload, JSON_UNESCAPED_UNICODE) : null,
            $ip,
        ]);
    }

    public function logFromRequest(ServerRequestInterface $request, array $user): void
    {
        $path = $request->getUri()->getPath();
        $method = $request->getMethod();
        $body = $request->getParsedBody();

        $this->log(
            (int) ($user['business_id'] ?? 1),
            (int) $user['id'],
            strtolower($method) . ':' . $path,
            null,
            null,
            is_array($body) ? $body : null,
            $request->getServerParams()['REMOTE_ADDR'] ?? null
        );
    }
}
