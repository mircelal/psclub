<?php

declare(strict_types=1);

namespace App\Modules\Loyalty;

use App\Support\ApiResponse;
use App\Support\LoyaltyService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

final class LoyaltyController
{
    public function __construct(private readonly LoyaltyService $loyalty)
    {
    }

    public function show(Request $request, Response $response, array $args): Response
    {
        if (!$this->loyalty->tablesExist()) {
            return ApiResponse::error('Loyallıq cədvəlləri mövcud deyil — miqrasiya işlədin', 503);
        }

        $id = (int) $args['id'];

        return ApiResponse::success([
            'balance' => $this->loyalty->getBalance($id),
            'ledger' => $this->loyalty->getLedger($id),
        ]);
    }

    public function grant(Request $request, Response $response, array $args): Response
    {
        return $this->mutate($request, (int) $args['id'], true);
    }

    public function adjust(Request $request, Response $response, array $args): Response
    {
        return $this->mutate($request, (int) $args['id'], false);
    }

    private function mutate(Request $request, int $customerId, bool $grant): Response
    {
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');
        $adminId = (int) ($user['id'] ?? 0);
        $kind = (string) ($body['kind'] ?? '');
        $note = isset($body['note']) ? (string) $body['note'] : null;

        try {
            $result = $grant
                ? $this->loyalty->adminGrant($customerId, $kind, (float) ($body['value'] ?? 0), $note, $adminId)
                : $this->loyalty->adminAdjust($customerId, $kind, (float) ($body['delta'] ?? 0), (string) ($note ?? ''), $adminId);
        } catch (\InvalidArgumentException $e) {
            return ApiResponse::error($e->getMessage(), 422);
        } catch (\RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), 503);
        }

        return ApiResponse::success([
            'balance' => $this->loyalty->getBalance($customerId),
            'ledger' => $this->loyalty->getLedger($customerId),
            'applied' => $result,
        ]);
    }
}
