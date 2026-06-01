<?php

declare(strict_types=1);

namespace App\Modules\Sessions;

use App\Support\ReceiptCleanup;
use Dompdf\Dompdf;
use Dompdf\Options;
use PDO;

final class ReceiptService
{
    private readonly string $storageRoot;

    public function __construct(private readonly PDO $pdo)
    {
        $this->storageRoot = dirname(__DIR__, 3) . '/storage';
    }

    private function setLine(array $session): ?string
    {
        $name = trim((string) ($session['set_name_snapshot'] ?? ''));
        if ($name === '') {
            return null;
        }
        $price = number_format((float) ($session['set_price_snapshot'] ?? 0), 2);

        return "Paket: {$name} — {$price} AZN";
    }

    private function tariffLine(array $session): string
    {
        $rate = number_format((float) $session['hourly_rate_snapshot'], 2);
        $name = trim((string) ($session['tariff_name_snapshot'] ?? ''));
        if ($name !== '') {
            return sprintf('Tarif: %s — %s AZN/saat', $name, $rate);
        }

        return 'Saatlıq: ' . $rate . ' AZN';
    }

    public function buildReceipt(array $session, array $bill, string $method, float $cash, float $card): array
    {
        ReceiptCleanup::maybeRun($this->pdo, $this->storageRoot);

        $settings = $this->getSettings();
        $header = $settings['receipt_header'] ?? 'PS Club';
        $footer = $settings['receipt_footer'] ?? 'Təşəkkür edirik!';

        $tableLabel = ($session['session_type'] ?? 'table') === 'counter'
            ? ($session['table_name'] ?? 'Kassa satışı')
            : ($session['table_name'] ?? 'Masa');

        $lines = [
            ['type' => 'text', 'content' => $header, 'align' => 'center', 'bold' => true],
            ['type' => 'text', 'content' => str_repeat('-', 32)],
            ['type' => 'text', 'content' => 'Masa: ' . $tableLabel],
            ['type' => 'text', 'content' => 'Açılış: ' . $session['opened_at']],
            ['type' => 'text', 'content' => 'Bağlanış: ' . ($session['closed_at'] ?? date('Y-m-d H:i:s'))],
            ['type' => 'text', 'content' => 'Müddət: ' . $bill['active_minutes'] . ' dəq'],
            ['type' => 'text', 'content' => $this->tariffLine($session)],
            ...($this->setLine($session) !== null ? [['type' => 'text', 'content' => $this->setLine($session)]] : []),
            ['type' => 'text', 'content' => 'Vaxt cəmi: ' . number_format($bill['time_charge'], 2) . ' AZN'],
        ];

        foreach ($bill['items'] as $item) {
            $lines[] = [
                'type' => 'text',
                'content' => sprintf(
                    '%s x%d  %s',
                    $item['product_name'],
                    $item['quantity'],
                    number_format((float) $item['unit_price'] * (int) $item['quantity'], 2)
                ),
            ];
        }

        $lines[] = ['type' => 'text', 'content' => str_repeat('-', 32)];
        $lines[] = ['type' => 'text', 'content' => 'Məhsullar: ' . number_format($bill['products_total'], 2) . ' AZN'];
        $lines[] = ['type' => 'text', 'content' => 'ÜMUMİ: ' . number_format($bill['total_amount'], 2) . ' AZN', 'bold' => true];
        $lines[] = ['type' => 'text', 'content' => 'Ödəniş: ' . $method];
        if ($method === 'mixed') {
            $lines[] = ['type' => 'text', 'content' => 'Nağd: ' . number_format($cash, 2) . ' | Kart: ' . number_format($card, 2)];
        }
        $lines[] = ['type' => 'text', 'content' => $footer, 'align' => 'center'];

        $receiptNumber = 'R-' . date('Ymd') . '-' . str_pad((string) $session['id'], 5, '0', STR_PAD_LEFT);
        $payload = json_encode(['lines' => $lines, 'bill' => $bill], JSON_UNESCAPED_UNICODE);

        $this->pdo->prepare(
            'INSERT INTO receipts (session_id, receipt_number, payload, created_at) VALUES (?, ?, ?, NOW())'
        )->execute([(int) $session['id'], $receiptNumber, $payload]);

        $sessionId = (int) $session['id'];

        return [
            'receipt_number' => $receiptNumber,
            'receipt_lines' => $lines,
            // PDF serverdə saxlanmır — lazım olsa API-dən generasiya (24 saat ərzində)
            'pdf_url' => '/api/receipts/' . $sessionId . '/pdf',
        ];
    }

    /** PDF bytes — diskə yazılmır. 24 saatdan köhnə qəbzdə null. */
    public function renderPdfForSession(int $sessionId): ?string
    {
        ReceiptCleanup::maybeRun($this->pdo, $this->storageRoot);

        $stmt = $this->pdo->prepare(
            'SELECT * FROM receipts WHERE session_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? HOUR) ORDER BY id DESC LIMIT 1'
        );
        $stmt->execute([$sessionId, ReceiptCleanup::RETENTION_HOURS]);
        $receipt = $stmt->fetch();
        if (!$receipt) {
            return null;
        }

        $data = json_decode((string) $receipt['payload'], true);
        if (!is_array($data)) {
            return null;
        }

        $session = $this->pdo->prepare(
            'SELECT s.*, t.name AS table_name
             FROM sessions s
             LEFT JOIN tables t ON t.id = s.table_id
             WHERE s.id = ?'
        );
        $session->execute([$sessionId]);
        $sessionRow = $session->fetch();
        if (!$sessionRow) {
            return null;
        }
        if (($sessionRow['session_type'] ?? 'table') === 'counter' && empty($sessionRow['table_name'])) {
            $sessionRow['table_name'] = 'Kassa satışı';
        }

        return $this->renderPdfBytes(
            (string) $receipt['receipt_number'],
            $data['lines'] ?? []
        );
    }

    /** @param list<array<string, mixed>> $lines */
    private function renderPdfBytes(string $number, array $lines): string
    {
        $html = '<html><body style="font-family:DejaVu Sans;font-size:12px;">';
        $html .= '<h3 style="text-align:center;">' . htmlspecialchars($number) . '</h3>';
        foreach ($lines as $line) {
            $style = !empty($line['bold']) ? 'font-weight:bold;' : '';
            $align = isset($line['align']) ? 'text-align:' . $line['align'] . ';' : '';
            $html .= '<p style="' . $style . $align . '">' . htmlspecialchars($line['content'] ?? '') . '</p>';
        }
        $html .= '</body></html>';

        $options = new Options();
        $options->set('isRemoteEnabled', false);
        $dompdf = new Dompdf($options);
        $dompdf->loadHtml($html);
        $dompdf->setPaper([0, 0, 226.77, 600], 'portrait');
        $dompdf->render();

        return (string) $dompdf->output();
    }

    private function getSettings(): array
    {
        $stmt = $this->pdo->query('SELECT `key`, value FROM settings WHERE business_id = 1');
        $settings = [];
        foreach ($stmt->fetchAll() as $row) {
            $settings[$row['key']] = $row['value'];
        }

        return $settings;
    }
}
