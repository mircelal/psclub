<?php

declare(strict_types=1);

require __DIR__ . '/../vendor/autoload.php';

$dotenv = Dotenv\Dotenv::createImmutable(dirname(__DIR__));
$dotenv->safeLoad();

$pdo = App\Support\Database::connect();
$dbName = $_ENV['DB_NAME'] ?? '?';

$tables = [];
foreach ($pdo->query('SHOW TABLES') as $row) {
    $tables[] = (array_values($row)[0]);
}

$required = ['promotions', 'customer_groups', 'table_tariffs', 'shifts', 'sessions', 'customers'];
$missing = array_values(array_diff($required, $tables));

$migrations = $pdo->query(
    'SELECT version FROM phinxlog WHERE version IN (20260601120000, 20260601130000) ORDER BY version'
)->fetchAll(PDO::FETCH_COLUMN);

$diag = App\Support\SchemaMigrator::diagnostics($pdo);

echo "DB: {$dbName}\n";
echo 'missing_tables: ' . ($missing === [] ? 'none' : implode(', ', $missing)) . "\n";
echo 'discounts_schema_ok: ' . (($diag['discounts_schema_ok'] ?? false) ? 'YES' : 'NO') . "\n";
echo 'billing_columns_ok: ' . (($diag['billing_columns_ok'] ?? false) ? 'YES' : 'NO') . "\n";
echo 'migrations: ' . ($migrations === [] ? 'MISSING promotions/customer_groups' : implode(', ', $migrations)) . "\n";

if (in_array('promotions', $tables, true)) {
    echo 'active_promotions: ' . $pdo->query('SELECT COUNT(*) FROM promotions WHERE is_active=1')->fetchColumn() . "\n";
}
if (in_array('customer_groups', $tables, true)) {
    echo 'active_customer_groups: ' . $pdo->query('SELECT COUNT(*) FROM customer_groups WHERE is_active=1')->fetchColumn() . "\n";
}

$openShift = $pdo->query("SELECT COUNT(*) FROM shifts WHERE status='open'")->fetchColumn();
$openSessions = $pdo->query("SELECT COUNT(*) FROM sessions WHERE status IN ('active','paused')")->fetchColumn();
echo "open_shifts: {$openShift}\n";
echo "open_sessions: {$openSessions}\n";

$users = $pdo->query("SELECT username, role, is_active FROM users ORDER BY id")->fetchAll(PDO::FETCH_ASSOC);
echo "users:\n";
foreach ($users as $u) {
    echo "  - {$u['username']} ({$u['role']}) active=" . ($u['is_active'] ? '1' : '0') . "\n";
}

exit($missing !== [] || !($diag['discounts_schema_ok'] ?? false) ? 1 : 0);
