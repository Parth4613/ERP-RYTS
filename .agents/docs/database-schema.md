# Database Schema — Detailed Reference

> All tables follow AD-003: `id, created_at, updated_at, created_by, updated_by, deleted_at, is_active`
> All PKs use `bigint generated always as identity` (AD-001)
> All timestamps use `timestamptz` (AD-004)
> All text columns use `text` not `varchar` (AD-005)
> All FK columns must be indexed (AD-013)

---

## Auth / RBAC

### users
*Extends Supabase `auth.users`. Profile data only.*

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | FK → auth.users(id) |
| full_name | text | |
| avatar_url | text | nullable |
| phone | text | nullable |
| + standard audit cols | | |

### roles
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| name | text not null unique | admin, owner, engineer, store, purchase |
| description | text | |
| + standard audit cols | | |

### permissions
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| module | text not null | projects, inventory, procurement, etc. |
| action | text not null | view, create, edit, approve, delete |
| + standard audit cols | | |

### user_roles
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| user_id | uuid not null → auth.users | **Index** |
| role_id | bigint not null → roles | **Index** |
| project_id | bigint → projects | nullable — project-scoped roles. **Index** |
| + standard audit cols | | |

---

## Projects

### projects
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| name | text not null | |
| client_id | bigint → clients | **Index** |
| status | text | draft, active, on_hold, completed, archived |
| start_date | date | |
| end_date | date | nullable |
| budget | numeric(15,2) | |
| + standard audit cols | | |

**Indexes:** `client_id`, `status` (partial: `where deleted_at is null`)

### project_zones
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| project_id | bigint not null → projects | **Index** |
| name | text not null | |
| description | text | |
| + standard audit cols | | |

---

## BOQ

### boq_headers
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| project_id | bigint not null → projects | **Index** unique per project |
| revision | int not null default 1 | |
| status | text | draft, submitted, approved |
| approved_by | uuid → auth.users | nullable |
| approved_at | timestamptz | nullable |
| + standard audit cols | | |

### boq_items
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| boq_header_id | bigint not null → boq_headers | **Index** |
| material_id | bigint not null → materials | **Index** |
| zone_id | bigint → project_zones | **Index** |
| planned_qty | numeric(15,3) not null | |
| unit_of_measure | text not null | |
| unit_rate | numeric(15,2) | |
| + standard audit cols | | |

---

## Inventory

### material_categories
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| name | text not null | |
| parent_id | bigint → material_categories | nullable — hierarchical. **Index** |

### materials
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| category_id | bigint → material_categories | **Index** |
| code | text unique | |
| name | text not null | |
| unit_of_measure | text not null | |
| min_stock_level | numeric(15,3) default 0 | |
| + standard audit cols | | |

### warehouses
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| name | text not null | |
| location | text | |
| project_id | bigint → projects | nullable. **Index** |
| + standard audit cols | | |

### stock_balances
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| material_id | bigint not null → materials | **Index** |
| warehouse_id | bigint not null → warehouses | **Index** |
| quantity | numeric(15,3) not null default 0 | CHECK (quantity >= 0) — INV-001 |
| reserved_qty | numeric(15,3) not null default 0 | |
| updated_at | timestamptz | |

**Constraint:** `UNIQUE(material_id, warehouse_id)`
**Rule:** Never update directly. Derived from `stock_transactions` (DB-002, INV-003).

### stock_transactions
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| material_id | bigint not null → materials | **Index** |
| warehouse_id | bigint not null → warehouses | **Index** |
| transaction_type | text not null | stock_in, stock_out, issue, return, adjustment |
| quantity | numeric(15,3) not null | positive = in, negative = out |
| reference_type | text | mr, mrn, consumption, adjustment |
| reference_id | bigint | polymorphic FK |
| project_id | bigint → projects | **Index** |
| notes | text | |
| + standard audit cols | | |

**Index:** `(material_id, warehouse_id, created_at)` composite

---

## Material Requests

