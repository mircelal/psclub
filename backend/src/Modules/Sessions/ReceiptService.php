<?php

declare(strict_types=1);

namespace App\Modules\Sessions;

use Dompdf\Dompdf;
use Dompdf\Options;
use PDO;

final class ReceiptService
{
    public function __construct(private readonly PDO $pdo)
    {
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
        $settings = $this->getSettings();
        $header = $settings['receipt_header'] ?? 'PS Club';
        $footer = $settings['receipt_footer'] ?? 'Təşəkkür edirik!';

        $lines = [
            ['type' => 'text', 'content' => $header, 'align' => 'center', 'bold' => true],
            ['type' => 'text', 'content' => str_repeat('-', 32)],
            ['type' => 'text', 'content' => 'Masa: ' . $session['table_name']],
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

        $pdfPath = $this->generatePdf($receiptNumber, $lines, $session, $bill);

        return [
            'receipt_number' => $receiptNumber,
            'receipt_lines' => $lines,
            'pdf_url' => $pdfPath ? '/storage/receipts/' . basename($pdfPath) : null,
        ];
    }

    public function generatePdfForSession(int $sessionId): ?string
    {
        $stmt = $this->pdo->prepare('SELECT * FROM receipts WHERE session_id = ? ORDER BY id DESC LIMIT 1');
        $stmt->execute([$sessionId]);
        $receipt = $stmt->fetch();
        if (!$receipt) {
            return null;
        }
        $data = json_decode($receipt['payload'], true);
        $session = $this->pdo->prepare('SELECT s.*, t.name AS table_name FROM sessions s JOIN tables t ON t.id = s.table_id WHERE s.id = ?');
        $session->execute([$sessionId]);
        $sessionRow = $session->fetch();

        return $this->generatePdf($receipt['receipt_number'], $data['lines'] ?? [], $sessionRow, $data['bill'] ?? []);
    }

    private function generatePdf(string $number, array $lines, array $session, array $bill): ?string
    {
        $html = '<html><body style="font-family:DejaVu Sans;font-size:12px;">';
        $html .= '<h3 style="text-align:center;">' . htmlspecialchars($number) . '</h3>';
        foreach ($lines as $line) {
            $style = !empty($line['bold']) ? 'font-weight:bold;' : '';
            $align = isset($line['align']) ? 'text-align:' . $line['align'] . ';' : '';
            $html .= '<p style="' . $style . $align . '">' . htmlspecialchars($line['content'] ?? '') . '</p>';
        }
        $html .= '</body></html>';

        $dir = __DIR__ . '/../../../storage/receipts';
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }

        $options = new Options();
        $options->set('isRemoteEnabled', false);
        $dompdf = new Dompdf($options);
        $dompdf->loadHtml($html);
        $dompdf->setPaper([0, 0, 226.77, 600], 'portrait');
        $dompdf->render();

        $path = $dir . '/' . $number . '.pdf';
        file_put_contents($path, $dompdf->output());

        $this->pdo->prepare('UPDATE receipts SET pdf_path = ? WHERE receipt_number = ?')->execute([$path, $number]);

        return $path;
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
