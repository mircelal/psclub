<?php

declare(strict_types=1);

namespace App\Support;

use PDO;

final class DbSchema
{
    public static function hasTable(PDO $pdo, string $table): bool
    {
        if (!preg_match('/^[a-zA-Z0-9_]+$/', $table)) {
            return false;
        }

        if (self::isSqlite($pdo)) {
            $stmt = $pdo->prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?");
            $stmt->execute([$table]);

            return (bool) $stmt->fetchColumn();
        }

        $stmt = $pdo->prepare(
            'SELECT 1 FROM information_schema.TABLES
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? LIMIT 1'
        );
        $stmt->execute([$table]);

        return (bool) $stmt->fetchColumn();
    }

    public static function hasColumn(PDO $pdo, string $table, string $column): bool
    {
        if (!preg_match('/^[a-zA-Z0-9_]+$/', $table) || !preg_match('/^[a-zA-Z0-9_]+$/', $column)) {
            return false;
        }

        if (self::isSqlite($pdo)) {
            $rows = $pdo->query('PRAGMA table_info(' . $table . ')')->fetchAll();
            foreach ($rows as $row) {
                if (($row['name'] ?? '') === $column) {
                    return true;
                }
            }

            return false;
        }

        return SchemaMigrator::columnExists($pdo, $table, $column);
    }

    private static function isSqlite(PDO $pdo): bool
    {
        return $pdo->getAttribute(PDO::ATTR_DRIVER_NAME) === 'sqlite';
    }
}
