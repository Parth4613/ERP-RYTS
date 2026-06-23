ERP Build Progress

> Agents append session entries. Never overwrite previous entries.
> Update module status table after each session.

---

## Module Status

| # | Module | Migration | Indexes | RLS | Triggers | Repo | UseCase | Provider | UI | Tests | ✅ |
|---|--------|-----------|---------|-----|----------|------|---------|----------|----|-------|---|
| Foundation | Auth / Users / Roles | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 1 | Project Management | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 2 | BOQ Management | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 3 | Material Request | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 4 | Inventory | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 5 | Store Issuance + PDF | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 6 | Procurement / PR | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 7 | Purchase / PO | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 8 | Supplier Management | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 9 | MRN | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 10 | Site Consumption | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 11 | Cost Tracking | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 12 | Project Zones | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 13 | Document Management | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 14 | Approval System | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 15 | Reports PDF/Excel | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 16 | Executive Dashboard | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Adv | QR / Barcode / Geo | ⬜ | — | — | — | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Adv | WhatsApp PDF Share | ⬜ | — | — | — | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Adv | Daily Progress Reports | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Adv | Equipment/Vehicle Track | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Adv | AI Demand Forecasting | ⬜ | — | — | — | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |

Legend: ✅ Done · 🔄 In Progress · ⬜ Not Started · ❌ Blocked

---

## Build Order (follow this sequence)

```
Phase 1:  Foundation (auth, users, roles, core structure, router, theme)
Phase 2:  Inventory (materials, warehouses, stock_balances, stock_transactions)
Phase 3:  Projects + Zones + BOQ
Phase 4:  Approval System (needed before MR/PO workflows)
Phase 5:  Material Master (categories, materials)
Phase 6:  Material Request System
Phase 7:  Store Issuance + Issue Slip PDF
Phase 8:  Procurement (PR → PO → Suppliers)
Phase 9:  MRN (Material Receipt Note)
Phase 10: Site Consumption + Returns + Wastage
Phase 11: Cost Tracking
Phase 12: Document Management
Phase 13: Reports (PDF + Excel)
Phase 14: Executive Dashboard
Phase 15: Advanced Features (QR, Barcode, Geo, WhatsApp)
Phase 16: AI Features
```

---

## Supabase Migration Files

| File | Status | Tables Created |
|------|--------|---------------|
| `phase1_foundation.sql` | ⬜ | audit_logs, users, roles, user_roles, permissions |
| `phase2_inventory.sql` | ⬜ | material_categories, materials, warehouses, stock_balances, stock_transactions, inventory_adjustments |
| `phase3_projects.sql` | ⬜ | clients, projects, project_zones |
| `phase3_boq.sql` | ⬜ | boq_headers, boq_items |
| `phase4_approvals.sql` | ⬜ | approval_workflows, approval_steps, approval_logs |
| `phase6_material_requests.sql` | ⬜ | material_requests, material_request_items |
| `phase7_issuance.sql` | ⬜ | issue_slips, issue_slip_items |
| `phase8_procurement.sql` | ⬜ | purchase_requisitions, purchase_requisition_items, purchase_orders, purchase_order_items |
| `phase8_suppliers.sql` | ⬜ | suppliers, supplier_contacts, supplier_products, supplier_ratings |
| `phase9_mrn.sql` | ⬜ | mrn_headers, mrn_items |
| `phase10_consumption.sql` | ⬜ | consumption_entries, return_entries, wastage_entries |
| `phase11_costs.sql` | ⬜ | cost_categories, project_costs, cost_allocations |
| `phase12_documents.sql` | ⬜ | document_categories, documents |
| `phase14_dashboard.sql` | ⬜ | daily_progress_reports, notifications, notification_logs |
| `phase15_advanced.sql` | ⬜ | vehicles, vehicle_logs, equipment, equipment_usage, diesel_logs |

---

## Session Log

<!-- Agents append below. Use this format:

### [YYYY-MM-DD] — [Agent: Claude Code | Codex | OpenCode]
**Phase:** Phase N — Description
**Completed:**
- specific item done
**Files created/modified:**
- path/to/file.dart
- supabase/migrations/xxx.sql
**Next session must:**
- specific next task
**Decisions made:**
- any new decision (also add to DECISIONS.md)
**Blockers:**
- none / describe issue