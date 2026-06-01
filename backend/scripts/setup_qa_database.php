<?php

declare(strict_types=1);

/**
 * Təmiz QA DB: psclub_qa — migrate + DeploySeeder + billing_mode.
 * php scripts/setup_qa_database.php
 */

$root = dirname(__DIR__);
require $root . '/vendor/autoload.php';

$dotenv = Dotenv\Dotenv::createImmutable($root);
$dotenv->safeLoad();

$host = $_ENV['DB_HOST'] ?? '127.0.0.1';
$port = $_ENV['DB_PORT'] ?? '3306';
$user = $_ENV['DB_USER'] ?? 'root';
$pass = $_ENV['DB_PASS'] ?? '';
$qaDb = 'psclub_qa';

echo "Connecting to MySQL...\n";
$pdo = new PDO(
    "mysql:host={$host};port={$port};charset=utf8mb4",
    $user,
    $pass,
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

echo "Recreating database {$qaDb}...\n";
$pdo->exec("DROP DATABASE IF EXISTS `{$qaDb}`");
$pdo->exec("CREATE DATABASE `{$qaDb}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");

$phinx = escapeshellarg(PHP_BINARY) . ' ' . escapeshellarg($root . '/vendor/bin/phinx');

echo "Running migrations...\n";
passthru("{$phinx} migrate -e qa", $code);
if ($code !== 0) {
    exit(1);
}

echo "Seeding DeploySeeder...\n";
passthru("{$phinx} seed:run -e qa -s DeploySeeder", $code);
if ($code !== 0) {
    exit(1);
}

$qa = new PDO(
    "mysql:host={$host};port={$port};dbname={$qaDb};charset=utf8mb4",
    $user,
    $pass,
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

$qa->exec(
    "UPDATE businesses SET
        billing_mode = 'min_1h_then_30',
        billing_grace_minutes = 10,
        min_billing_minutes = 60,
        billing_increment_minutes = 30,
        min_open_minutes = 60,
        extend_step_minutes = 30
     WHERE id = 1"
);

file_put_contents($root . '/.qa-db', $qaDb);
echo "QA database ready: {$qaDb}\n";
echo "Wrote {$root}/.qa-db — API bu fayl olduqda psclub_qa istifadə edir.\n";
