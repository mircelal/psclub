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

    /** ISO8601 — Flutter parse üçün (məs. 2026-05-17T14:30:00+04:00). */
    public function nowIso(): string
    {
        $tz = new \DateTimeZone($_ENV['APP_TIMEZONE'] ?? 'Asia/Baku');

        return (new \DateTimeImmutable('now', $tz))->format('c');
    }
}
