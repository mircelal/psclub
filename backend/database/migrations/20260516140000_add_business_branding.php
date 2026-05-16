<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddBusinessBranding extends AbstractMigration
{
    public function change(): void
    {
        $this->table('businesses')
            ->addColumn('venue_type', 'string', ['limit' => 30, 'default' => 'gaming', 'after' => 'name'])
            ->addColumn('tagline', 'string', ['limit' => 255, 'null' => true, 'after' => 'venue_type'])
            ->addColumn('logo_url', 'string', ['limit' => 500, 'null' => true, 'after' => 'tagline'])
            ->addColumn('time_billing_enabled', 'boolean', ['default' => true, 'after' => 'billing_mode'])
            ->update();
    }
}