### material_requests
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| project_id | bigint not null → projects | **Index** |
| zone_id | bigint not null → project_zones | **Index** |
| status | text not null | draft, submitted, approved, issued, closed |
| requested_by | uuid → auth.users | **Index** |
| approved_by | uuid → auth.users | nullable |
| approved_at | timestamptz | nullable |
| + standard audit cols | | |

**Index:** `(project_id, status)` composite

### material_request_items
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| mr_id | bigint not null → material_requests | **Index** |
| material_id | bigint not null → materials | **Index** |
| boq_item_id | bigint → boq_items | **Index** |
| requested_qty | numeric(15,3) not null | |
| approved_qty | numeric(15,3) | nullable until approved |
| issued_qty | numeric(15,3) default 0 | |
| + standard audit cols | | |

---

## Procurement

### purchase_requisitions
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| project_id | bigint → projects | **Index** |
| status | text | draft, submitted, approved, converted, closed |
| priority | text | low, medium, high, urgent |
| required_by | date | |
| approved_by | uuid → auth.users | nullable |
| + standard audit cols | | |

### purchase_requisition_items
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| pr_id | bigint not null → purchase_requisitions | **Index** |
| material_id | bigint not null → materials | **Index** |
| requested_qty | numeric(15,3) not null | |
| approved_qty | numeric(15,3) | |
| estimated_rate | numeric(15,2) | |
| + standard audit cols | | |

### purchase_orders
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| pr_id | bigint → purchase_requisitions | **Index** |
| supplier_id | bigint not null → suppliers | **Index** |
| status | text | draft, sent, acknowledged, partial, received, closed |
| po_date | date not null | |
| delivery_date | date | |
| total_amount | numeric(15,2) | |
| approved_by | uuid → auth.users | nullable |
| + standard audit cols | | |

### purchase_order_items
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| po_id | bigint not null → purchase_orders | **Index** |
| pr_item_id | bigint → purchase_requisition_items | **Index** |
| material_id | bigint not null → materials | **Index** |
| ordered_qty | numeric(15,3) not null | CHECK <= approved PR qty (BR-016) |
| unit_rate | numeric(15,2) not null | |
| received_qty | numeric(15,3) default 0 | |
| + standard audit cols | | |

---

## Suppliers

### suppliers
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| name | text not null | |
| gstin | text | |
| payment_terms | text | |
| + standard audit cols | | |

---

## Receiving (MRN)

### mrn_headers
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| po_id | bigint not null → purchase_orders | **Index** |
| status | text | draft, approved |
| received_date | date not null | |
| + standard audit cols | | |

### mrn_items
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| mrn_id | bigint not null → mrn_headers | **Index** |
| po_item_id | bigint not null → purchase_order_items | **Index** |
| received_qty | numeric(15,3) not null | CHECK <= PO qty (BR-018) |
| accepted_qty | numeric(15,3) not null | |
| rejected_qty | numeric(15,3) not null default 0 | BR-019 |
| rejection_reason | text | |
| + standard audit cols | | |

---

## Site Operations

### consumption_entries
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| mr_item_id | bigint not null → material_request_items | **Index** |
| project_id | bigint not null → projects | **Index** |
| zone_id | bigint → project_zones | **Index** |
| consumed_qty | numeric(15,3) not null | CHECK <= issued qty (BR-021) |
| wastage_qty | numeric(15,3) not null default 0 | BR-023 |
| entry_date | date not null | |
| + standard audit cols | | |

### return_entries
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| mr_item_id | bigint not null → material_request_items | **Index** |
| warehouse_id | bigint not null → warehouses | **Index** |
| returned_qty | numeric(15,3) not null | |
| condition | text | good, damaged |
| + standard audit cols | | |

---

## Approvals

### approval_workflows
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| entity_type | text not null | pr, po, mr, boq, budget |
| entity_id | bigint not null | |
| status | text | pending, approved, rejected |
| + standard audit cols | | |

**Index:** `(entity_type, entity_id)` composite

### approval_logs
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| workflow_id | bigint not null → approval_workflows | **Index** |
| action | text not null | approve, reject, comment |
| actor_id | uuid not null → auth.users | **Index** |
| comment | text | |
| acted_at | timestamptz not null default now() | |

**Immutable — no update/delete policies (APP-004)**
