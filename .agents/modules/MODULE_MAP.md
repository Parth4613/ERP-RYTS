Module Map — All 16 Modules + Advanced Features

> Full specification for every module. Agents read the relevant section before building.
> Status: ⬜ Not Started · 🔄 In Progress · ✅ Done · ❌ Blocked

---

## MODULE 1 — Project Management
**Status:** ⬜ | **Priority:** P0 | **Phase:** 1

### Purpose
Projects are the center of the ERP. Every MR, BOQ, cost, and consumption entry belongs to a project.

### Tables
- `clients` — client master
- `projects` — master project record  
- `project_zones` — sub-areas (Zone A, B, C...)

### `projects` Fields
| Field | Type | Rules |
|-------|------|-------|
| project_code | text unique | Auto-generated: `PP-YYYY-NNN` |
| name | text not null | |
| client_id | bigint → clients | required, index |
| location | text | city/area |
| contract_value | numeric(15,2) | |
| start_date | date not null | |
| end_date | date | nullable |
| status | text | see flow below |
| assigned_engineer_id | uuid → auth.users | required, index |
| description | text | |

### Status Flow
```
planning → active → on_hold → active (resumable)
active → completed → closed
```
DB trigger enforces valid transitions.

### `project_zones` Fields
| Field | Type | Rules |
|-------|------|-------|
| project_id | bigint not null | index |
| zone_code | text | A, B, C or custom |
| name | text not null | e.g. "Zone A — Andheri" |
| description | text | |

### Screens
- Project list (cards with status chip, progress %)
- Project detail (tabbed: Overview, BOQ, MRs, Costs, Docs, Zones)
- Create/Edit project form
- Assign engineer modal
- Zone management sub-screen

### RLS Summary
- Admin: all
- Owner: read all, no create/delete
- Engineer: read assigned projects only
- Store/Purchase: read all (need project context for MR/PO)

---

## MODULE 2 — BOQ Management
**Status:** ⬜ | **Priority:** P0 | **Phase:** 3

### Purpose
Bill of Quantities is the budget baseline. Every material request is validated against it.
This module alone can save lakhs by catching BOQ overruns early.

### Tables
- `boq_headers` — one per project (versioned with revisions)
- `boq_items` — line items

### `boq_headers` Fields
| Field | Type | Rules |
|-------|------|-------|
| project_id | bigint | unique per revision, index |
| revision | int default 1 | increments on revision |
| status | text | draft, submitted, approved |
| approved_by | uuid | nullable |
| approved_at | timestamptz | nullable |
| notes | text | |

### `boq_items` Fields
| Field | Type | Rules |
|-------|------|-------|
| boq_header_id | bigint | index |
| material_id | bigint → materials | index |
| zone_id | bigint → project_zones | nullable, index |
| planned_qty | numeric(15,3) not null | |
| unit_of_measure | text not null | |
| unit_rate | numeric(15,2) | budgeted cost per unit |
| total_budgeted_cost | numeric(15,2) | computed: planned_qty × unit_rate |

### Tracked Quantities (computed, not stored — derived from transactions)
- `planned_qty` — from boq_items
- `requested_qty` — sum of MR items for this BOQ item
- `issued_qty` — sum of issue_slip items
- `consumed_qty` — sum of consumption_entries
- `returned_qty` — sum of return_entries
- `wastage_qty` — sum of wastage_entries
- `remaining_qty` — `planned_qty - issued_qty`
- `boq_variance` — `requested_qty - planned_qty`
- `cost_variance` — `actual_cost - budgeted_cost`

### Business Rules
- BR-007: MR cannot exceed planned_qty without approval
- BR-008: BOQ revisions require Owner/Admin approval
- BOQ must be approved before any MR can be submitted

### Screens
- BOQ list per project (with variance chips — green/amber/red)
- BOQ detail — line-by-line with tracked quantities
- BOQ upload (CSV import)
- BOQ variance dashboard (compare planned vs actual)
- Revision history

