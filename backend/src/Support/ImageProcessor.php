<?php

declare(strict_types=1);

namespace App\Support;

final class ImageProcessor
{
    public const PRODUCT_MAX_PX = 400;
    public const PRODUCT_JPEG_QUALITY = 82;
    public const MAX_UPLOAD_BYTES = 8_388_608; // 8 MB

    /**
     * Məhsul şəklini standart JPEG-ə endirir (maks. 400px, keyfiyyət 82).
     */
    public function saveProductJpeg(string $sourcePath, string $destJpegPath, int $maxPx = self::PRODUCT_MAX_PX, int $quality = self::PRODUCT_JPEG_QUALITY): void
    {
        if (!is_file($sourcePath)) {
            throw new \RuntimeException('Source file not found');
        }

        if (filesize($sourcePath) > self::MAX_UPLOAD_BYTES) {
            throw new \RuntimeException('Image too large (max 8 MB)');
        }

        $info = @getimagesize($sourcePath);
        if ($info === false) {
            throw new \RuntimeException('Invalid image file');
        }

        $width = $info[0];
        $height = $info[1];
        $type = $info[2];

        $src = $this->loadImage($sourcePath, $type);
        if ($src === false) {
            throw new \RuntimeException('Unsupported image format');
        }

        $scale = min($maxPx / $width, $maxPx / $height, 1.0);
        $newW = max(1, (int) round($width * $scale));
        $newH = max(1, (int) round($height * $scale));

        $dst = imagecreatetruecolor($newW, $newH);
        if ($dst === false) {
            imagedestroy($src);
            throw new \RuntimeException('Failed to create image');
        }

        $white = imagecolorallocate($dst, 255, 255, 255);
        imagefill($dst, 0, 0, $white);
        imagecopyresampled($dst, $src, 0, 0, 0, 0, $newW, $newH, $width, $height);
        imagedestroy($src);

        $dir = dirname($destJpegPath);
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }

        if (!imagejpeg($dst, $destJpegPath, $quality)) {
            imagedestroy($dst);
            throw new \RuntimeException('Failed to save JPEG');
        }

        imagedestroy($dst);
    }

    /**
     * @return \GdImage|false
     */
    private function loadImage(string $path, int $type): \GdImage|false
    {
        return match ($type) {
            IMAGETYPE_JPEG => @imagecreatefromjpeg($path),
            IMAGETYPE_PNG => @imagecreatefrompng($path),
            IMAGETYPE_GIF => @imagecreatefromgif($path),
            IMAGETYPE_WEBP => function_exists('imagecreatefromwebp') ? @imagecreatefromwebp($path) : false,
            default => false,
        };
    }
}
