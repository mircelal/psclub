<?php

declare(strict_types=1);

namespace App\Modules\Auth;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

final class JwtService
{
    public function __construct(
        private readonly string $secret,
        private readonly int $ttl
    ) {
    }

    public function encode(array $user): string
    {
        $now = time();
        $payload = [
            'iss' => 'psclub',
            'iat' => $now,
            'exp' => $now + $this->ttl,
            'sub' => (int) $user['id'],
            'role' => $user['role'],
        ];

        return JWT::encode($payload, $this->secret, 'HS256');
    }

    public function decode(string $token): array
    {
        $decoded = JWT::decode($token, new Key($this->secret, 'HS256'));

        return (array) $decoded;
    }
}
