<?php

declare(strict_types=1);

require __DIR__ . '/vendor/autoload.php';

$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->safeLoad();

// build-deploy.ps1 → generate-install-sql.php (müvəqqəti DB, lokal psclub qarışmasın)
if (($buildDb = getenv('PSCLUB_BUILD_DB_NAME')) !== false && $buildDb !== '') {
    $_ENV['DB_NAME'] = $buildDb;
    $_ENV['DB_HOST'] = getenv('PSCLUB_BUILD_DB_HOST') ?: ($_ENV['DB_HOST'] ?? '127.0.0.1');
    $_ENV['DB_PORT'] = getenv('PSCLUB_BUILD_DB_PORT') ?: ($_ENV['DB_PORT'] ?? '3306');
    $_ENV['DB_USER'] = getenv('PSCLUB_BUILD_DB_USER') ?: ($_ENV['DB_USER'] ?? 'root');
    $_ENV['DB_PASS'] = getenv('PSCLUB_BUILD_DB_PASS') ?: ($_ENV['DB_PASS'] ?? '');
}

return [
    'paths' => [
        'migrations' => __DIR__ . '/database/migrations',
        'seeds' => __DIR__ . '/database/seeders',
    ],
    'environments' => [
        'default_migration_table' => 'phinxlog',
        'default_environment' => 'development',
        'development' => [
            'adapter' => 'mysql',
            'host' => $_ENV['DB_HOST'] ?? '127.0.0.1',
            'name' => $_ENV['DB_NAME'] ?? 'psclub',
            'user' => $_ENV['DB_USER'] ?? 'root',
            'pass' => $_ENV['DB_PASS'] ?? '',
            'port' => $_ENV['DB_PORT'] ?? '3306',
            'charset' => 'utf8mb4',
        ],
        'qa' => [
            'adapter' => 'mysql',
            'host' => $_ENV['DB_HOST'] ?? '127.0.0.1',
            'name' => 'psclub_qa',
            'user' => $_ENV['DB_USER'] ?? 'root',
            'pass' => $_ENV['DB_PASS'] ?? '',
            'port' => $_ENV['DB_PORT'] ?? '3306',
            'charset' => 'utf8mb4',
        ],
    ],
];
