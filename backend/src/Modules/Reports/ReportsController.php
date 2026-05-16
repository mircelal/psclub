<?php

declare(strict_types=1);

namespace App\Modules\Reports;

use App\Support\ApiResponse;
use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

final class ReportsController
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function daily(Request $request, Response $response): Response
    {
        $date = $request->getQueryParams()['date'] ?? date('Y-m-d');
        return ApiResponse::success($this->buildDailyReport($date));
    }

    private function buildDailyReport(string $date): array
    {
        $sessions = $this->pdo->prepare(
            "SELECT COUNT(*) AS sessions_count,
                    COALESCE(SUM(active_seconds), 0) AS total_seconds,
                    COALESCE(SUM(time_charge), 0) AS time_revenue,
                    COALESCE(SUM(products_total), 0) AS products_revenue,
                    COALESCE(SUM(total_amount), 0) AS total_revenue
             FROM sessions WHERE status = 'closed' AND DATE(closed_at) = ?"
        );
        $sessions->execute([$date]);
        $summary = $sessions->fetch();

        $payments = $this->pdo->prepare(
            "SELECT p.method, SUM(p.total_amount) AS total, SUM(p.cash_amount) AS cash, SUM(p.card_amount) AS card
             FROM payments p
             JOIN sessions s ON s.id = p.session_id
             WHERE DATE(s.closed_at) = ?
             GROUP BY p.method"
        );
        $payments->execute([$date]);

        $products = $this->pdo->prepare(
            "SELECT si.product_name, SUM(si.quantity) AS qty, SUM(si.quantity * si.unit_price) AS revenue
             FROM session_items si
             JOIN sessions s ON s.id = si.session_id
             WHERE s.status = 'closed' AND DATE(s.closed_at) = ?
             GROUP BY si.product_name ORDER BY revenue DESC"
        );
        $products->execute([$date]);

        return [
            'date' => $date,
            'summary' => $summary,
            'payments' => $payments->fetchAll(),
            'product_breakdown' => $products->fetchAll(),
        ];
    }

    public function dashboard(Request $request, Response $response): Response
    {
        $params = $request->getQueryParams();
        $from = $params['from'] ?? date('Y-m-d', strtotime('-30 days'));
        $to = $params['to'] ?? date('Y-m-d');

        $period = fn (string $f, string $t) => $this->aggregatePeriod($f, $t);

        $overview = [
            'today' => $period(date('Y-m-d'), date('Y-m-d')),
            'week' => $period(date('Y-m-d', strtotime('monday this week')), date('Y-m-d')),
            'month' => $period(date('Y-m-01'), date('Y-m-d')),
            'range' => $period($from, $to),
        ];

        $tables = $this->pdo->prepare(
            "SELECT t.id, t.name,
                    COUNT(s.id) AS sessions_count,
                    COALESCE(SUM(s.time_charge), 0) AS time_revenue,
                    COALESCE(SUM(s.products_total), 0) AS products_revenue,
                    COALESCE(SUM(s.total_amount), 0) AS total_revenue,
                    COALESCE(SUM(s.active_seconds), 0) AS total_seconds
             FROM tables t
             LEFT JOIN sessions s ON s.table_id = t.id
                AND s.status = 'closed' AND DATE(s.closed_at) BETWEEN ? AND ?
             WHERE t.is_active = 1
             GROUP BY t.id, t.name
             ORDER BY total_revenue DESC"
        );
        $tables->execute([$from, $to]);

        $daily = $this->pdo->prepare(
            "SELECT DATE(closed_at) AS day,
                    COUNT(*) AS sessions,
                    SUM(total_amount) AS revenue,
                    SUM(time_charge) AS time_revenue,
                    SUM(products_total) AS products_revenue
             FROM sessions
             WHERE status = 'closed' AND DATE(closed_at) BETWEEN ? AND ?
             GROUP BY DATE(closed_at) ORDER BY day"
        );
        $daily->execute([$from, $to]);

        $topProducts = $this->pdo->prepare(
            "SELECT si.product_name, SUM(si.quantity) AS qty, SUM(si.quantity * si.unit_price) AS revenue
             FROM session_items si
             JOIN sessions s ON s.id = si.session_id
             WHERE s.status = 'closed' AND DATE(s.closed_at) BETWEEN ? AND ?
             GROUP BY si.product_name ORDER BY revenue DESC LIMIT 10"
        );
        $topProducts->execute([$from, $to]);

        $activeTable = $this->pdo->query(
            "SELECT COUNT(*) AS cnt FROM sessions
             WHERE status IN ('active','paused') AND table_id IS NOT NULL"
        )->fetch();
        $activeCounter = $this->pdo->query(
            "SELECT COUNT(*) AS cnt FROM sessions
             WHERE status IN ('active','paused') AND table_id IS NULL"
        )->fetch();

        $payments = $this->pdo->prepare(
            "SELECT p.method, SUM(p.total_amount) AS total
             FROM payments p
             JOIN sessions s ON s.id = p.session_id
             WHERE DATE(s.closed_at) BETWEEN ? AND ?
             GROUP BY p.method"
        );
        $payments->execute([$from, $to]);

        return ApiResponse::success([
            'from' => $from,
            'to' => $to,
            'overview' => $overview,
            'tables' => $tables->fetchAll(),
            'daily_trend' => $daily->fetchAll(),
            'top_products' => $topProducts->fetchAll(),
            'payment_methods' => $payments->fetchAll(),
            'active_sessions' => (int) ($activeTable['cnt'] ?? 0) + (int) ($activeCounter['cnt'] ?? 0),
            'active_table_sessions' => (int) ($activeTable['cnt'] ?? 0),
            'active_counter_sessions' => (int) ($activeCounter['cnt'] ?? 0),
        ]);
    }

    private function aggregatePeriod(string $from, string $to): array
    {
        $stmt = $this->pdo->prepare(
            "SELECT COUNT(*) AS sessions_count,
                    COALESCE(SUM(time_charge), 0) AS time_revenue,
                    COALESCE(SUM(products_total), 0) AS products_revenue,
                    COALESCE(SUM(total_amount), 0) AS total_revenue,
                    COALESCE(SUM(active_seconds), 0) AS total_seconds
             FROM sessions
             WHERE status = 'closed' AND DATE(closed_at) BETWEEN ? AND ?"
        );
        $stmt->execute([$from, $to]);

        return $stmt->fetch() ?: [];
    }

    public function summary(Request $request, Response $response): Response
    {
        $params = $request->getQueryParams();
        $from = $params['from'] ?? date('Y-m-01');
        $to = $params['to'] ?? date('Y-m-d');

        $stmt = $this->pdo->prepare(
            "SELECT DATE(closed_at) AS day,
                    COUNT(*) AS sessions,
                    SUM(total_amount) AS revenue,
                    SUM(active_seconds) AS seconds
             FROM sessions
             WHERE status = 'closed' AND DATE(closed_at) BETWEEN ? AND ?
             GROUP BY DATE(closed_at) ORDER BY day"
        );
        $stmt->execute([$from, $to]);

        return ApiResponse::success($stmt->fetchAll());
    }

    public function dailyClose(Request $request, Response $response): Response
    {
        $body = (array) $request->getParsedBody();
        $user = $request->getAttribute('user');
        $date = $body['date'] ?? date('Y-m-d');

        $exists = $this->pdo->prepare('SELECT id FROM daily_closings WHERE business_id = 1 AND closing_date = ?');
        $exists->execute([$date]);
        if ($exists->fetch()) {
            return ApiResponse::error('Day already closed', 409);
        }

        $snapshot = $this->buildDailyReport($date);

        $this->pdo->prepare(
            'INSERT INTO daily_closings (business_id, closing_date, snapshot, closed_by, created_at) VALUES (1, ?, ?, ?, NOW())'
        )->execute([$date, json_encode($snapshot, JSON_UNESCAPED_UNICODE), (int) $user['id']]);

        return ApiResponse::success(['closed' => true, 'date' => $date]);
    }
}
