# Dashboard Queries

> All queries used for the Executive Dashboard (Module 16).
> Agents implement these in DashboardRepository.
> Each query maps to one KPI card or chart widget.

---

## KPI Row 1 — Projects

```sql
-- Active / Delayed / Completed counts
SELECT
  COUNT(*) FILTER (WHERE status = 'active')     AS active_count,
  COUNT(*) FILTER (
    WHERE status = 'active'
    AND end_date < CURRENT_DATE
  )                                              AS delayed_count,
  COUNT(*) FILTER (
    WHERE status = 'completed'
    AND updated_at >= DATE_TRUNC('month', NOW())
  )                                              AS completed_this_month,
  COALESCE(SUM(contract_value), 0)              AS total_contract_value
FROM public.projects
WHERE deleted_at IS NULL;
```

---

## KPI Row 2 — Inventory

```sql
-- Total inventory value, low stock count
SELECT
  COUNT(*) FILTER (WHERE stock_status = 'low_stock')   AS low_stock_count,
  COUNT(*) FILTER (WHERE stock_status = 'out_of_stock') AS out_of_stock_count,
  COUNT(*) FILTER (WHERE is_critical AND stock_status != 'in_stock') AS critical_low_count
FROM public.inventory_summary;

-- Total inventory value (separate query for performance)
SELECT
  COALESCE(SUM(sb.quantity * sp.unit_rate), 0) AS total_inventory_value
FROM public.stock_balances sb
JOIN public.supplier_products sp ON sp.material_id = sb.material_id
WHERE sp.id IN (
  SELECT DISTINCT ON (material_id) id
  FROM public.supplier_products
  WHERE deleted_at IS NULL
  ORDER BY material_id, last_updated DESC
);
```

---

## KPI Row 3 — Procurement

```sql
-- Pending PR value, Active PO value, Overdue deliveries
SELECT
  COALESCE(SUM(pr.total_estimated_value)
    FILTER (WHERE pr.status = 'submitted'), 0)  AS pending_pr_value,
  COUNT(*) FILTER (WHERE pr.status = 'submitted') AS pending_pr_count
FROM public.purchase_requisitions pr
WHERE pr.deleted_at IS NULL;

SELECT
  COALESCE(SUM(po.total_amount)
    FILTER (WHERE po.status IN ('ordered','partially_received')), 0) AS active_po_value,
  COUNT(*) FILTER (
    WHERE po.status IN ('ordered','partially_received')
    AND po.expected_delivery < CURRENT_DATE
  )                                              AS overdue_deliveries_count
FROM public.purchase_orders po
WHERE po.deleted_at IS NULL;
```

---

## KPI Row 4 — Finance

```sql
-- Total cost to date, budget variance
SELECT
  p.id,
  p.name,
  p.contract_value,
  COALESCE(SUM(pc.amount), 0)                  AS total_cost,
  p.contract_value - COALESCE(SUM(pc.amount), 0) AS cost_remaining,
  CASE WHEN p.contract_value > 0
    THEN ROUND((COALESCE(SUM(pc.amount), 0) / p.contract_value * 100)::NUMERIC, 1)
    ELSE 0
  END                                           AS cost_utilization_pct
FROM public.projects p
LEFT JOIN public.project_costs pc
  ON pc.project_id = p.id AND pc.deleted_at IS NULL
WHERE p.deleted_at IS NULL AND p.status IN ('active','on_hold')
GROUP BY p.id, p.name, p.contract_value
ORDER BY total_cost DESC;
```

---

## Alerts Queries

```sql
-- Low stock items (for alert list)
SELECT
  m.id,
  m.name,
  m.unit_of_measure,
  m.min_stock_level,
  m.is_critical,
  COALESCE(sb.quantity, 0)   AS current_qty,
  COALESCE(sb.quantity - sb.reserved_qty, 0) AS available_qty
FROM public.materials m
LEFT JOIN public.stock_balances sb ON sb.material_id = m.id
WHERE m.deleted_at IS NULL
  AND m.is_active = TRUE
  AND COALESCE(sb.quantity, 0) <= m.min_stock_level
ORDER BY m.is_critical DESC, (COALESCE(sb.quantity, 0) / NULLIF(m.min_stock_level, 0)) ASC
LIMIT 20;

-- Overdue PO deliveries
SELECT
  po.id,
  po.po_number,
  po.expected_delivery,
  CURRENT_DATE - po.expected_delivery AS days_overdue,
  s.name AS supplier_name,
  po.total_amount
FROM public.purchase_orders po
JOIN public.suppliers s ON s.id = po.supplier_id
WHERE po.status IN ('ordered', 'partially_received')
  AND po.expected_delivery < CURRENT_DATE
  AND po.deleted_at IS NULL
ORDER BY days_overdue DESC
LIMIT 10;

-- BOQ overrun warnings (>80% consumed of planned)
SELECT
  bv.project_id,
  p.name AS project_name,
  bv.material_name,
  bv.planned_qty,
  bv.issued_qty,
  ROUND((bv.issued_qty / NULLIF(bv.planned_qty, 0) * 100)::NUMERIC, 1) AS consumed_pct
FROM public.boq_variance bv
JOIN public.projects p ON p.id = bv.project_id
WHERE bv.planned_qty > 0
  AND (bv.issued_qty / NULLIF(bv.planned_qty, 0)) > 0.8
ORDER BY consumed_pct DESC
LIMIT 20;

-- High wastage projects (>5% wastage rate)
SELECT
  cs.project_id,
  p.name AS project_name,
  cs.material_name,
  cs.issued_qty,
  cs.total_wastage,
  cs.wastage_pct
FROM public.consumption_summary cs
JOIN public.projects p ON p.id = cs.project_id
WHERE cs.wastage_pct > 5
ORDER BY cs.wastage_pct DESC
LIMIT 20;

-- Pending approvals count by type
SELECT
  entity_type,
  COUNT(*) AS pending_count,
  COALESCE(SUM(total_value), 0) AS pending_value
FROM public.approval_workflows
WHERE status = 'pending'
GROUP BY entity_type;
```

