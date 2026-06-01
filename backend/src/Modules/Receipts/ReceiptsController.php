<?php

declare(strict_types=1);

namespace App\Modules\Receipts;

use App\Modules\Sessions\ReceiptService;
use App\Support\ApiResponse;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

final class ReceiptsController
{
    public function __construct(private readonly ReceiptService $receipts)
    {
    }

    public function pdf(Request $request, Response $response, array $args): Response
    {
        $sessionId = (int) $args['sessionId'];
        $pdf = $this->receipts->renderPdfForSession($sessionId);
        if ($pdf === null || $pdf === '') {
            return ApiResponse::error('Receipt not found or expired (24h)', 404);
        }

        $response = $response->withHeader('Content-Type', 'application/pdf');
        $response = $response->withHeader('Content-Disposition', 'inline; filename="receipt-' . $sessionId . '.pdf"');
        $response = $response->withHeader('Cache-Control', 'no-store');
        $response->getBody()->write($pdf);

        return $response;
    }
}
