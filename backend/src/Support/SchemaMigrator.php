<?php

declare(strict_types=1);

namespace App\Support;

use PDO;
use PDOException;

final class SchemaMigrator
{
    /**
     * @return array{applied: list<string>, skipped: list<string>}
     */
    public static function run(PDO $pdo, string $patchesDir): array
    {
        $applied = [];
        $skipped = [];

        $columns = [
            'min_open_minutes' => "ADD COLUMN min_open_minutes INT UNSIGNED NOT NULL DEFAULT 60 AFTER time_billing_enabled",
            'extend_step_minutes' => "ADD COLUMN extend_step_minutes INT UNSIGNED NOT NULL DEFAULT 30 AFTER min_open_minutes",
            'min_billing_minutes' => "ADD COLUMN min_billing_minutes INT UNSIGNED NOT NULL DEFAULT 60 AFTER extend_step_minutes",
            'billing_increment_minutes' => "ADD COLUMN billing_increment_minutes INT UNSIGNED NOT NULL DEFAULT 30 AFTER min_billing_minutes",
            'billing_grace_minutes' => "ADD COLUMN billing_grace_minutes INT UNSIGNED NOT NULL DEFAULT 10 AFTER billing_increment_minutes",
        ];

        foreach ($columns as $nameCol => $ddl) {
            if (self::columnExists($pdo, 'businesses', $nameCol)) {
                $skipped[] = "businesses.{$nameCol}";
                continue;
            }
            $pdo->exec("ALTER TABLE businesses {$ddl}");
            $applied[] = "businesses.{$nameCol}";
        }

        $enumRow = $pdo->query(
            "SELECT COLUMN_TYPE FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'businesses' AND COLUMN_NAME = 'billing_mode'"
        )->fetch(PDO::FETCH_ASSOC);

        $enumType = (string) ($enumRow['COLUMN_TYPE'] ?? '');
        if (!str_contains($enumType, 'min_1h_then_30')) {
            $pdo->exec(
                "ALTER TABLE businesses MODIFY billing_mode ENUM(
                    'per_minute','block_30','block_60','min_1h_then_30'
                ) NOT NULL DEFAULT 'per_minute'"
            );
            $applied[] = 'businesses.billing_mode_enum';
        } else {
            $skipped[] = 'businesses.billing_mode_enum';
        }

        if (is_dir($patchesDir)) {
            $files = glob($patchesDir . '/*.sql') ?: [];
            sort($files, SORT_STRING);
            foreach ($files as $file) {
                $basename = basename($file);
                $sql = trim((string) file_get_contents($file));
                if ($sql === '') {
                    $skipped[] = $basename . ' (boş)';
                    continue;
                }
                if (self::patchAlreadyApplied($pdo, $basename)) {
                    $skipped[] = $basename;
                    continue;
                }
                foreach (self::splitSqlStatements($sql) as $statement) {
                    try {
                        $pdo->exec($statement);
                    } catch (PDOException $e) {
                        if (!self::isIgnorableMigrationError($e)) {
                            throw $e;
                        }
                    }
                }
                self::markPatchApplied($pdo, $basename);
                $applied[] = $basename;
            }
        }

        self::recordPhinxMigration($pdo, '20260517120000');
        self::recordPhinxMigration($pdo, '20260522120000', 'AddBillingGraceMinutes');

