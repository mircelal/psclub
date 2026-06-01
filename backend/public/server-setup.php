<?php

declare(strict_types=1);

/**
 * Server diaqnostika + migration (bir dəfəlik).
 *
 * 1) .env-ə əlavə edin: MIGRATE_KEY=uzun-gizli-acar
 * 2) Bu faylı public_html-ə yükləyin
 * 3) Status (açar lazım deyil): https://psapi.sayt.cam/server-setup.php?action=status
 * 4) Migration: https://psapi.sayt.cam/server-setup.php?action=migrate&key=ACAR
 * 5) Uğurdan sonra server-setup.php, run-migrate.php SİLİN
 *
 * Bir dəfəlik (açarsız): storage/allow-migrate-once faylı yaradın, sonra:
 *   ?action=migrate&once=1
 */

header('Content-Type: application/json; charset=utf-8');

require __DIR__ . '/bootstrap.php';

$root = resolveAppRoot();
$action = strtolower(trim((string) ($_GET['action'] ?? 'status')));

if (!is_file($root . '/vendor/autoload.php')) {
    http_response_code(503);
    echo json_encode(['ok' => false, 'error' => 'vendor tapılmadı — site-root düzgün yerdədir?'], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    exit;
}

require $root . '/vendor/autoload.php';

$dotenv = Dotenv\Dotenv::createImmutable($root);
$dotenv->safeLoad();

$checks = [
    'php_version' => PHP_VERSION,
    'php_ok' => version_compare(PHP_VERSION, '8.2.0', '>='),
    'app_root' => $root,
    'vendor_autoload' => true,
    'env_file' => is_file($root . '/.env'),
    'storage_exists' => is_dir($root . '/storage'),
    'storage_writable' => is_dir($root . '/storage') && is_writable($root . '/storage'),
    'pdo_mysql' => extension_loaded('pdo_mysql'),
    'action' => $action,
];

if (!$checks['env_file']) {
    http_response_code(503);
    echo json_encode(['ok' => false, 'checks' => $checks, 'error' => '.env tapılmadı'], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    exit;
}

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
    $checks['db_name'] = $name;

    $diag = App\Support\SchemaMigrator::diagnostics($pdo);
    $checks = array_merge($checks, $diag);

    if ($action === 'status') {
        $ok = ($checks['billing_columns_ok'] ?? false)
            && ($checks['public_config_query_ok'] ?? false)
            && ($checks['tables_query_ok'] ?? false)
            && ($checks['discounts_schema_ok'] ?? false);

        http_response_code($ok ? 200 : 503);
        echo json_encode([
            'ok' => $ok,
            'checks' => $checks,
            'hint' => $ok
                ? 'Hamısı yaxşıdır. Bu faylı silə bilərsiniz.'
                : 'action=migrate ilə DB yeniləyin (.env MIGRATE_KEY və ya storage/allow-migrate-once)',
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        exit;
    }

    if ($action === 'migrate') {
        if (!authorizeMigrate($root)) {
            http_response_code(403);
            echo json_encode([
                'ok' => false,
                'error' => 'Forbidden — .env MIGRATE_KEY=?key=... və ya storage/allow-migrate-once + ?once=1',
            ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
            exit;
        }

        $result = App\Support\SchemaMigrator::run($pdo, $root . '/database/patches');
        $after = App\Support\SchemaMigrator::diagnostics($pdo);

        echo json_encode([
            'ok' => true,
            'applied' => $result['applied'],
            'skipped' => $result['skipped'],
            'after' => $after,
            'message' => 'Migration tamamlandı. server-setup.php və run-migrate.php fayllarını silin.',
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        exit;
    }

    http_response_code(400);
    echo json_encode([
        'ok' => false,
        'error' => 'Naməlum action. İstifadə: status | migrate',
        'checks' => $checks,
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'ok' => false,
        'error' => $e->getMessage(),
        'checks' => $checks,
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
}

function authorizeMigrate(string $root): bool
{
    $expectedKey = trim((string) ($_ENV['MIGRATE_KEY'] ?? ''));
    $providedKey = trim((string) ($_GET['key'] ?? ''));

    if ($expectedKey !== '' && $providedKey !== '' && hash_equals($expectedKey, $providedKey)) {
        return true;
    }

    $onceFlag = $root . '/storage/allow-migrate-once';
    if (($_GET['once'] ?? '') === '1' && is_file($onceFlag)) {
        @unlink($onceFlag);

        return true;
    }

    return false;
}
