# Reports Specification — Module 15

> All 7 report types. Each has: data source query, PDF layout, Excel layout.
> Agents implement these in `lib/features/reports/`.

---

## Common PDF Header (all reports)

```dart
pw.Column(children: [
  // Company logo + name
  pw.Row(children: [
    pw.Container(width: 60, height: 60, color: PdfColors.blue),  // logo placeholder
    pw.SizedBox(width: 12),
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('GAS PIPELINE INSTALLATION CO.',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.Text('Material & Inventory ERP System',
        style: const pw.TextStyle(fontSize: 10)),
    ]),
  ]),
  pw.Divider(),
  // Report title + metadata
  pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(reportTitle,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text('Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}'),
        pw.Text('Period: $filterDescription'),
      ]),
    ],
  ),
  pw.SizedBox(height: 16),
])
```

---

## Report 1 — Inventory Report

**Trigger:** Store → Reports → Inventory Report
**Filters:** Warehouse, Category, Stock Status (all / low / out)
**Data source:**

```sql
SELECT
  mc.name AS category,
  m.code,
  m.name AS material_name,
  m.unit_of_measure,
  m.min_stock_level,
  w.name AS warehouse,
  COALESCE(sb.quantity, 0)     AS current_qty,
  COALESCE(sb.reserved_qty, 0) AS reserved_qty,
  COALESCE(sb.quantity - sb.reserved_qty, 0) AS available_qty,
  CASE
    WHEN COALESCE(sb.quantity, 0) = 0                THEN 'Out of Stock'
    WHEN COALESCE(sb.quantity, 0) <= m.min_stock_level THEN 'Low Stock'
    ELSE 'In Stock'
  END AS stock_status
FROM public.materials m
JOIN public.material_categories mc ON mc.id = m.category_id
CROSS JOIN public.warehouses w
LEFT JOIN public.stock_balances sb
  ON sb.material_id = m.id AND sb.warehouse_id = w.id
WHERE m.deleted_at IS NULL AND w.deleted_at IS NULL
  AND ($1::text IS NULL OR w.id = $1::bigint)
  AND ($2::text IS NULL OR mc.id = $2::bigint)
ORDER BY mc.name, m.name, w.name;
```

**PDF columns:** Category | Code | Material | UOM | Min Level | Current | Reserved | Available | Status
**Excel sheets:** Summary (totals), Detail (all rows), Low Stock (filtered)

---

## Report 2 — Project Cost Report

**Trigger:** Owner → Reports → Project Cost Report
**Filters:** Project, Date range, Cost category
**Data source:**

```sql
SELECT
  p.project_code,
  p.name AS project_name,
  p.contract_value,
  cc.name AS cost_category,
  COALESCE(SUM(pc.amount), 0) AS total_cost,
  p.contract_value - COALESCE(SUM(pc.amount), 0) AS cost_remaining,
  ROUND(
    CASE WHEN p.contract_value > 0
    THEN COALESCE(SUM(pc.amount), 0) / p.contract_value * 100
    ELSE 0 END, 2
  ) AS utilization_pct
FROM public.projects p
LEFT JOIN public.project_costs pc
  ON pc.project_id = p.id
  AND pc.cost_date BETWEEN $1 AND $2
  AND pc.deleted_at IS NULL
LEFT JOIN public.cost_categories cc ON cc.id = pc.category_id
WHERE p.deleted_at IS NULL
  AND ($3::text IS NULL OR p.id = $3::bigint)
GROUP BY p.id, p.project_code, p.name, p.contract_value, cc.name
ORDER BY p.project_code, cc.name;
```

**PDF layout:** Project header → cost breakdown table → budget vs actual bar chart
**Excel sheets:** By Project, By Category, Monthly Trend

---

## Report 3 — Supplier Report

**Filters:** Supplier, Date range
**Data source:**

