-- Ləğv edilmiş boş sessiyalar: məhsulsuz, vaxt/məhsul haqqı 0, total 0
UPDATE sessions s
SET s.order_state = 'deleted', s.updated_at = NOW()
WHERE s.status = 'closed'
  AND s.order_state = 'paid'
  AND ROUND(s.total_amount, 2) = 0
  AND ROUND(s.time_charge, 2) = 0
  AND ROUND(s.products_total, 2) = 0
  AND NOT EXISTS (SELECT 1 FROM session_items si WHERE si.session_id = s.id);
