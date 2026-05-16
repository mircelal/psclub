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
        $path = $this->receipts->generatePdfForSession($sessionId);
        if (!$path || !file_exists($path)) {
            return ApiResponse::error('Receipt not found', 404);
        }

        $response = $response->withHeader('Content-Type', 'application/pdf');
        $response->getBody()->write((string) file_get_contents($path));
        return $response;
    }
}
