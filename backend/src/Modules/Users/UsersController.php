<?php

declare(strict_types=1);

namespace App\Modules\Users;

use App\Support\ApiResponse;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class UsersController
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function index(Request $request, Response $response): Response
    {
        $stmt = $this->pdo->query('SELECT id, username, full_name, role, is_active, business_id, created_at FROM users ORDER BY id');
        return ApiResponse::success($stmt->fetchAll());
    }

    public function store(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        $validation = v::key('username', v::stringType()->notEmpty())
            ->key('password', v::stringType()->length(4, null))
            ->key('role', v::in(['admin', 'cashier']));
        if (!$validation->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $stmt = $this->pdo->prepare(
            'INSERT INTO users (business_id, username, password_hash, full_name, role, is_active, created_at, updated_at)
             VALUES (1, ?, ?, ?, ?, 1, NOW(), NOW())'
        );
        $stmt->execute([
            $body['username'],
            password_hash($body['password'], PASSWORD_BCRYPT),
            $body['full_name'] ?? null,
            $body['role'],
        ]);

        return ApiResponse::success(['id' => (int) $this->pdo->lastInsertId()], [], 201);
    }

    public function update(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $body = (array) $request->getParsedBody();

        $fields = [];
        $params = [];
        if (isset($body['full_name'])) {
            $fields[] = 'full_name = ?';
            $params[] = $body['full_name'];
        }
        $current = $request->getAttribute('user');
        $targetStmt = $this->pdo->prepare('SELECT id, role, is_active FROM users WHERE id = ?');
        $targetStmt->execute([$id]);
        $target = $targetStmt->fetch();
        if (!$target) {
            return ApiResponse::error('İstifadəçi tapılmadı', 404);
        }

        $newRole = $body['role'] ?? $target['role'];
        $newActive = isset($body['is_active']) ? (bool) $body['is_active'] : (bool) $target['is_active'];

        if ($current && (int) $current['id'] === $id) {
            if ($newRole !== 'admin') {
                return ApiResponse::error('Öz rolunuzu dəyişə bilməzsiniz', 403);
            }
            if (!$newActive) {
                return ApiResponse::error('Öz hesabınızı deaktiv edə bilməzsiniz', 403);
            }
        }

        if ($target['role'] === 'admin' && (int) $target['is_active'] === 1) {
            $wouldLoseAdmin = ($newRole !== 'admin' || !$newActive);
            if ($wouldLoseAdmin && $this->countActiveAdmins() <= 1) {
                return ApiResponse::error('Son aktiv administrator dəyişdirilə bilməz', 422);
            }
        }

        if (isset($body['role']) && in_array($body['role'], ['admin', 'cashier'], true)) {
            $fields[] = 'role = ?';
            $params[] = $body['role'];
        }
        if (isset($body['is_active'])) {
            $fields[] = 'is_active = ?';
            $params[] = (int) $newActive;
        }
        if (!empty($body['password'])) {
            $fields[] = 'password_hash = ?';
            $params[] = password_hash($body['password'], PASSWORD_BCRYPT);
        }
        if ($fields === []) {
            return ApiResponse::error('No fields to update', 422);
        }

        $fields[] = 'updated_at = NOW()';
        $params[] = $id;
        $sql = 'UPDATE users SET ' . implode(', ', $fields) . ' WHERE id = ?';
        $this->pdo->prepare($sql)->execute($params);

        return ApiResponse::success(['updated' => true]);
    }

    public function destroy(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $current = $request->getAttribute('user');
        if ($current && (int) $current['id'] === $id) {
            return ApiResponse::error('Öz hesabınızı silə bilməzsiniz', 403);
        }

        $target = $this->pdo->prepare('SELECT id, role, is_active FROM users WHERE id = ?');
        $target->execute([$id]);
        $row = $target->fetch();
        if (!$row) {
            return ApiResponse::error('İstifadəçi tapılmadı', 404);
        }

        if ($row['role'] === 'admin' && (int) $row['is_active'] === 1) {
            $admins = (int) $this->pdo->query(
                "SELECT COUNT(*) FROM users WHERE role = 'admin' AND is_active = 1"
            )->fetchColumn();
            if ($admins <= 1) {
                return ApiResponse::error('Son aktiv administrator silinə bilməz', 422);
            }
        }

        $this->pdo->prepare('UPDATE users SET is_active = 0, updated_at = NOW() WHERE id = ?')->execute([$id]);
        return ApiResponse::success(['deleted' => true]);
    }

    private function countActiveAdmins(): int
    {
        return (int) $this->pdo->query(
            "SELECT COUNT(*) FROM users WHERE role = 'admin' AND is_active = 1"
        )->fetchColumn();
    }
}
