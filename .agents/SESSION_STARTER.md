You are a Senior Full-Stack Engineer building a production-grade Gas Pipeline ERP.
Stack: Flutter + Supabase + Clean Architecture.

MANDATORY: Read these files in order before writing any code:

1. .agents/AGENT_CONTEXT.md       ← rules, roles, non-negotiables
2. .agents/PROGRESS.md            ← what's done, what's next
3. .agents/DECISIONS.md           ← locked decisions, do not re-debate
4. .agents/modules/MODULE_MAP.md  ← full spec for all 16 modules
5. .agents/RLS_PATTERNS.md        ← copy-paste RLS policies
6. .agents/flutter/FLUTTER_PATTERNS.md  ← Flutter code structure
7. .agents/ui/UI_SPEC.md          ← design tokens and components

Today's task: [DESCRIBE SPECIFIC TASK]
Example tasks:
  "Build Phase 1: Run phase1_foundation.sql and create auth screens"
  "Build Module 4: Inventory — migration + RLS + repository + screens"
  "Build Issue Slip PDF generator for Module 5"
  "Add BOQ variance tracking computed view for Module 2"

CONSTRAINTS (enforce strictly):
- Use .agents/templates/migration_template.sql for every new table
- Every table: RLS enabled + forced + role policies from RLS_PATTERNS.md
- No hard deletes — soft delete only (deleted_at)
- Inventory NEVER goes negative (DB constraint required)
- All timestamps: timestamptz
- All strings: text (not varchar)
- All PKs: bigint generated always as identity
- RLS functions: (select auth.uid()) not bare auth.uid()
- Role from app_metadata, never user_metadata
- Flutter: AsyncNotifier + Repository + UseCase pattern only
- Every screen: loading state + empty state + error state

BEFORE ENDING THIS SESSION:
1. Update PHASE/LAST_TASK/NEXT_TASK in AGENT_CONTEXT.md
2. Append session entry to PROGRESS.md
3. Add any new decisions to DECISIONS.md
```

---

## Phase-Specific Prompts

### Phase 1 — Foundation
```
Task: Build Phase 1 Foundation

Run .agents/migrations/phase1_foundation.sql via Supabase MCP.
Then build:

1. Flutter project setup
   - pubspec.yaml with all dependencies from FLUTTER_PATTERNS.md
   - Core folder structure as per FLUTTER_PATTERNS.md
   - AppColors + AppTextStyles + ThemeData from UI_SPEC.md
   - Go Router with shell route structure from UI_SPEC.md

2. Auth feature
   - Supabase email/password login
   - Role-based routing after login (admin → dashboard, engineer → projects, etc.)
   - Login screen (dark theme, company logo placeholder)
   - Profile screen

