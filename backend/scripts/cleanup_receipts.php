<?php

declare(strict_types=1);

/**
 * Köhnə qəbz PDF-ləri və DB qeydlərini silir (24 saatdan köhnə).
 * Bir dəfəlik: php scripts/cleanup_receipts.php --all-pdfs
 */

require __DIR__ . '/../vendor/autoload.php';

use App\Support\Database;
use App\Support\ReceiptCleanup;

$dotenv = Dotenv\Dotenv::createImmutable(dirname(__DIR__));
$dotenv->safeLoad();

$pdo = Database::connect();
$storageRoot = dirname(__DIR__) . '/storage';
$purgeAll = in_array('--all-pdfs', $argv ?? [], true);

$result = ReceiptCleanup::run($pdo, $storageRoot, $purgeAll);

echo 'Receipt cleanup' . ($purgeAll ? ' (all PDF files)' : '') . PHP_EOL;
echo 'DB rows deleted: ' . $result['db_deleted'] . PHP_EOL;
echo 'PDF files deleted: ' . $result['files_deleted'] . PHP_EOL;
echo 'Retention: ' . ReceiptCleanup::RETENTION_HOURS . ' hours' . PHP_EOL;

exit(0);
