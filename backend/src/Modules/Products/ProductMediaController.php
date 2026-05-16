<?php

declare(strict_types=1);

namespace App\Modules\Products;

use App\Support\ApiResponse;
use App\Support\ImageProcessor;
use App\Support\MediaUrl;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

final class ProductMediaController
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly ImageProcessor $images
    ) {
    }

    public function serve(Request $request, Response $response, array $args): Response
    {
        $filename = basename($args['filename'] ?? '');
        if ($filename === '' || str_contains($filename, '..')) {
            return ApiResponse::error('Invalid file', 400);
        }

        $path = __DIR__ . '/../../../storage/products/' . $filename;
        if (!is_file($path)) {
            return ApiResponse::error('Not found', 404);
        }

        $mime = mime_content_type($path) ?: 'image/jpeg';
        $response->getBody()->write((string) file_get_contents($path));

        return $response
            ->withHeader('Content-Type', $mime)
            ->withHeader('Cache-Control', 'public, max-age=86400');
    }

    public function upload(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $check = $this->pdo->prepare('SELECT id FROM products WHERE id = ?');
        $check->execute([$id]);
        if (!$check->fetch()) {
            return ApiResponse::error('Product not found', 404);
        }

        $files = $request->getUploadedFiles();
        $file = $files['image'] ?? null;

        if (!$file || $file->getError() !== UPLOAD_ERR_OK) {
            return ApiResponse::error('Image file required', 422);
        }

        if ($file->getSize() > ImageProcessor::MAX_UPLOAD_BYTES) {
            return ApiResponse::error('Image too large (max 8 MB)', 422);
        }

        $ext = strtolower(pathinfo($file->getClientFilename() ?? '', PATHINFO_EXTENSION));
        if (!in_array($ext, ['jpg', 'jpeg', 'png', 'webp', 'gif'], true)) {
            return ApiResponse::error('Invalid image type (JPG, PNG, WEBP, GIF)', 422);
        }

        $dir = __DIR__ . '/../../../storage/products';
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }

        $temp = $dir . '/.tmp_upload_' . $id . '_' . bin2hex(random_bytes(4));
        $file->moveTo($temp);

        $filename = 'product_' . $id . '.jpg';
        $dest = $dir . '/' . $filename;

        try {
            $this->images->saveProductJpeg($temp, $dest);
        } catch (\Throwable $e) {
            @unlink($temp);
            return ApiResponse::error($e->getMessage(), 422);
        }

        @unlink($temp);
        $this->removeOtherVariants($dir, $id);

        $storedUrl = MediaUrl::productImage($filename) . '?v=' . time();

        $this->pdo->prepare('UPDATE products SET image_url = ?, updated_at = NOW() WHERE id = ?')
            ->execute([$storedUrl, $id]);

        return ApiResponse::success([
            'image_url' => $storedUrl,
            'width' => ImageProcessor::PRODUCT_MAX_PX,
            'optimized' => true,
        ]);
    }

    private function removeOtherVariants(string $dir, int $productId): void
    {
        foreach (glob($dir . '/product_' . $productId . '.*') ?: [] as $path) {
            if (!str_ends_with(strtolower($path), '.jpg')) {
                @unlink($path);
            }
        }
    }
}
