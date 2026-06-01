# Təmiz QA verilənlər bazası: psclub_qa
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Backend = Join-Path $Root 'backend'

$env:DB_HOST = '127.0.0.1'
$env:DB_PORT = '3306'
$env:DB_USER = 'root'
$env:DB_PASS = ''
$env:DB_NAME = 'psclub_qa'

Write-Host "Creating database psclub_qa..."
mysql -h $env:DB_HOST -P $env:DB_PORT -u $env:DB_USER -e "DROP DATABASE IF EXISTS psclub_qa; CREATE DATABASE psclub_qa CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

Push-Location $Backend
try {
    Write-Host "Running migrations..."
    php vendor/bin/phinx migrate -e development
    Write-Host "Seeding DeploySeeder..."
    php vendor/bin/phinx seed:run -s DeploySeeder
    Write-Host "Setting billing_mode min_1h_then_30..."
    php -r "
require 'vendor/autoload.php';
Dotenv\Dotenv::createImmutable(__DIR__)->safeLoad();
`$_ENV['DB_NAME'] = 'psclub_qa';
`$pdo = new PDO(
    'mysql:host=' . (`$_ENV['DB_HOST'] ?? '127.0.0.1') . ';dbname=psclub_qa;charset=utf8mb4',
    `$_ENV['DB_USER'] ?? 'root',
    `$_ENV['DB_PASS'] ?? '',
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);
`$pdo->exec(\"UPDATE businesses SET billing_mode = 'min_1h_then_30', billing_grace_minutes = 10, min_billing_minutes = 60, billing_increment_minutes = 30, min_open_minutes = 60, extend_step_minutes = 30 WHERE id = 1\");
echo \"QA DB ready.\n\";
"
} finally {
    Pop-Location
}

Write-Host "Done. Start API with: scripts/run-api-qa.ps1"
