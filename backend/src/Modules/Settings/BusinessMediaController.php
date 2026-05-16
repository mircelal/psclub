<?php

declare(strict_types=1);

namespace App\Modules\Settings;

use App\Support\ApiResponse;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

final class BusinessMediaController
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function serve(Request $request, Response $response): Response
    {
        $biz = $this->pdo->query('SELECT logo_url FROM businesses WHERE id = 1')->fetch();
        $url = $biz['logo_url'] ?? '';
        if ($url === '') {
            return ApiResponse::error('No logo', 404);
        }

        $filename = basename(parse_url($url, PHP_URL_PATH) ?: '');
        $path = __DIR__ . '/../../../storage/business/' . $filename;
        if (!is_file($path)) {
            return ApiResponse::error('Not found', 404);
        }

        $mime = mime_content_type($path) ?: 'image/png';
        $response->getBody()->write((string) file_get_contents($path));

        return $response->withHeader('Content-Type', $mime);
    }

    public function upload(Request $request, Response $response): Response
    {
        $files = $request->getUploadedFiles();
        $file = $files['logo'] ?? null;

        if (!$file || $file->getError() !== UPLOAD_ERR_OK) {
            return ApiResponse::error('Logo file required', 422);
        }

        $ext = strtolower(pathinfo($file->getClientFilename(), PATHINFO_EXTENSION));
        if (!in_array($ext, ['jpg', 'jpeg', 'png', 'webp', 'gif'], true)) {
            return ApiResponse::error('Invalid image type', 422);
        }

        $dir = __DIR__ . '/../../../storage/business';
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }

        $filename = 'logo.' . ($ext === 'jpeg' ? 'jpg' : $ext);
        $file->moveTo($dir . '/' . $filename);

        $baseUrl = rtrim($_ENV['APP_URL'] ?? 'http://127.0.0.1:8080', '/');
        $url = $baseUrl . '/api/media/business/logo';

        $this->pdo->prepare('UPDATE businesses SET logo_url = ?, updated_at = NOW() WHERE id = 1')
            ->execute([$url]);

        return ApiResponse::success(['logo_url' => $url]);
    }
}