---

## MODULE 3 — Material Request System
**Status:** ⬜ | **Priority:** P0 | **Phase:** 6

### Purpose
Engineer creates a request for materials needed on site. Store checks and issues.

### Tables
- `material_requests` — header
- `material_request_items` — line items

### `material_requests` Fields
| Field | Type | Rules |
|-------|------|-------|
| mr_number | text unique | Auto: `MR-YYYY-NNNN` |
| project_id | bigint not null | index |
| zone_id | bigint | index |
| requested_by | uuid | index |
| required_date | date not null | |
| priority | text | low, medium, high, urgent |
| status | text | see flow |
| approved_by | uuid | nullable |
| approved_at | timestamptz | nullable |
| remarks | text | |

### Status Flow
```
draft → submitted → approved → partially_issued → fully_issued → closed
submitted → rejected (with reason)
```

### `material_request_items` Fields
| Field | Type | Rules |
|-------|------|-------|
| mr_id | bigint not null | index |
| material_id | bigint not null | index |
| boq_item_id | bigint | index (links to BOQ for variance tracking) |
| requested_qty | numeric(15,3) not null | |
| approved_qty | numeric(15,3) | set on approval |
| issued_qty | numeric(15,3) default 0 | updated on each issue |
| unit_of_measure | text | |
| remarks | text | |

### Screens
- MR list (filterable by project, status, priority, date)
- MR detail with item-level status
- Create MR form (material search, BOQ link, qty validation)
- Approve/Reject MR (Owner/Admin)
- MR → Issuance flow (Store view)

---

## MODULE 4 — Inventory Management
**Status:** ⬜ | **Priority:** P0 | **Phase:** 2

### Purpose
Real-time stock visibility. Single source of truth for all material quantities.

### Tables
- `material_categories` — hierarchical
- `materials` — master material list
- `warehouses` — physical storage locations
- `stock_balances` — current qty per material per warehouse
- `stock_transactions` — every movement (immutable audit trail)
- `inventory_adjustments` — approved manual corrections

### `materials` Fields
| Field | Type | Rules |
|-------|------|-------|
| category_id | bigint | index |
| code | text unique | |
| name | text not null | |
| description | text | |
| unit_of_measure | text not null | |
| min_stock_level | numeric(15,3) default 0 | for low-stock alerts |
| hsn_code | text | GST compliance |
| is_critical | boolean default false | flags critical materials |

### `stock_transactions` Types
```
stock_in      — MRN approved (goods received)
stock_out     — material issued to MR
return_in     — material returned from site
adjustment    — approved inventory correction
transfer      — warehouse to warehouse
```

### Inventory Rules
- BR-001: Stock can never go negative — CHECK constraint + trigger
- BR-002: Every movement creates a transaction
- BR-003: Balance is SUM of transactions (never direct edit)
- BR-004: Adjustments require approval (inventory_adjustments table)
- BR-005: Reserved stock cannot be issued to another project

### Tracked Per Material Per Warehouse
- `available_qty` = quantity - reserved_qty
- `reserved_qty` = sum of approved-not-yet-issued MR items
- `ordered_qty` = sum of active PO items not yet received

### Screens
- Inventory dashboard (total value, low stock alerts, warehouse filter)
- Stock level list (searchable, filterable by category/warehouse)
- Stock transaction history (timeline per material)
- Stock adjustment form (requires approval)
- Warehouse management

---

## MODULE 5 — Store Issuance + Issue Slip PDF
**Status:** ⬜ | **Priority:** P0 | **Phase:** 7

### Purpose
Store receives approved MR and issues materials. Generates a PDF Issue Slip.

### Tables
- `issue_slips` — issuance header
- `issue_slip_items` — items issued

