<?php

declare(strict_types=1);

namespace App\Modules\Orders;

final class RefundCalculator
{
    /**
     * @param array{method: string, cash_amount: float|string, card_amount: float|string, total_amount: float|string} $payment
     *
     * @return array{cash_refund: float, card_refund: float}
     */
    public static function splitRefund(float $refundAmount, array $payment): array
    {
        $refundAmount = round($refundAmount, 2);
        if ($refundAmount <= 0) {
            return ['cash_refund' => 0.0, 'card_refund' => 0.0];
        }

        $method = (string) ($payment['method'] ?? 'cash');
        $cash = round((float) ($payment['cash_amount'] ?? 0), 2);
        $card = round((float) ($payment['card_amount'] ?? 0), 2);
        $total = round((float) ($payment['total_amount'] ?? 0), 2);

        if ($method === 'cash') {
            return ['cash_refund' => $refundAmount, 'card_refund' => 0.0];
        }
        if ($method === 'card') {
            return ['cash_refund' => 0.0, 'card_refund' => $refundAmount];
        }

        if ($total <= 0) {
            return ['cash_refund' => 0.0, 'card_refund' => $refundAmount];
        }

        $cashRefund = round($refundAmount * ($cash / $total), 2);
        $cardRefund = round($refundAmount - $cashRefund, 2);

        return ['cash_refund' => $cashRefund, 'card_refund' => $cardRefund];
    }

    /** @param array{opened_at: string, closed_at?: string|null} $shift */
    public static function sessionInShiftWindow(string $closedAt, array $shift): bool
    {
        $openedAt = (string) $shift['opened_at'];
        $endAt = (string) ($shift['closed_at'] ?? date('Y-m-d H:i:s'));

        return $closedAt >= $openedAt && $closedAt <= $endAt;
    }

    /**
     * @param array{method: string, cash_amount: float|string, card_amount: float|string, total_amount: float|string} $payment
     *
     * @return array{cash_amount: float, card_amount: float, total_amount: float, method: string}
     */
    public static function rescalePayment(float $newTotal, array $payment): array
    {
        $newTotal = round(max(0, $newTotal), 2);
        $method = (string) ($payment['method'] ?? 'cash');

        if ($method === 'cash') {
            return [
                'method' => 'cash',
                'cash_amount' => $newTotal,
                'card_amount' => 0.0,
                'total_amount' => $newTotal,
            ];
        }
        if ($method === 'card') {
            return [
                'method' => 'card',
                'cash_amount' => 0.0,
                'card_amount' => $newTotal,
                'total_amount' => $newTotal,
            ];
        }

        $oldTotal = round((float) ($payment['total_amount'] ?? 0), 2);
        if ($oldTotal <= 0) {
            return [
                'method' => 'cash',
                'cash_amount' => $newTotal,
                'card_amount' => 0.0,
                'total_amount' => $newTotal,
            ];
        }

        $oldCash = round((float) ($payment['cash_amount'] ?? 0), 2);
        $newCash = round($newTotal * ($oldCash / $oldTotal), 2);
        $newCard = round($newTotal - $newCash, 2);

        return [
            'method' => 'mixed',
            'cash_amount' => $newCash,
            'card_amount' => $newCard,
            'total_amount' => $newTotal,
        ];
    }
}