3. Executive Dashboard skeleton (Module 16)
   - KPI cards (hardcoded values for now, wire up in Phase 14)
   - Bottom navigation
   - Role guard (redirect if role doesn't match route)
```

### Phase 2 — Inventory
```
Task: Build Phase 2 Inventory

Create migration: supabase migration new phase2_inventory
Tables needed (use migration_template.sql):
  - material_categories (hierarchical, parent_id)
  - materials (code, name, uom, min_stock_level, hsn_code, is_critical)
  - warehouses (name, location, project_id nullable)
  - stock_balances (material_id, warehouse_id, quantity CHECK>=0, reserved_qty)
  - stock_transactions (type: stock_in|stock_out|return_in|adjustment|transfer)
  - inventory_adjustments (requires approval)

Business rules to enforce via triggers:
  - BR-001: stock_balances.quantity can never go negative
  - BR-002: every write to stock_balances creates a stock_transaction
  - BR-003: stock_balances is only updated via trigger from stock_transactions

Flutter deliverables:
  - InventoryRepository + InventoryRepositoryImpl
  - UseCases: GetStockLevels, RecordTransaction, RequestAdjustment
  - Screens: InventoryDashboard, StockList, TransactionHistory, AdjustmentForm
  - Low stock alert widget (for dashboard)
```

### Phase 3 — Projects + BOQ
```
Task: Build Phase 3 Projects and BOQ

Migrations:
  - supabase migration new phase3_projects
  - supabase migration new phase3_boq

Tables:
  - clients (name, gstin, contact_person, phone)
  - projects (project_code auto PP-YYYY-NNN, all fields from MODULE_MAP.md Module 1)
  - project_zones (project_id, zone_code, name)
  - boq_headers (project_id, revision, status, approval fields)
  - boq_items (boq_header_id, material_id, zone_id, planned_qty, unit_rate)

Business rules:
  - Project code auto-generation trigger: PP-YYYY-NNN sequence
  - Project status flow enforcement trigger
  - BOQ must be approved before MRs can be submitted (check in MR trigger)

BOQ variance view (read-only, no storage):
  CREATE VIEW boq_variance AS
  SELECT boq_item_id,
    bi.planned_qty,
    COALESCE(SUM(mri.requested_qty), 0) as requested_qty,
    COALESCE(SUM(isi.issued_qty), 0) as issued_qty,
    COALESCE(SUM(ce.consumed_qty), 0) as consumed_qty,
    bi.planned_qty - COALESCE(SUM(isi.issued_qty), 0) as remaining_qty
  FROM boq_items bi
  LEFT JOIN material_request_items mri ON mri.boq_item_id = bi.id
  LEFT JOIN issue_slip_items isi ON isi.boq_item_id = bi.id
  LEFT JOIN consumption_entries ce ON ce.boq_item_id = bi.id
  GROUP BY bi.id, bi.planned_qty;

Flutter:
  - ProjectRepository + screens (list, detail tabbed, create, zones)
  - BOQRepository + screens (BOQ detail, variance view, revision history)
```

### Phase 6 — Material Requests
```
Task: Build Phase 6 Material Request System

Migration: supabase migration new phase6_material_requests

Tables:
  - material_requests (all fields from MODULE_MAP.md Module 3)
  - material_request_items

Triggers required:
  - MR number auto-generation: MR-YYYY-NNNN
  - MR status flow enforcement (Draft→Submitted→Approved→Issued→Closed)
  - BR-007: check MR qty vs BOQ planned qty on submit
  - On MR approval: create reserved_qty entries in stock_balances

Flutter:
  - MRRepository + screens (list with filters, detail, create form, approve flow)
  - Material search with BOQ link
  - Qty validation against BOQ on form
  - Push notification on MR status change (Supabase Realtime)
```

### Phase 7 — Store Issuance + PDF
```
Task: Build Phase 7 Store Issuance and Issue Slip PDF

Migration: supabase migration new phase7_issuance

Tables:
  - issue_slips (slip_number auto IS-YYYY-NNNN, mr_id, project_id, pdf_url)
  - issue_slip_items (slip_id, mr_item_id, material_id, issued_qty)

Triggers:
  - On issue_slip approval:
    1. Create stock_transaction (stock_out) per item
    2. Update stock_balances (reduce available, reduce reserved)
    3. Update material_request_items.issued_qty
    4. Update material_request status (partially_issued or fully_issued)

PDF Generation (see FLUTTER_PATTERNS.md pdf section):
  - Issue Slip PDF: company header, project info, items table, signature lines, QR
  - Upload PDF to Supabase Storage: /issue-slips/{year}/{slip_number}.pdf
  - Save PDF URL to issue_slips.pdf_url

WhatsApp Share:
  - Share PDF bytes via share_plus
  - WhatsApp deep link: wa.me with file

Flutter:
  - IssuanceRepository + screens
  - Pending MRs screen (Store view — all approved MRs awaiting issue)
  - Issue form (shows stock levels, warns on shortage)
  - PDF preview screen
  - Share options (WhatsApp, email, download)
```

### Phase 8 — Procurement
```
Task: Build Phase 8 Procurement (PR + PO + Suppliers)

Migrations:
  - supabase migration new phase8_suppliers
  - supabase migration new phase8_procurement

Tables from MODULE_MAP.md Modules 6, 7, 8:
  - suppliers, supplier_contacts, supplier_products, supplier_ratings
  - purchase_requisitions, purchase_requisition_items
  - purchase_orders, purchase_order_items

Key business rules:
  - PR number auto-generation: PR-YYYY-NNNN
  - PO number auto-generation: PO-YYYY-NNNN
  - BR-014: Consolidation check on PR creation
  - BR-015: PO only from approved PR
  - BR-016: PO qty ≤ PR approved qty (trigger)
  - BR-025: PR > ₹50,000 requires Owner approval
  - BR-026: PO > ₹1,00,000 requires Owner approval

Flutter:
  - SupplierRepository + screens (list, detail, rate catalog)
  - PRRepository + screens (list, create, approve, convert to PO)
  - PORepository + screens (list, create, approve, delivery tracking)
  - Purchase Dashboard with pending items and overdue alerts
```

---

## Per-Agent Notes

### Claude Code
```bash
# Read files first
cat .agents/AGENT_CONTEXT.md
cat .agents/PROGRESS.md

# Create migration (never hand-craft filename)
supabase migration new <descriptive_name>

# After changes, run advisors
supabase db advisors

# Test RLS
supabase db query "SET role authenticated; SET request.jwt.claims = '{\"sub\":\"user-uuid\",\"app_metadata\":{\"role\":\"engineer\"}}'; SELECT * FROM projects;"

# Run tests
flutter test
```

### Codex / GPT-4
```
Include AGENT_CONTEXT.md + DECISIONS.md as system message.
Ask for: one migration file + one repository file + one screen file per turn.
Validate each output against MODULE_MAP.md before accepting.
Check that every new table has: RLS enabled, FK indexes, updated_at trigger.
```

### OpenCode
```
Attach as files: AGENT_CONTEXT.md, PROGRESS.md, MODULE_MAP.md, the relevant module section.
Specify output format: "Write the complete Dart file for X, then the SQL migration for Y."
Always request: "After each file, confirm it follows the patterns in FLUTTER_PATTERNS.md."