```sql
SELECT
  s.supplier_code,
  s.name AS supplier_name,
  s.rating,
  COUNT(DISTINCT po.id)           AS total_orders,
  COALESCE(SUM(po.total_amount), 0) AS total_order_value,
  COUNT(po.id) FILTER (
    WHERE po.actual_delivery > po.expected_delivery
  )                               AS delayed_orders,
  ROUND(
    COUNT(po.id) FILTER (WHERE po.actual_delivery <= po.expected_delivery)::NUMERIC
    / NULLIF(COUNT(po.id) FILTER (WHERE po.actual_delivery IS NOT NULL), 0) * 100, 1
  )                               AS on_time_delivery_pct,
  AVG(EXTRACT(EPOCH FROM (po.actual_delivery::timestamp - po.expected_delivery::timestamp))
      / 86400) FILTER (WHERE po.actual_delivery > po.expected_delivery) AS avg_delay_days
FROM public.suppliers s
LEFT JOIN public.purchase_orders po
  ON po.supplier_id = s.id
  AND po.po_date BETWEEN $1 AND $2
  AND po.deleted_at IS NULL
WHERE s.deleted_at IS NULL
  AND ($3::text IS NULL OR s.id = $3::bigint)
GROUP BY s.id, s.supplier_code, s.name, s.rating
ORDER BY total_order_value DESC;
```

---

## Report 4 — Material Consumption Report

**Filters:** Project, Zone, Material, Date range
**Data source:**

```sql
SELECT
  p.project_code,
  p.name AS project_name,
  pz.name AS zone_name,
  m.code,
  m.name AS material_name,
  m.unit_of_measure,
  COALESCE(SUM(isi.issued_qty), 0)  AS issued_qty,
  COALESCE(SUM(ce.consumed_qty), 0) AS consumed_qty,
  COALESCE(SUM(re.returned_qty), 0) AS returned_qty,
  COALESCE(SUM(we.wastage_qty), 0)  AS wastage_qty,
  COALESCE(SUM(isi.issued_qty), 0)
    - COALESCE(SUM(ce.consumed_qty), 0)
    - COALESCE(SUM(re.returned_qty), 0)
    - COALESCE(SUM(we.wastage_qty), 0)  AS unaccounted_qty,
  ROUND(
    COALESCE(SUM(we.wastage_qty), 0)
    / NULLIF(COALESCE(SUM(isi.issued_qty), 0), 0) * 100, 2
  )                                   AS wastage_pct
FROM public.projects p
LEFT JOIN public.project_zones pz ON pz.project_id = p.id
LEFT JOIN public.issue_slips isl
  ON isl.project_id = p.id AND isl.status = 'complete'
LEFT JOIN public.issue_slip_items isi ON isi.slip_id = isl.id
LEFT JOIN public.materials m ON m.id = isi.material_id
LEFT JOIN public.consumption_entries ce
  ON ce.issue_slip_item_id = isi.id
  AND ce.entry_date BETWEEN $1 AND $2
  AND ce.deleted_at IS NULL
LEFT JOIN public.return_entries re
  ON re.issue_slip_item_id = isi.id AND re.deleted_at IS NULL
LEFT JOIN public.wastage_entries we
  ON we.issue_slip_item_id = isi.id AND we.deleted_at IS NULL
WHERE p.deleted_at IS NULL
  AND ($3::text IS NULL OR p.id = $3::bigint)
GROUP BY p.id, p.project_code, p.name, pz.name,
         m.id, m.code, m.name, m.unit_of_measure
HAVING COALESCE(SUM(isi.issued_qty), 0) > 0
ORDER BY p.project_code, wastage_pct DESC;
```

---

## Report 5 — BOQ Variance Report

**Filters:** Project, BOQ revision
**Data source:** Use `boq_variance` view (created in phase3 migration)