---

## Charts Queries

```sql
-- Monthly cost trend (last 6 months) — for line chart
SELECT
  DATE_TRUNC('month', cost_date) AS month,
  SUM(amount)                    AS total_cost
FROM public.project_costs
WHERE cost_date >= NOW() - INTERVAL '6 months'
  AND deleted_at IS NULL
GROUP BY DATE_TRUNC('month', cost_date)
ORDER BY month;

-- Project status distribution — for pie chart
SELECT status, COUNT(*) AS count
FROM public.projects
WHERE deleted_at IS NULL AND is_active = TRUE
GROUP BY status;

-- Top 10 materials by consumption value — for bar chart
SELECT
  m.name,
  SUM(ce.consumed_qty)                           AS total_consumed,
  SUM(ce.consumed_qty * sp.unit_rate)            AS consumption_value
FROM public.consumption_entries ce
JOIN public.materials m ON m.id = ce.material_id
LEFT JOIN public.supplier_products sp ON sp.material_id = m.id
WHERE ce.deleted_at IS NULL
  AND ce.entry_date >= NOW() - INTERVAL '30 days'
GROUP BY m.id, m.name
ORDER BY consumption_value DESC NULLS LAST
LIMIT 10;

-- Inventory value by category — for donut chart
SELECT
  mc.name AS category,
  COALESCE(SUM(sb.quantity * sp.unit_rate), 0) AS value
FROM public.material_categories mc
JOIN public.materials m ON m.category_id = mc.id
LEFT JOIN public.stock_balances sb ON sb.material_id = m.id
LEFT JOIN public.supplier_products sp ON sp.material_id = m.id
WHERE m.deleted_at IS NULL
GROUP BY mc.id, mc.name
ORDER BY value DESC;
```

---

## Flutter DashboardRepository

```dart
class DashboardRepository {
  final SupabaseClient _client;
  DashboardRepository(this._client);

  Future<DashboardKpis> getKpis() async {
    // Run all KPI queries in parallel
    final results = await Future.wait([
      _client.rpc('get_project_kpis'),      // wraps Project KPI query
      _client.rpc('get_inventory_kpis'),    // wraps Inventory KPI query
      _client.rpc('get_procurement_kpis'),  // wraps Procurement KPI query
      _client.rpc('get_finance_kpis'),      // wraps Finance KPI query
    ]);
    return DashboardKpis.fromResults(results);
  }

  Future<List<AlertItem>> getAlerts() async {
    final results = await Future.wait([
      _client.rpc('get_low_stock_alerts'),
      _client.rpc('get_overdue_po_alerts'),
      _client.rpc('get_boq_overrun_alerts'),
      _client.rpc('get_high_wastage_alerts'),
    ]);
    return AlertItem.fromResults(results);
  }

  Future<List<MonthlyCost>> getMonthlyCostTrend() async {
    final data = await _client.rpc('get_monthly_cost_trend');
    return (data as List).map((r) => MonthlyCost.fromJson(r)).toList();
  }
}
```

---

## Supabase RPC Functions (wrap complex queries)

```sql
-- Create as SECURITY DEFINER functions so RLS doesn't block aggregation

CREATE OR REPLACE FUNCTION public.get_project_kpis()
RETURNS JSON LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  SELECT json_build_object(
    'active_count',           COUNT(*) FILTER (WHERE status = 'active'),
    'delayed_count',          COUNT(*) FILTER (WHERE status = 'active' AND end_date < CURRENT_DATE),
    'completed_this_month',   COUNT(*) FILTER (WHERE status = 'completed' AND updated_at >= DATE_TRUNC('month', NOW())),
    'total_contract_value',   COALESCE(SUM(contract_value), 0)
  )
  FROM public.projects WHERE deleted_at IS NULL;
$$;

-- Repeat pattern for other KPI functions
```