### `issue_slips` Fields
| Field | Type | Rules |
|-------|------|-------|
| slip_number | text unique | Auto: `IS-YYYY-NNNN` |
| mr_id | bigint not null | index |
| project_id | bigint not null | index |
| issued_by | uuid | store user |
| issued_at | timestamptz | |
| status | text | partial, complete |
| pdf_url | text | Supabase Storage URL |

### Workflow
```
Approved MR → Store views pending MRs
→ Store checks stock levels (auto-highlighted if short)
→ Store enters actual issue qty (partial or full)
→ System creates stock_transaction (stock_out)
→ Updates stock_balances
→ Updates mr_items.issued_qty
→ Generates PDF Issue Slip
→ Updates MR status (partially_issued or fully_issued)
```

### Issue Slip PDF Contents
- Company logo + header
- Slip number, date, project name, zone
- Engineer name and signature line
- Store person name and signature line
- Table: Material | Unit | Requested | Issued
- QR code linking to digital slip

### Screens
- Pending issuance list (approved MRs awaiting issue)
- Issue form (shows stock availability, warns on shortage)
- Issue slip PDF preview + share (WhatsApp, email)
- Issue history per project

---

## MODULE 6 — Procurement / PR
**Status:** ⬜ | **Priority:** P0 | **Phase:** 8

### Purpose
When stock is insufficient, Store creates a shortage. Shortages are consolidated into a single PR.
**Never create duplicate PRs for the same shortage.**

### Tables
- `purchase_requisitions` — PR header
- `purchase_requisition_items` — line items (consolidated from multiple MRs)

### `purchase_requisitions` Fields
| Field | Type | Rules |
|-------|------|-------|
| pr_number | text unique | Auto: `PR-YYYY-NNNN` |
| project_id | bigint | nullable (can be cross-project) |
| status | text | draft, submitted, approved, converted, closed |
| priority | text | low, medium, high, urgent |
| required_by | date | |
| total_estimated_value | numeric(15,2) | sum of items |
| approved_by | uuid | nullable |
| approved_at | timestamptz | |

