<?php

declare(strict_types=1);

namespace App\Support;

final class MediaUrl
{
    /** Verilənlər bazasında saxlanacaq nisbi media yolu. */
    public static function path(string $segment): string
    {
        return '/api/media/' . ltrim($segment, '/');
    }

    public static function businessLogo(): string
    {
        return self::path('business/logo');
    }

    public static function productImage(string $filename): string
    {
        return self::path('products/' . basename($filename));
    }
}
