<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class UniqueCustomerPhone extends AbstractMigration
{
    public function change(): void
    {
        $this->table('customers')
            ->addIndex(['phone'], ['unique' => true, 'name' => 'customers_phone_unique'])
            ->update();
    }
}
