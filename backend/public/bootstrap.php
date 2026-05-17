<?php

declare(strict_types=1);

/**
 * DirectAdmin upload strukturundan asılı olmayaraq layihə kökünü tapır.
 *
 * Düzgün:  domain/site-root/vendor + domain/public_html/index.php
 * Alternativ: hamısı public_html içində (vendor ilə yanaşı index.php)
 */
function resolveAppRoot(): string
{
    $candidates = [
        dirname(__DIR__),
        __DIR__,
    ];

    foreach ($candidates as $root) {
        if (is_file($root . '/vendor/autoload.php')) {
            return $root;
        }
    }

    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'error' => 'vendor/autoload.php tapılmadı',
        'hint' => 'site-root/ məzmununu public_html-dən BİR SƏVİYYƏ YUXARI yükləyin, '
            . 'və ya zip-dəki public_html_FULL/ məzmununu birbaşa public_html-ə atın.',
        'public_dir' => __DIR__,
        'checked_roots' => $candidates,
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    exit(1);
}
