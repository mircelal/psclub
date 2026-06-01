<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

require __DIR__ . '/bootstrap.php';

$root = resolveAppRoot();

$checks = [
    'php_version' => PHP_VERSION,
    'php_ok' => version_compare(PHP_VERSION, '8.2.0', '>='),
    'app_root' => $root,
    'vendor_autoload' => is_file($root . '/vendor/autoload.php'),
    'env_file' => is_file($root . '/.env'),
    'storage_exists' => is_dir($root . '/storage'),
    'storage_writable' => is_dir($root . '/storage') && is_writable($root . '/storage'),
    'pdo_mysql' => extension_loaded('pdo_mysql'),
    'gd' => extension_loaded('gd'),
];

if ($checks['vendor_autoload'] && $checks['env_file']) {
    require $root . '/vendor/autoload.php';
    $dotenv = Dotenv\Dotenv::createImmutable($root);
    $dotenv->safeLoad();
    $qaDbFile = $root . '/.qa-db';
    if (is_file($qaDbFile)) {
        $qaDb = trim((string) file_get_contents($qaDbFile));
        if ($qaDb !== '') {
            $_ENV['DB_NAME'] = $qaDb;
        }
    }
    $checks['db_host'] = $_ENV['DB_HOST'] ?? null;
    $checks['db_name'] = $_ENV['DB_NAME'] ?? null;

    if ($checks['pdo_mysql']) {
        try {
            $host = $_ENV['DB_HOST'] ?? 'localhost';
            $port = $_ENV['DB_PORT'] ?? '3306';
            $name = $_ENV['DB_NAME'] ?? '';
            $user = $_ENV['DB_USER'] ?? '';
            $pass = $_ENV['DB_PASS'] ?? '';
            $pdo = new PDO(
                "mysql:host={$host};port={$port};dbname={$name};charset=utf8mb4",
                $user,
                $pass,
                [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
            );
            $checks['db_connect'] = true;
            $checks['db_tables'] = (int) $pdo->query('SHOW TABLES')->rowCount();
            $colStmt = $pdo->prepare(
                'SELECT COUNT(*) FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?'
            );
            $billingCols = [
                'min_open_minutes',
                'extend_step_minutes',
                'min_billing_minutes',
                'billing_increment_minutes',
                'billing_grace_minutes',
            ];
            $missing = [];
            foreach ($billingCols as $col) {
                $colStmt->execute(['businesses', $col]);
                if ((int) $colStmt->fetchColumn() === 0) {
                    $missing[] = $col;
                }
            }
            $checks['billing_columns_ok'] = $missing === [];
            if ($missing !== []) {
                $checks['billing_columns_missing'] = $missing;
                $checks['migrate_hint'] = 'phpMyAdmin: database/patches/20260517120000_billing_timing_rules.sql və ya run-migrate.php?key=...';
            }
        } catch (Throwable $e) {
            $checks['db_connect'] = false;
            $checks['db_error'] = $e->getMessage();
        }
    }
}

$ok = $checks['php_ok']
    && $checks['vendor_autoload']
    && $checks['env_file']
    && ($checks['db_connect'] ?? false);

http_response_code($ok ? 200 : 503);
echo json_encode([
    'status' => $ok ? 'ok' : 'needs_fix',
    'checks' => $checks,
], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
