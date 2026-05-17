<?php

declare(strict_types=1);

/**
 * Təmiz production install.sql — müvəqqəti DB, DeploySeeder, lokal .env dəyişmir.
 *
 * Usage: php scripts/generate-install-sql.php <temp_db_name> <output_sql_path>
 */

if ($argc < 3) {
    fwrite(STDERR, "Usage: php scripts/generate-install-sql.php <temp_db> <output.sql>\n");
    exit(1);
}

$tempDb = $argv[1];
$outputPath = $argv[2];
$root = dirname(__DIR__);

require $root . '/vendor/autoload.php';

$dotenv = Dotenv\Dotenv::createImmutable($root);
$dotenv->safeLoad();

$host = $_ENV['DB_HOST'] ?? '127.0.0.1';
$port = (int) ($_ENV['DB_PORT'] ?? 3306);
$user = $_ENV['DB_USER'] ?? 'root';
$pass = $_ENV['DB_PASS'] ?? '';

$dsn = sprintf('mysql:host=%s;port=%d;charset=utf8mb4', $host, $port);

try {
    $pdo = new PDO($dsn, $user, $pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
} catch (PDOException $e) {
    fwrite(STDERR, "MySQL qoşulması uğursuz: {$e->getMessage()}\n");
    fwrite(STDERR, "Laragon MySQL işləyir? backend/.env DB_* düzgündür?\n");
    exit(1);
}

$pdo->exec("DROP DATABASE IF EXISTS `{$tempDb}`");
$pdo->exec("CREATE DATABASE `{$tempDb}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");

// Phinx alt prosesi — phinx.php PSCLUB_BUILD_* oxuyur (lokal psclub DB qarışmır).
putenv('PSCLUB_BUILD_DB_NAME=' . $tempDb);
putenv('PSCLUB_BUILD_DB_HOST=' . $host);
putenv('PSCLUB_BUILD_DB_PORT=' . (string) $port);
putenv('PSCLUB_BUILD_DB_USER=' . $user);
putenv('PSCLUB_BUILD_DB_PASS=' . $pass);

$phpBin = PHP_BINARY;
$phinx = $root . DIRECTORY_SEPARATOR . 'vendor' . DIRECTORY_SEPARATOR . 'bin' . DIRECTORY_SEPARATOR . 'phinx';

$run = static function (array $args) use ($phpBin, $phinx, $root): int {
    $cmd = escapeshellarg($phpBin) . ' ' . escapeshellarg($phinx) . ' ' . implode(' ', array_map('escapeshellarg', $args));
    passthru($cmd, $code);
    return (int) $code;
};

chdir($root);

if ($run(['migrate', '-e', 'development']) !== 0) {
    exit(1);
}
if ($run(['seed:run', '-s', 'DeploySeeder', '-e', 'development']) !== 0) {
    exit(1);
}

$pdo->exec("USE `{$tempDb}`");

$tables = $pdo->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN);
$generatedAt = date('Y-m-d H:i:s');
$sql = <<<HDR
-- PS Club production install.sql
-- Yaradılıb: {$generatedAt}
-- Mənbə: DeploySeeder (lokal sessiya / test məlumatı YOXDUR)
-- Import: DirectAdmin phpMyAdmin → DB seç → Import

HDR;
$sql .= "SET NAMES utf8mb4;\nSET FOREIGN_KEY_CHECKS = 0;\n\n";

foreach ($tables as $table) {
    $create = $pdo->query("SHOW CREATE TABLE `{$table}`")->fetch(PDO::FETCH_ASSOC);
    $sql .= "DROP TABLE IF EXISTS `{$table}`;\n";
    $sql .= $create['Create Table'] . ";\n\n";

    $rows = $pdo->query("SELECT * FROM `{$table}`")->fetchAll(PDO::FETCH_ASSOC);
    if ($rows === []) {
        continue;
    }

    $columns = array_keys($rows[0]);
    $colList = implode('`, `', $columns);

    foreach ($rows as $row) {
        $values = [];
        foreach ($columns as $col) {
            $values[] = sqlValue($pdo, $row[$col]);
        }
        $sql .= "INSERT INTO `{$table}` (`{$colList}`) VALUES (" . implode(', ', $values) . ");\n";
    }
    $sql .= "\n";
}

$sql .= "SET FOREIGN_KEY_CHECKS = 1;\n";

$dir = dirname($outputPath);
if (!is_dir($dir)) {
    mkdir($dir, 0775, true);
}
file_put_contents($outputPath, $sql);

$pdo->exec("DROP DATABASE IF EXISTS `{$tempDb}`");

echo "install.sql yazıldı: {$outputPath}\n";
echo "Cədvəl sayı: " . count($tables) . "\n";
exit(0);

function sqlValue(PDO $pdo, mixed $value): string
{
    if ($value === null) {
        return 'NULL';
    }
    if (is_bool($value)) {
        return $value ? '1' : '0';
    }
    if (is_int($value) || is_float($value)) {
        return (string) $value;
    }

    return $pdo->quote((string) $value);
}
