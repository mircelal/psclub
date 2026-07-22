<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddSessionItemReturnedDeletedQuantities extends AbstractMigration
{
    public function change(): void
    {
        $this->table('session_items')
            ->addColumn('returned_quantity', 'integer', ['default' => 0, 'signed' => false, 'after' => 'quantity'])
            ->addColumn('deleted_quantity', 'integer', ['default' => 0, 'signed' => false, 'after' => 'returned_quantity'])
            ->update();
    }
}
