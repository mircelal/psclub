<?php

declare(strict_types=1);

namespace App\Support;

final class StockMovementLabels
{
    public static function labelAz(string $type, mixed $referenceType, mixed $referenceId): string
    {
        $refType = $referenceType !== null ? (string) $referenceType : null;
        $refId = $referenceId !== null ? (int) $referenceId : null;

        if ($type === 'sale' && $refType === 'session' && $refId !== null) {
            return 'Satış (sessiya #' . $refId . ')';
        }
        if ($type === 'in' && $refType === 'session' && $refId !== null) {
            return 'Səbətdən qaytarma (sessiya #' . $refId . ')';
        }
        if ($type === 'in' && $refType === 'refund' && $refId !== null) {
            return 'Qaytarma (sifariş #' . $refId . ')';
        }
        if ($type === 'in' && $refType === 'order_delete' && $refId !== null) {
            return 'Sifariş silindi (#' . $refId . ')';
        }
        if ($type === 'in' && $refType === 'product_create') {
            return 'Məhsul yaradılması (ilkin stok)';
        }
        if ($type === 'adjustment' && $refType === 'product_edit') {
            return 'Admin məhsul stok redaktəsi';
        }
        if ($type === 'in' && $refType === 'manual') {
            return 'Manual anbara giriş';
        }
        if ($type === 'out' && $refType === 'manual') {
            return 'Manual anbardan çıxış';
        }
        if ($type === 'adjustment' && $refType === 'manual') {
            return 'Manual stok düzəlişi';
        }
        if ($type === 'in' && $refType === null) {
            return 'Anbara giriş';
        }
        if ($type === 'out') {
            return 'Anbardan çıxış';
        }
        if ($type === 'adjustment') {
            return 'Stok düzəlişi';
        }
        if ($type === 'sale') {
            return 'Satış';
        }

        return $type;
    }

    public static function actorLabel(?string $fullName, ?string $username): string
    {
        $full = trim((string) $fullName);
        if ($full !== '') {
            return $full;
        }

        $user = trim((string) $username);
        if ($user !== '') {
            return $user;
        }

        return 'Sistem';
    }
}
