<?php

declare(strict_types=1);

namespace App\Support;

final class PhoneNormalizer
{
    /** Azərbaycan mobil: +994XXXXXXXXX (9 rəqəm) */
    public static function normalize(?string $phone): ?string
    {
        if ($phone === null) {
            return null;
        }
        $digits = preg_replace('/\D+/', '', trim($phone)) ?? '';
        if ($digits === '') {
            return null;
        }
        if (str_starts_with($digits, '994')) {
            $digits = substr($digits, 3);
        } elseif (str_starts_with($digits, '0')) {
            $digits = substr($digits, 1);
        }
        if (strlen($digits) !== 9) {
            return null;
        }

        return '+994' . $digits;
    }

    public static function isValid(?string $phone): bool
    {
        return self::normalize($phone) !== null;
    }
}
