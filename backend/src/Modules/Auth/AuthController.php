<?php

declare(strict_types=1);

namespace App\Modules\Auth;

use App\Support\ApiResponse;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class AuthController
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly JwtService $jwt
    ) {
    }

    public function login(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        $validation = v::key('username', v::stringType()->notEmpty())
            ->key('password', v::stringType()->notEmpty());
        if (!$validation->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $stmt = $this->pdo->prepare('SELECT * FROM users WHERE username = ? AND is_active = 1');
        $stmt->execute([$body['username']]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($body['password'], $user['password_hash'])) {
            return ApiResponse::error('Invalid credentials', 401);
        }

        unset($user['password_hash']);
        $token = $this->jwt->encode($user);

        return ApiResponse::success([
            'token' => $token,
            'user' => $user,
        ]);
    }

    public function me(Request $request, Response $response): Response
    {
        $user = $request->getAttribute('user');
        return ApiResponse::success($user);
    }

    public function logout(Request $request, Response $response): Response
    {
        return ApiResponse::success(['message' => 'Logged out']);
    }
}
