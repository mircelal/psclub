<?php

declare(strict_types=1);

/**
 * @deprecated server-setup.php istifadə edin
 * Köhnə URL uyğunluğu: ?key=... → server-setup.php?action=migrate&key=...
 */

$_GET['action'] = 'migrate';
require __DIR__ . '/server-setup.php';
