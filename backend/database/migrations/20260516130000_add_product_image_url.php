<?php

declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddProductImageUrl extends AbstractMigration
{
    public function change(): void
    {
        $this->table('products')
            ->addColumn('image_url', 'string', ['limit' => 500, 'null' => true, 'after' => 'sku'])
            ->update();
    }
}
