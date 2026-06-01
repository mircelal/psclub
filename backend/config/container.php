<?php

declare(strict_types=1);

use App\Modules\Auth\JwtService;
use App\Modules\Audit\AuditService;
use App\Modules\Sessions\ReceiptService;
use App\Modules\Shifts\ShiftService;
use App\Support\BillingCalculator;
use App\Support\Database;
use App\Support\DatabaseClock;
use App\Support\CustomerGroupService;
use App\Support\PromotionService;
use DI\ContainerBuilder;
use Monolog\Handler\StreamHandler;
use Monolog\Logger;
use Psr\Log\LoggerInterface;

$builder = new ContainerBuilder();
$builder->useAutowiring(true);

$builder->addDefinitions([
    LoggerInterface::class => function () {
        $logger = new Logger('psclub');
        $logPath = __DIR__ . '/../storage/logs/app.log';
        if (!is_dir(dirname($logPath))) {
            mkdir(dirname($logPath), 0755, true);
        }
        $logger->pushHandler(new StreamHandler($logPath, Logger::DEBUG));
        return $logger;
    },
    PDO::class => fn () => Database::connect(),
    JwtService::class => fn () => new JwtService(
        $_ENV['JWT_SECRET'] ?? 'dev-secret-change-me',
        (int) ($_ENV['JWT_TTL'] ?? 86400)
    ),
    BillingCalculator::class => fn () => new BillingCalculator(),
    DatabaseClock::class => fn (\Psr\Container\ContainerInterface $c) => new DatabaseClock($c->get(PDO::class)),
    AuditService::class => fn (\Psr\Container\ContainerInterface $c) => new AuditService($c->get(PDO::class)),
    ReceiptService::class => fn (\Psr\Container\ContainerInterface $c) => new ReceiptService($c->get(PDO::class)),
    ShiftService::class => fn (\Psr\Container\ContainerInterface $c) => new ShiftService($c->get(PDO::class)),
    CustomerGroupService::class => fn (\Psr\Container\ContainerInterface $c) => new CustomerGroupService($c->get(PDO::class)),
    PromotionService::class => fn (\Psr\Container\ContainerInterface $c) => new PromotionService(
        $c->get(PDO::class),
        $c->get(CustomerGroupService::class)
    ),
]);

return $builder->build();
