<?php

declare(strict_types=1);

namespace App\Modules\Settings;

use App\Support\ApiResponse;
use App\Support\BusinessBillingColumns;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

final class SettingsController
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    /** Giriş səhifəsi və veb — auth tələb etmir. */
    public function publicIndex(Request $request, Response $response): Response
    {
        $select = BusinessBillingColumns::selectSql($this->pdo, [
            'id', 'name', 'tagline', 'venue_type', 'currency', 'billing_mode', 'time_billing_enabled', 'logo_url',
        ]);
        $stmt = $this->pdo->query("SELECT {$select} FROM businesses WHERE id = 1 LIMIT 1");
        $biz = BusinessBillingColumns::withDefaults($stmt->fetch() ?: []);

        $settingsStmt = $this->pdo->query(
            "SELECT `key`, value FROM settings WHERE business_id = 1 AND `key` IN ('receipt_header', 'receipt_footer')"
        );
        $settings = [];
        foreach ($settingsStmt->fetchAll() as $row) {
            $settings[$row['key']] = $row['value'];
        }

        return ApiResponse::success([
            'business' => $biz,
            'settings' => $settings,
        ]);
    }

    public function index(Request $request, Response $response): Response
    {
        $biz = $this->pdo->query('SELECT * FROM businesses WHERE id = 1')->fetch();
        $stmt = $this->pdo->query('SELECT `key`, value FROM settings WHERE business_id = 1');
        $settings = [];
        foreach ($stmt->fetchAll() as $row) {
            $settings[$row['key']] = $row['value'];
        }

        return ApiResponse::success([
            'business' => $biz,
            'settings' => $settings,
        ]);
    }

    public function update(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();

        if (isset($body['business']) && is_array($body['business'])) {
            $b = $body['business'];
            $fields = [];
            $params = [];
            foreach ([
                'name', 'tagline', 'venue_type', 'currency', 'billing_mode', 'billing_rounding',
                'min_stock_threshold', 'logo_url', 'time_billing_enabled',
                'min_open_minutes', 'extend_step_minutes', 'min_billing_minutes', 'billing_increment_minutes',
                'billing_grace_minutes',
            ] as $key) {
                if (array_key_exists($key, $b)) {
                    $fields[] = "{$key} = ?";
                    $params[] = $b[$key];
                }
            }
            if ($fields !== []) {
                $fields[] = 'updated_at = NOW()';
                $params[] = 1;
                $this->pdo->prepare('UPDATE businesses SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);
            }
        }

        if (isset($body['settings']) && is_array($body['settings'])) {
            foreach ($body['settings'] as $key => $value) {
                $exists = $this->pdo->prepare('SELECT id FROM settings WHERE business_id = 1 AND `key` = ?');
                $exists->execute([$key]);
                if ($exists->fetch()) {
                    $this->pdo->prepare('UPDATE settings SET value = ? WHERE business_id = 1 AND `key` = ?')
                        ->execute([(string) $value, $key]);
                } else {
                    $this->pdo->prepare('INSERT INTO settings (business_id, `key`, value) VALUES (1, ?, ?)')
                        ->execute([$key, (string) $value]);
                }
            }
        }

        return $this->index($request, $response);
    }
}
