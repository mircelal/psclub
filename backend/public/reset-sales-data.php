<?php

declare(strict_types=1);

/**
 * Köhnə satışlar və statistikaları sıfırlayır (masa/tarif/məhsul qalır).
 *
 * 1) .env-ə əlavə edin: RESET_KEY=ozunuz-uzun-gizli-acar
 * 2) Faylı serverə yükləyin (məs. public_html/reset-sales-data.php)
 * 3) Brauzer: https://psapi.sayt.cam/reset-sales-data.php?key=ACAR
 * 4) Uğurdan sonra bu faylı serverdən SİLİN
 */

require __DIR__ . '/bootstrap.php';

$root = resolveAppRoot();

if (!is_file($root . '/vendor/autoload.php')) {
    http_response_code(503);
    header('Content-Type: text/html; charset=utf-8');
    echo '<p>vendor tapılmadı. Faylı API public_html qovluğuna yükləyin.</p>';
    exit;
}

require $root . '/vendor/autoload.php';

$dotenv = Dotenv\Dotenv::createImmutable($root);
$dotenv->safeLoad();

$expectedKey = trim((string) ($_ENV['RESET_KEY'] ?? ''));
$providedKey = trim((string) ($_GET['key'] ?? $_POST['key'] ?? ''));

if ($expectedKey === '' || !hash_equals($expectedKey, $providedKey)) {
    http_response_code(403);
    header('Content-Type: text/html; charset=utf-8');
    echo '<!DOCTYPE html><html lang="az"><head><meta charset="utf-8"><title>403</title></head><body>';
    echo '<h1>Forbidden</h1><p>.env faylında <code>RESET_KEY=...</code> təyin edin və URL-də <code>?key=...</code> göndərin.</p>';
    echo '</body></html>';
    exit;
}

function h(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/** @return list<string> */
function tablesToReset(PDO $pdo): array
{
    $wanted = [
        'coupon_redemptions',
        'receipts',
        'payments',
        'session_items',
        'session_pauses',
        'sessions',
        'cash_movements',
        'shifts',
        'daily_closings',
        'audit_logs',
        'stock_movements',
    ];

    $existing = [];
    foreach ($pdo->query('SHOW TABLES') as $row) {
        $existing[] = (string) array_values($row)[0];
    }

    return array_values(array_filter($wanted, static fn (string $t) => in_array($t, $existing, true)));
}

function renderPage(string $title, string $body, int $status = 200): void
{
    http_response_code($status);
    header('Content-Type: text/html; charset=utf-8');
    echo '<!DOCTYPE html><html lang="az"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">';
    echo '<title>' . h($title) . '</title>';
    echo '<style>body{font-family:system-ui,sans-serif;max-width:640px;margin:2rem auto;padding:0 1rem;line-height:1.5}';
    echo 'code{background:#f0f0f0;padding:.15em .4em;border-radius:4px}';
    echo '.warn{background:#fff3cd;border:1px solid #ffc107;padding:1rem;border-radius:8px;margin:1rem 0}';
    echo '.ok{background:#d1e7dd;border:1px solid #198754;padding:1rem;border-radius:8px}';
    echo '.err{background:#f8d7da;border:1px solid #dc3545;padding:1rem;border-radius:8px}';
    echo 'button{background:#dc3545;color:#fff;border:0;padding:.6rem 1.2rem;border-radius:6px;font-size:1rem;cursor:pointer}';
    echo 'button:disabled{opacity:.5;cursor:not-allowed}</style></head><body>';
    echo '<h1>' . h($title) . '</h1>';
    echo $body;
    echo '<p style="color:#666;font-size:.9rem">PS Club — satış sıfırlama aləti. İş bitəndən sonra faylı silin.</p>';
    echo '</body></html>';
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    $body = '<div class="warn"><strong>Diqqət!</strong> Bu əməliyyat geri qaytarıla bilməz.</div>';
    $body .= '<p><strong>Silinəcək:</strong> bütün sessiyalar, ödənişlər, çeklər, növbələr, kassa hərəkətləri, gün bağlamaları, audit log, stok hərəkət tarixçəsi.</p>';
    $body .= '<p><strong>Qalacaq:</strong> masalar, tariflər, məhsullar, kateqoriyalar, stok miqdarları, müştərilər, kuponlar (istifadə sayı sıfırlanır), paketlər, istifadəçilər, biznes ayarları.</p>';
    $body .= '<p>Bütün masalar <code>empty</code> statusuna qaytarılacaq.</p>';
    $body .= '<form method="post" onsubmit="return confirm(\'Əminsiniz? Bütün satış tarixçəsi silinəcək.\');">';
    $body .= '<input type="hidden" name="key" value="' . h($providedKey) . '">';
    $body .= '<p><label><input type="checkbox" name="confirm" value="yes" required> Bəli, satış və statistikaları sıfırlamaq istəyirəm</label></p>';
    $body .= '<p><button type="submit">Sıfırla</button></p></form>';

    renderPage('Satışları sıfırla', $body);
}

if (($_POST['confirm'] ?? '') !== 'yes') {
    renderPage('Xəta', '<div class="err">Təsdiq qutusu işarələnməyib.</div>', 400);
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

    $countsBefore = [];
    foreach (tablesToReset($pdo) as $table) {
        $countsBefore[$table] = (int) $pdo->query("SELECT COUNT(*) FROM `{$table}`")->fetchColumn();
    }

    $pdo->exec('SET FOREIGN_KEY_CHECKS = 0');

    foreach (tablesToReset($pdo) as $table) {
        $pdo->exec("TRUNCATE TABLE `{$table}`");
    }

    $allTables = [];
    foreach ($pdo->query('SHOW TABLES') as $row) {
        $allTables[] = (string) array_values($row)[0];
    }

    if (in_array('coupons', $allTables, true)) {
        $pdo->exec('UPDATE coupons SET used_count = 0');
    }

    if (in_array('tables', $allTables, true)) {
        $pdo->exec("UPDATE tables SET status = 'empty', updated_at = NOW()");
    }

    $pdo->exec('SET FOREIGN_KEY_CHECKS = 1');

    $body = '<div class="ok"><strong>Uğurlu!</strong> Satış və statistika məlumatları sıfırlandı.</div><ul>';
    foreach ($countsBefore as $table => $count) {
        $body .= '<li><code>' . h($table) . '</code>: ' . $count . ' sətir silindi</li>';
    }
    $body .= '</ul><p>Kassir indi təmiz sistemdən işləyə bilər.</p>';
    $body .= '<p><strong>Təhlükəsizlik:</strong> indi <code>reset-sales-data.php</code> faylını serverdən silin və .env-dən <code>RESET_KEY</code> sətirini silə bilərsiniz.</p>';

    renderPage('Tamamlandı', $body);
} catch (Throwable $e) {
    renderPage('Xəta', '<div class="err">' . h($e->getMessage()) . '</div>', 500);
}
