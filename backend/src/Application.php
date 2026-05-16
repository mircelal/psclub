<?php

declare(strict_types=1);

namespace App;

use Slim\App;

final class Application
{
    public function __construct(private readonly App $app)
    {
    }

    public function run(): void
    {
        $this->app->run();
    }
}
