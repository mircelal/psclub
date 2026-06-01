<?php

declare(strict_types=1);

namespace App\Support;

use PDO;

/**
 * Köhnə DB-lərdə billing sütunları addım-addım əlavə olunur; SELECT çökməsin deyə.
 */
final class BusinessBillingColumns
{
    /** @var array<string, int> */
    private const DEFAULTS = [
        'min_open_minutes' => 60,
        'extend_step_minutes' => 30,
        'min_billing_minutes' => 60,
        'billing_increment_minutes' => 30,
        'billing_grace_minutes' => 10,
    ];

    public static function exists(PDO $pdo, string $column): bool
    {
        static $cache = [];
        if (array_key_exists($column, $cache)) {
            return $cache[$column];
        }

        $stmt = $pdo->prepare(
            'SELECT 1 FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = \'businesses\' AND COLUMN_NAME = ?'
        );
        $stmt->execute([$column]);
        $cache[$column] = (bool) $stmt->fetchColumn();

        return $cache[$column];
    }

    /**
     * @param list<string> $baseColumns
     */
    public static function selectSql(PDO $pdo, array $baseColumns): string
    {
        $cols = $baseColumns;
        foreach (array_keys(self::DEFAULTS) as $name) {
            if (self::exists($pdo, $name)) {
                $cols[] = $name;
            }
        }

        return implode(', ', $cols);
    }

    /**
     * @param array<string, mixed>|false $row
     * @return array<string, mixed>
     */
    public static function withDefaults(array|false $row): array
    {
        $out = is_array($row) ? $row : [];
        foreach (self::DEFAULTS as $key => $default) {
            if (!array_key_exists($key, $out) || $out[$key] === null) {
                $out[$key] = $default;
            }
        }

        return $out;
    }

    /**
     * @return array{min_open_minutes: int, extend_step_minutes: int, min_billing_minutes: int, billing_increment_minutes: int, billing_grace_minutes: int}
     */
    public static function timingFromRow(PDO $pdo, array|false $row): array
    {
        $biz = self::withDefaults($row);

        return [
            'min_open_minutes' => max(1, (int) ($biz['min_open_minutes'] ?? 60)),
            'extend_step_minutes' => max(1, (int) ($biz['extend_step_minutes'] ?? 30)),
            'min_billing_minutes' => max(1, (int) ($biz['min_billing_minutes'] ?? 60)),
            'billing_increment_minutes' => max(1, (int) ($biz['billing_increment_minutes'] ?? 30)),
            'billing_grace_minutes' => max(0, (int) ($biz['billing_grace_minutes'] ?? 10)),
        ];
    }
}