        return ['applied' => $applied, 'skipped' => $skipped];
    }

    /** @return array<string, mixed> */
    public static function diagnostics(PDO $pdo): array
    {
        $billingCols = [
            'min_open_minutes',
            'extend_step_minutes',
            'min_billing_minutes',
            'billing_increment_minutes',
            'billing_grace_minutes',
        ];
        $missing = [];
        foreach ($billingCols as $col) {
            if (!self::columnExists($pdo, 'businesses', $col)) {
                $missing[] = $col;
            }
        }

        $tables = [];
        foreach ($pdo->query('SHOW TABLES') as $row) {
            $tables[] = (string) array_values($row)[0];
        }

        $publicConfigOk = null;
        $tablesApiOk = null;
        $publicConfigError = null;
        $tablesApiError = null;

        try {
            $select = BusinessBillingColumns::selectSql($pdo, [
                'id', 'name', 'billing_mode', 'time_billing_enabled', 'logo_url',
            ]);
            $pdo->query("SELECT {$select} FROM businesses WHERE id = 1 LIMIT 1")->fetch();
            $publicConfigOk = true;
        } catch (\Throwable $e) {
            $publicConfigOk = false;
            $publicConfigError = $e->getMessage();
        }

        try {
            $bizSelect = BusinessBillingColumns::selectSql($pdo, [
                'billing_mode', 'billing_rounding', 'time_billing_enabled',
            ]);
            $pdo->query("SELECT {$bizSelect} FROM businesses WHERE id = 1")->fetch();
            $stmt = $pdo->query(
                "SHOW TABLES LIKE 'table_tariffs'"
            );
            if ($stmt->fetchColumn()) {
                $pdo->query('SELECT COUNT(*) FROM table_tariffs')->fetchColumn();
            }
            $pdo->query(
                "SELECT t.id FROM tables t
                 LEFT JOIN sessions s ON s.table_id = t.id AND s.status IN ('active', 'paused')
                 WHERE t.is_active = 1 LIMIT 1"
            )->fetch();
            $tablesApiOk = true;
        } catch (\Throwable $e) {
            $tablesApiOk = false;
            $tablesApiError = $e->getMessage();
        }

        return [
            'db_tables_count' => count($tables),
            'billing_columns_missing' => $missing,
            'billing_columns_ok' => $missing === [],
            'table_tariffs_exists' => in_array('table_tariffs', $tables, true),
            'promotions_table_exists' => in_array('promotions', $tables, true),
            'customer_groups_table_exists' => in_array('customer_groups', $tables, true),
            'customers_group_column_ok' => self::columnExists($pdo, 'customers', 'customer_group_id'),
            'discounts_schema_ok' => in_array('promotions', $tables, true)
                && in_array('customer_groups', $tables, true)
                && self::columnExists($pdo, 'customers', 'customer_group_id'),
            'public_config_query_ok' => $publicConfigOk,
            'public_config_error' => $publicConfigError,
            'tables_query_ok' => $tablesApiOk,
            'tables_error' => $tablesApiError,
        ];
    }

    public static function columnExists(PDO $pdo, string $table, string $column): bool
    {
        $stmt = $pdo->prepare(
            'SELECT 1 FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?'
        );
        $stmt->execute([$table, $column]);

        return (bool) $stmt->fetchColumn();
    }

    private static function recordPhinxMigration(PDO $pdo, string $version, string $migrationName = 'AddBillingTimingRules'): void
    {
        $pdo->exec(
            'CREATE TABLE IF NOT EXISTS phinxlog (
                version BIGINT NOT NULL PRIMARY KEY,
                migration_name VARCHAR(255) NULL,
                start_time TIMESTAMP NULL,
                end_time TIMESTAMP NULL,
                breakpoint TINYINT(1) NOT NULL DEFAULT 0
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
        );

        $versionNum = (int) $version;
        $stmt = $pdo->prepare('SELECT 1 FROM phinxlog WHERE version = ?');
        $stmt->execute([$versionNum]);
        if ($stmt->fetchColumn()) {
            return;
        }

        $insert = $pdo->prepare(
            'INSERT INTO phinxlog (version, migration_name, start_time, end_time, breakpoint)
             VALUES (?, ?, NOW(), NOW(), 0)'
        );
        $insert->execute([$versionNum, $migrationName]);
    }

    private static function patchAlreadyApplied(PDO $pdo, string $name): bool
    {
        $pdo->exec(
            'CREATE TABLE IF NOT EXISTS schema_patches (
                name VARCHAR(255) NOT NULL PRIMARY KEY,
                applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
        );
        $stmt = $pdo->prepare('SELECT 1 FROM schema_patches WHERE name = ?');
        $stmt->execute([$name]);

        return (bool) $stmt->fetchColumn();
    }

    private static function markPatchApplied(PDO $pdo, string $name): void
    {
        $stmt = $pdo->prepare('INSERT IGNORE INTO schema_patches (name) VALUES (?)');
        $stmt->execute([$name]);
    }

    private static function isIgnorableMigrationError(PDOException $e): bool
    {
        $msg = $e->getMessage();

        return str_contains($msg, 'Duplicate column')
            || str_contains($msg, 'duplicate column name')
            || str_contains($msg, '1060');
    }

    /** @return list<string> */
    private static function splitSqlStatements(string $sql): array
    {
        $parts = preg_split('/;\s*\n/', $sql) ?: [];
        $out = [];
        foreach ($parts as $part) {
            $part = trim($part);
            if ($part !== '' && !str_starts_with($part, '--')) {
                $out[] = $part;
            }
        }

        return $out;
    }
}
