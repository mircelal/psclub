<?php

declare(strict_types=1);

use App\Application;
use Slim\Factory\AppFactory;

require __DIR__ . '/bootstrap.php';

$appRoot = resolveAppRoot();

require $appRoot . '/vendor/autoload.php';

$dotenv = Dotenv\Dotenv::createImmutable($appRoot);
$dotenv->safeLoad();

date_default_timezone_set($_ENV['APP_TIMEZONE'] ?? 'Asia/Baku');

$container = require $appRoot . '/config/container.php';
AppFactory::setContainer($container);
$app = AppFactory::create();

(require $appRoot . '/config/middleware.php')($app);
(require $appRoot . '/config/routes.php')($app);

$application = new Application($app);
$application->run();
