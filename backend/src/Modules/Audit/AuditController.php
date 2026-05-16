<?php

declare(strict_types=1);

namespace App\Modules\Audit;

use App\Support\ApiResponse;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

final class AuditController
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function index(Request $request, Response $response): Response
    {
        $params = $request->getQueryParams();
        $limit = min(200, (int) ($params['limit'] ?? 50));
        $action = $params['action'] ?? null;

        $sql = 'SELECT al.*, u.username AS actor_name FROM audit_logs al LEFT JOIN users u ON u.id = al.actor_id WHERE 1=1';
        $bind = [];
        if ($action) {
            $sql .= ' AND al.action LIKE ?';
            $bind[] = '%' . $action . '%';
        }
        $sql .= ' ORDER BY al.created_at DESC LIMIT ' . $limit;

        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($bind);

        return ApiResponse::success($stmt->fetchAll());
    }
}
