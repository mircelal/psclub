<?php

declare(strict_types=1);

/**
 * Modules/* fayllarında App\Support class çağırışlarının import olub-olmadığını yoxlayır.
 * QA suite-in birinci addımı kimi işlədilir.
 */

$root = dirname(__DIR__);
$modulesDir = $root . '/src/Modules';

/** @var array<string, string> shortName => full FQCN */
$supportClasses = [];
foreach (glob($root . '/src/Support/*.php') ?: [] as $file) {
    $base = basename($file, '.php');
    $supportClasses[$base] = 'App\\Support\\' . $base;
}

$failures = 0;

foreach (glob($modulesDir . '/**/*.php') ?: [] as $file) {
    $content = (string) file_get_contents($file);
    if (!preg_match('/namespace\s+([^;]+);/', $content, $nsMatch)) {
        continue;
    }
    $namespace = trim($nsMatch[1]);

    preg_match_all('/\buse\s+([^;]+);/', $content, $useMatches);
    $imports = [];
    foreach ($useMatches[1] as $useLine) {
        foreach (preg_split('/\s*,\s*/', trim($useLine)) as $use) {
            $use = trim($use);
            if ($use === '') {
                continue;
            }
            $parts = preg_split('/\s+as\s+/', $use);
            $fqcn = trim($parts[0]);
            $alias = trim($parts[1] ?? basename(str_replace('\\', '/', $fqcn)));
            $imports[$alias] = $fqcn;
        }
    }

    foreach ($supportClasses as $short => $fqcn) {
        if (!preg_match('/\b' . preg_quote($short, '/') . '::/', $content)) {
            continue;
        }
        if ($namespace === 'App\\Support') {
            continue;
        }
        if (($imports[$short] ?? null) === $fqcn) {
            continue;
        }
        if (str_starts_with($namespace, 'App\\Support')) {
            continue;
        }

        $rel = str_replace('\\', '/', substr($file, strlen($root) + 1));
        echo "FAIL {$rel}: uses {$short}:: but missing `use {$fqcn};`\n";
        $failures++;
    }
}

if ($failures > 0) {
    echo "\n{$failures} import problem(s).\n";
    exit(1);
}

echo "OK module import audit — no missing App\\Support imports.\n";
exit(0);