### Consolidation Logic
When a shortage exists:
1. Check for existing open PR for same material
2. If exists → add to existing PR item (don't create new PR)
3. If not → create new PR item

BR-014: Shortages consolidated into single PR. Never duplicate.
BR-025: PR > threshold value requires Owner approval.

### Screens
- PR list (pending, approved, converted to PO)
- PR detail with item breakdown
- Create PR from shortage (auto-consolidation shown)
- PR approval screen (Owner/Admin)
- PR → PO conversion

---

## MODULE 7 — Purchase Management / PO
**Status:** ⬜ | **Priority:** P0 | **Phase:** 8

### Purpose
Purchase team generates PO from approved PR. Tracks delivery.

### Tables
- `purchase_orders` — PO header
- `purchase_order_items` — line items

### `purchase_orders` Fields
| Field | Type | Rules |
|-------|------|-------|
| po_number | text unique | Auto: `PO-YYYY-NNNN` |
| pr_id | bigint | index (source PR) |
| supplier_id | bigint not null | index |
| project_id | bigint | index |
| status | text | see flow |
| po_date | date not null | |
| expected_delivery | date | |
| actual_delivery | date | nullable |
| total_amount | numeric(15,2) | |
| payment_terms | text | |
| approved_by | uuid | nullable |
| terms_and_conditions | text | |

### Status Flow
```
draft → approved → ordered → partially_received → fully_received → closed
```

### Business Rules
- BR-015: PO only from approved PR
- BR-016: PO qty ≤ approved PR qty
- BR-026: PO > threshold requires Owner approval

### Purchase Dashboard Shows
- Pending PR count + value
- Approved PR awaiting PO
- Active POs with delivery dates
- Overdue deliveries (highlight in red)
- Supplier performance metrics

### Screens
- PO list with delivery status
- PO detail (linked PR, supplier, items, delivery tracking)
- Create PO from PR
- PO approval (Owner/Admin)
- Delivery delay tracker

---

## MODULE 8 — Supplier Management
**Status:** ⬜ | **Priority:** P1 | **Phase:** 8

### Tables
- `suppliers`
- `supplier_contacts`
- `supplier_products` — catalog with rates
- `supplier_ratings` — performance tracking

### `suppliers` Fields
| Field | Type | Notes |
|-------|------|-------|
| supplier_code | text unique | Auto: `SUP-NNN` |
| name | text not null | |
| gstin | text | |
| pan | text | |
| iso_certified | boolean | |
| payment_terms | text | e.g. "30 days net" |
| address | text | |
| city | text | |
| rating | numeric(3,2) | 0.00–5.00, auto-calculated |

### `supplier_products` Fields
| Field | Type |
|-------|------|
| supplier_id | bigint index |
| material_id | bigint index |
| description | text |
| unit_rate | numeric(15,2) |
| lead_time_days | int |
| last_updated | timestamptz |

### Performance Tracking
- On-time delivery rate
- Order fulfillment rate
- Quality rejection rate
- Average lead time vs promised lead time

### Screens
- Supplier list with rating stars
- Supplier detail (profile, contacts, products, order history, ratings)
- Supplier product catalog (compare rates across suppliers)
- Add/Edit supplier

---

## MODULE 9 — Material Receipt Note (MRN)
**Status:** ⬜ | **Priority:** P0 | **Phase:** 9

### Purpose
When supplier delivers goods, Store creates MRN. Approved MRN triggers inventory update.

### Tables
- `mrn_headers`
- `mrn_items`

### `mrn_headers` Fields
| Field | Type | Rules |
|-------|------|-------|
| mrn_number | text unique | Auto: `MRN-YYYY-NNNN` |
| po_id | bigint not null | index |
| supplier_id | bigint not null | index |
| received_date | date not null | |
| status | text | draft, approved |
| received_by | uuid | store user |
| vehicle_number | text | delivery vehicle |
| dc_number | text | delivery challan |
| invoice_number | text | |

### `mrn_items` Fields
| Field | Type | Rules |
|-------|------|-------|
| mrn_id | bigint not null | index |
| po_item_id | bigint not null | index |
| material_id | bigint not null | index |
| ordered_qty | numeric(15,3) | from PO |
| received_qty | numeric(15,3) not null | CHECK ≤ ordered |
| accepted_qty | numeric(15,3) not null | |
| rejected_qty | numeric(15,3) default 0 | BR-019 |
| rejection_reason | text | required if rejected_qty > 0 |
| warehouse_id | bigint not null | where to stock |

### Workflow
```
Supplier arrives → Store creates MRN draft
→ Records received, accepted, rejected quantities
→ Supervisor approves MRN
→ System creates stock_transaction (stock_in) for accepted_qty
→ Updates stock_balances
→ Updates po_item.received_qty
→ Updates PO status
```

### BR-018 Enforcement: MRN qty ≤ remaining PO qty (trigger)

### Screens
- Create MRN (linked to active PO, shows expected quantities)
- MRN detail with quality check fields
- Approve MRN (triggers inventory update)
- MRN history per supplier / PO

---

## MODULE 10 — Site Consumption Tracking
**Status:** ⬜ | **Priority:** P0 | **Phase:** 10

### Purpose
Huge visibility for management. Engineer records daily material usage. Catches leakage.

### Tables
- `consumption_entries`
- `return_entries`
- `wastage_entries`
- `daily_progress_reports`

### `consumption_entries` Fields
| Field | Type | Rules |
|-------|------|-------|
| issue_slip_item_id | bigint not null | index (issued qty reference) |
| project_id | bigint not null | index |
| zone_id | bigint | index |
| material_id | bigint not null | index |
| consumed_qty | numeric(15,3) not null | CHECK ≤ issued qty |
| entry_date | date not null | |
| work_description | text | what work used this material |
| recorded_by | uuid | engineer |

### `return_entries` Fields
| Field | Type |
|-------|------|
| issue_slip_item_id | bigint index |
| project_id | bigint index |
| material_id | bigint index |
| returned_qty | numeric(15,3) not null |
| warehouse_id | bigint not null |
| condition | text | good, damaged |
| return_date | date not null |

### `wastage_entries` Fields
| Field | Type |
|-------|------|
| issue_slip_item_id | bigint index |
| project_id | bigint index |
| material_id | bigint index |
| wastage_qty | numeric(15,3) not null |
| wastage_reason | text | required |
| entry_date | date not null |

### Key Metrics Shown
- Issued vs Consumed per material per project
- Consumed vs BOQ planned (variance %)
- Wastage % = wastage_qty / issued_qty × 100
- Project leakage = issued_qty - consumed_qty - returned_qty - wastage_qty
- Zone-wise consumption breakdown

### Screens
- Daily consumption entry form (engineer mobile)
- Material return form
- Wastage entry form (requires reason)
- Consumption dashboard per project/zone
- Issued vs Consumed comparison chart

---

## MODULE 11 — Project Cost Tracking
**Status:** ⬜ | **Priority:** P1 | **Phase:** 11

### Tables
- `cost_categories` — Material, Labour, Transport, Equipment, Misc
- `project_costs` — cost entries
- `cost_allocations` — per zone breakdown

### Auto-Calculated Costs
- Material cost = sum of issued materials × unit rates
- Procurement cost = sum of PO amounts
- These update automatically from transactions

### Manual Cost Entries
- Transport cost (per trip or fixed)
- Equipment hire cost
- Labour cost

### Dashboard Shows
- Total cost till date
- Budget vs Actual (per category)
- Monthly cost trend chart
- Project health indicator (green/amber/red)
- Zone-wise cost breakdown

---

## MODULE 12 — Project Zones
**Status:** ⬜ | **Priority:** P0 | **Phase:** 1

See Module 1 — `project_zones` table.
Zones are created as part of project setup.
All MRs, consumption entries, and costs can be tagged to a zone.

---

## MODULE 13 — Document Management
**Status:** ⬜ | **Priority:** P1 | **Phase:** 12

### Storage
Supabase Storage bucket: `project-documents`
Path structure: `/{project_id}/{category}/{filename}`

### `document_categories` Values
- Drawings
- BOQ Files
- Agreements / Contracts
- Invoices
- Test Reports / Quality Docs
- Photographs

### `documents` Fields
| Field | Type |
|-------|------|
| project_id | bigint index |
| category_id | bigint index |
| name | text |
| file_url | text | Supabase Storage URL |
| file_size | bigint | bytes |
| uploaded_by | uuid |
| tags | text[] | searchable |

### Screens
- Document list per project (filterable by category)
- Upload form with category selection
- Document viewer (PDF inline preview)
- Share document (WhatsApp / email link)

---

## MODULE 14 — Approval System
**Status:** ⬜ | **Priority:** P0 | **Phase:** 4

### Tables
- `approval_workflows` — one per approvable entity
- `approval_steps` — each step in a multi-step workflow
- `approval_logs` — immutable history (APP-003, APP-004)

### Approval Triggers
| Entity | Condition | Approver |
|--------|-----------|---------|
| MR | Any MR | Owner or Admin |
| PR | Any PR | Owner or Admin |
| PO | Value > threshold | Owner or Admin |
| BOQ Revision | Any | Owner or Admin |
| Budget Revision | Any | Owner or Admin |
| Project Closure | Any | Owner or Admin |
| Inventory Adjustment | Any | Admin |

### Threshold (configurable in settings)
Default: PO > ₹500,000 requires Owner approval

### Workflow
```
Entity submitted → approval_workflow created (status: pending)
→ Notification sent to approver
→ Approver reviews + approves/rejects with comment
→ approval_log entry created (immutable)
→ Entity status updated
→ Notification sent to requester
```

### Screens
- Approval inbox (Owner/Admin home screen widget)
- Approval detail view
- Approve / Reject with mandatory comment for rejection
- Approval history per entity

---

## MODULE 15 — Reports
**Status:** ⬜ | **Priority:** P1 | **Phase:** 13

### Report Types
| Report | Data | Format |
|--------|------|--------|
| Inventory Report | Stock levels, value, low stock | PDF + Excel |
| Project Cost Report | Budget vs actual per project | PDF + Excel |
| Supplier Report | Performance, orders, delays | PDF + Excel |
| Material Consumption Report | Issued vs consumed, wastage | PDF + Excel |
| BOQ Variance Report | Planned vs actual quantities/costs | PDF + Excel |
| Wastage Report | By project, material, engineer | PDF + Excel |
| Procurement Report | PR/PO status, spend analysis | PDF + Excel |
| Issue Slip | Individual issuance record | PDF only |

### PDF Generation
Use `pdf` + `printing` Flutter packages.
Every PDF has: company logo, generation timestamp, filtered date range, page numbers.

### Excel Export
Use `excel` Flutter package.
One sheet per data section. Include totals row.

### Screens
- Reports list with filter options
- Date range picker
- Export buttons (PDF / Excel)
- WhatsApp share button (pdf share_plus)

---

## MODULE 16 — Executive Dashboard
**Status:** ⬜ | **Priority:** P0 | **Phase:** 14

### Purpose
Owner opens app → sees entire company health instantly. No navigation required.

### KPI Row 1 — Projects
- Active projects count
- Delayed projects (end_date < today, status = active)
- Completed this month
- Total contract value

### KPI Row 2 — Inventory
- Total inventory value (₹)
- Critical stock items count (below min_level)
- Materials on order

### KPI Row 3 — Procurement
- Pending PR value
- Active PO value
- Overdue deliveries count

### KPI Row 4 — Finance
- Total project cost till date
- Budget variance (% over/under)
- Cost by project (bar chart)

### Alerts Section
- 🔴 Low stock items (count + tap to view)
- 🔴 Overdue PO deliveries
- 🟡 BOQ overrun warning (>80% consumed)
- 🟡 High wastage projects (>5%)
- 🔴 Approval pending items

### Charts (fl_chart)
- Monthly cost trend (line chart — last 6 months)
- Project status distribution (pie chart)
- Top materials by consumption (bar chart)
- Inventory value by category (donut chart)

---

## ADVANCED FEATURES

### QR Code Inventory
- Generate QR per material per warehouse
- Scan QR → open material detail instantly
- Packages: `qr_flutter` (generate), `mobile_scanner` (scan)

### Barcode Scanning
- Scan supplier barcode on MRN creation to auto-fill material
- `mobile_scanner` package

### Geo-tagged Material Receipt
- GPS coordinates captured on MRN creation
- Show on map for project tracking
- `geolocator` + `google_maps_flutter`

### Site Photo Uploads
- Engineer uploads photo with consumption entry
- Stored in Supabase Storage: `/{project_id}/site-photos/{date}/{filename}`
- `image_picker` package

### Daily Progress Reports
- Engineer submits daily: work done, materials used, issues faced
- `daily_progress_reports` table
- PDF generation for sharing

### WhatsApp PDF Sharing
- Any PDF (issue slip, report) can be shared via WhatsApp
- `share_plus` package + `url_launcher` for WhatsApp deep link

### AI Demand Forecasting (Future Phase)
- Analyze consumption patterns to predict future material needs
- Auto-suggest PR quantities
- AI cannot approve or modify — recommend only (Constitution AI rules)

### Equipment & Vehicle Tracking
- `equipment`, `equipment_usage`, `vehicle_logs`, `diesel_logs` tables
- Daily diesel consumption entry
- Equipment utilization per project