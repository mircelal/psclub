<?php

declare(strict_types=1);

namespace App\Support;

use PDO;

/** Qəbz PDF-ləri və DB qeydləri — maksimum 24 saat saxlanılır. */
final class ReceiptCleanup
{
    public const RETENTION_HOURS = 24;

    private const THROTTLE_SECONDS = 3600;

    public static function maybeRun(PDO $pdo, string $storageRoot): void
    {
        $flag = rtrim($storageRoot, '/\\') . '/.receipt_cleanup_last';
        if (is_file($flag) && (time() - (int) filemtime($flag)) < self::THROTTLE_SECONDS) {
            return;
        }

        self::run($pdo, $storageRoot);
        @touch($flag);
    }

    /** @return array{db_deleted: int, files_deleted: int} */
    public static function run(PDO $pdo, string $storageRoot, bool $purgeAllPdfFiles = false): array
    {
        $cutoff = date('Y-m-d H:i:s', time() - self::RETENTION_HOURS * 3600);

        $stmt = $pdo->prepare('DELETE FROM receipts WHERE created_at < ?');
        $stmt->execute([$cutoff]);
        $dbDeleted = $stmt->rowCount();

        $receiptsDir = rtrim($storageRoot, '/\\') . '/receipts';
        $filesDeleted = 0;
        $cutoffTs = time() - self::RETENTION_HOURS * 3600;

        if (is_dir($receiptsDir)) {
            foreach (glob($receiptsDir . '/*.pdf') ?: [] as $file) {
                if ($purgeAllPdfFiles || filemtime($file) < $cutoffTs) {
                    if (@unlink($file)) {
                        $filesDeleted++;
                    }
                }
            }
        }

        return ['db_deleted' => $dbDeleted, 'files_deleted' => $filesDeleted];
    }
}
