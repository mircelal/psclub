<?php

declare(strict_types=1);

namespace App\Support;

use PDO;

/**
 * Billing timestamps must match MySQL (opened_at uses NOW() in SQL).
 */
final class DatabaseClock
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function now(): string
    {
        $row = $this->pdo->query('SELECT NOW() AS now_value')->fetch();

        return (string) ($row['now_value'] ?? date('Y-m-d H:i:s'));
    }
}