```sql
SELECT
  p.project_code,
  p.name AS project_name,
  bv.material_name,
  bv.uom,
  bv.planned_qty,
  bv.requested_qty,
  bv.issued_qty,
  bv.consumed_qty,
  bv.returned_qty,
  bv.wastage_qty,
  bv.remaining_qty,
  bv.boq_variance_qty,
  bv.boq_variance_pct,
  bv.total_budgeted_cost,
  bv.issued_qty * (
    SELECT AVG(poi.unit_rate) FROM public.purchase_order_items poi
    WHERE poi.material_id = bv.material_id
  ) AS actual_cost
FROM public.boq_variance bv
JOIN public.projects p ON p.id = bv.project_id
WHERE ($1::text IS NULL OR p.id = $1::bigint)
ORDER BY ABS(bv.boq_variance_pct) DESC;
```

**Color coding:** variance > 10% → red, 5-10% → amber, < 5% → green

---

## Report 6 — Wastage Report

**Filters:** Project, Date range, Material, minimum wastage %
**Data source:**

```sql
SELECT
  p.project_code,
  p.name AS project_name,
  m.name AS material_name,
  m.unit_of_measure,
  we.wastage_reason,
  we.entry_date,
  we.wastage_qty,
  u.full_name AS recorded_by
FROM public.wastage_entries we
JOIN public.projects p    ON p.id  = we.project_id
JOIN public.materials m   ON m.id  = we.material_id
JOIN public.users u       ON u.id  = we.created_by
WHERE we.deleted_at IS NULL
  AND we.entry_date BETWEEN $1 AND $2
  AND ($3::text IS NULL OR p.id = $3::bigint)
ORDER BY we.wastage_qty DESC;
```

---

## Report 7 — Procurement Report

**Filters:** Date range, Status, Supplier
**Data source:**

```sql
SELECT
  pr.pr_number,
  pr.status AS pr_status,
  pr.total_estimated_value,
  po.po_number,
  po.status AS po_status,
  s.name AS supplier_name,
  po.po_date,
  po.expected_delivery,
  po.actual_delivery,
  po.total_amount,
  CASE
    WHEN po.actual_delivery > po.expected_delivery
    THEN EXTRACT(DAY FROM po.actual_delivery::timestamp - po.expected_delivery::timestamp)
    ELSE 0
  END AS delay_days
FROM public.purchase_requisitions pr
LEFT JOIN public.purchase_orders po ON po.pr_id = pr.id
LEFT JOIN public.suppliers s ON s.id = po.supplier_id
WHERE pr.deleted_at IS NULL
  AND pr.created_at BETWEEN $1 AND $2
  AND ($3::text IS NULL OR po.supplier_id = $3::bigint)
ORDER BY pr.created_at DESC;
```

---

## Flutter Report Generation

```dart
// features/reports/domain/usecases/generate_report_usecase.dart

enum ReportType {
  inventory, projectCost, supplier,
  consumption, boqVariance, wastage, procurement
}

enum ReportFormat { pdf, excel }

class GenerateReportUseCase {
  final ReportRepository _repo;
  final StorageService _storage;

  Future<String> call({
    required ReportType type,
    required ReportFormat format,
    required DateTimeRange dateRange,
    Map<String, dynamic> filters = const {},
  }) async {
    // 1. Fetch data
    final data = await _repo.fetchReportData(type, dateRange, filters);

    // 2. Generate file
    final bytes = format == ReportFormat.pdf
        ? await PdfGenerator.generate(type, data, dateRange)
        : await ExcelGenerator.generate(type, data, dateRange);

    // 3. Upload to storage
    final filename = _buildFilename(type, format, dateRange);
    final url = await _storage.uploadReport(bytes, filename);

    return url;
  }

  String _buildFilename(ReportType t, ReportFormat f, DateTimeRange r) {
    final ts  = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final ext = f == ReportFormat.pdf ? 'pdf' : 'xlsx';
    return '${t.name}/$ts.${ext}';
  }
}
```