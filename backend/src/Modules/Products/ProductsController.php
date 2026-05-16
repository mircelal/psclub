<?php

declare(strict_types=1);

namespace App\Modules\Products;

use App\Support\ApiResponse;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;

final class ProductsController
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function indexCategories(Request $request, Response $response): Response
    {
        $stmt = $this->pdo->query('SELECT * FROM product_categories ORDER BY sort_order, id');
        return ApiResponse::success($stmt->fetchAll());
    }

    public function storeCategory(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        if (!v::key('name', v::stringType()->notEmpty())->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }
        $this->pdo->prepare(
            'INSERT INTO product_categories (business_id, name, sort_order, created_at, updated_at) VALUES (1, ?, ?, NOW(), NOW())'
        )->execute([$body['name'], (int) ($body['sort_order'] ?? 0)]);

        return ApiResponse::success(['id' => (int) $this->pdo->lastInsertId()], [], 201);
    }

    public function index(Request $request, Response $response): Response
    {
        $stmt = $this->pdo->query(
            'SELECT p.*, ps.quantity AS stock_quantity, pc.name AS category_name
             FROM products p
             LEFT JOIN product_stock ps ON ps.product_id = p.id
             LEFT JOIN product_categories pc ON pc.id = p.category_id
             WHERE p.is_active = 1
             ORDER BY p.name'
        );
        return ApiResponse::success($stmt->fetchAll());
    }

    public function store(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        $validation = v::key('name', v::stringType()->notEmpty())->key('price', v::numericVal());
        if (!$validation->validate($body)) {
            return ApiResponse::error('Validation failed', 422);
        }

        $this->pdo->beginTransaction();
        try {
            $this->pdo->prepare(
                'INSERT INTO products (business_id, category_id, name, sku, image_url, price, is_active, created_at, updated_at)
                 VALUES (1, ?, ?, ?, NULL, ?, 1, NOW(), NOW())'
            )->execute([
                $body['category_id'] ?? null,
                $body['name'],
                $body['sku'] ?? null,
                (float) $body['price'],
            ]);
            $productId = (int) $this->pdo->lastInsertId();
            $qty = (int) ($body['initial_stock'] ?? 0);
            $this->pdo->prepare(
                'INSERT INTO product_stock (product_id, quantity, created_at, updated_at) VALUES (?, ?, NOW(), NOW())'
            )->execute([$productId, $qty]);
            $this->pdo->commit();
        } catch (\Throwable $e) {
            $this->pdo->rollBack();
            throw $e;
        }

        return ApiResponse::success(['id' => $productId], [], 201);
    }

    public function update(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $body = (array) $request->getParsedBody();
        $fields = [];
        $params = [];
        foreach (['name', 'sku', 'price', 'category_id', 'is_active'] as $key) {
            if (array_key_exists($key, $body)) {
                $fields[] = "{$key} = ?";
                $params[] = $body[$key];
            }
        }
        $hasStock = array_key_exists('stock_quantity', $body);
        if ($fields === [] && !$hasStock) {
            return ApiResponse::error('No fields', 422);
        }
        if ($hasStock) {
            $qty = max(0, (int) $body['stock_quantity']);
            $stock = $this->pdo->prepare('SELECT product_id FROM product_stock WHERE product_id = ?');
            $stock->execute([$id]);
            if ($stock->fetch()) {
                $this->pdo->prepare('UPDATE product_stock SET quantity = ?, updated_at = NOW() WHERE product_id = ?')
                    ->execute([$qty, $id]);
            } else {
                $this->pdo->prepare(
                    'INSERT INTO product_stock (product_id, quantity, created_at, updated_at) VALUES (?, ?, NOW(), NOW())'
                )->execute([$id, $qty]);
            }
        }

        $fields[] = 'updated_at = NOW()';
        $params[] = $id;
        if ($fields !== ['updated_at = NOW()']) {
            $this->pdo->prepare('UPDATE products SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);
        }

        $stmt = $this->pdo->prepare(
            'SELECT p.*, ps.quantity AS stock_quantity, pc.name AS category_name
             FROM products p
             LEFT JOIN product_stock ps ON ps.product_id = p.id
             LEFT JOIN product_categories pc ON pc.id = p.category_id
             WHERE p.id = ?'
        );
        $stmt->execute([$id]);
        $row = $stmt->fetch();

        return ApiResponse::success($row ?: ['updated' => true]);
    }

    public function destroy(Request $request, Response $response, array $args): Response
    {
        $id = (int) $args['id'];
        $this->pdo->prepare('UPDATE products SET is_active = 0, updated_at = NOW() WHERE id = ?')->execute([$id]);
        return ApiResponse::success(['deleted' => true]);
    }
}
