# Gas Pipeline ERP — Master Agent Context

> **READ THIS FIRST. Every session. Every agent. No exceptions.**
> Claude Code · Codex · OpenCode — same rules, same patterns, same output quality.

---

## What This ERP Is

A **production-grade operational ERP** for a Gas Pipeline Installation Company
running multiple simultaneous projects across cities.

**This is NOT a CRUD app.** It is a daily operational tool used by:
- Project Engineers (on-site, mobile-first)
- Store Department (warehouse, issuance)
- Purchase Department (procurement, vendors)
- Management / Owners (dashboards, approvals, cost visibility)

**Target feel:** ₹50 lakh custom enterprise platform — Linear + Stripe Dashboard + Notion.
**Primary device:** Mobile (on-site field use). Desktop for management.

---

## Tech Stack (Locked — AD-009 through AD-012)

| Layer | Technology | Notes |
|-------|-----------|-------|
| Frontend | Flutter + Material 3 | Mobile-first |
| State | Riverpod (AsyncNotifier) | No BLoC, no setState for logic |
| Navigation | Go Router | Shell routes for bottom nav |
| Models | Freezed + JsonSerializable | All models are immutable |
| Backend | Supabase | Postgres + Auth + Realtime + Storage |
| Architecture | Clean Architecture + Feature First | Strict layer separation |
| PDF | pdf / printing package | Issue slips, reports |
| Charts | fl_chart | All dashboards |

---

## Current Build State

<!-- AGENT: Update this block at END of every session before stopping -->

```
PHASE:         Phase 2 — Inventory (In Progress)
LAST_TASK:     Implemented Phase 2 Inventory module: data models, repository, use cases, Riverpod providers, widgets, and 4 screens (Dashboard, Stock List, Transaction History, Adjustment Form). Integrated with router and bottom navigation.
NEXT_TASK:     Implement Unit Tests for Phase 2 Inventory / Move to Phase 3 — Projects + Zones + BOQ
BLOCKED_BY:    none
LAST_AGENT:    Antigravity
SESSION_DATE:  2026-06-28
SUPABASE_REF:  tkijmttpqhiebmnkvdgv
FLUTTER_PKG:   gas_company
```

---

## Mandatory Reading Order (New Session)

**Read every file in this order. Do not skip any.**

```
1.  .agents/AGENT_CONTEXT.md                        ← this file
2.  .agents/PROGRESS.md                             ← what is done / what is next
3.  .agents/DECISIONS.md                            ← locked decisions, never re-debate
4.  .agents/modules/MODULE_MAP.md                   ← full spec for all 16 modules
5.  .agents/docs/erp-constitution.md                ← supreme law, overrides everything
6.  .agents/docs/business-rules.md                  ← BR-001 to BR-037 with SQL
7.  .agents/docs/permissions-matrix.md              ← RBAC per module per role
8.  .agents/docs/database-schema.md                 ← all tables with types + indexes
9.  .agents/RLS_PATTERNS.md                         ← copy-paste RLS policies
10. .agents/BUSINESS_RULES_SQL.md                   ← triggers for every BR
11. .agents/flutter/FLUTTER_PATTERNS.md             ← Flutter code conventions
12. .agents/ui/UI_SPEC.md                           ← design tokens, components, theme
13. .agents/context/NOTIFICATION_SYSTEM.md          ← DB triggers for all notifications
14. .agents/context/SETTINGS_MODULE.md              ← app_settings table + Settings screen
15. .agents/context/TESTING_GUIDE.md                ← test patterns for all UseCases
16. .agents/context/DASHBOARD_QUERIES.md            ← SQL + Flutter for executive dashboard
17. .agents/context/REALTIME_SUBSCRIPTIONS.md       ← Supabase Realtime subscription patterns
18. .agents/context/REPORT_SPEC.md                  ← all 7 report types with SQL + PDF layout
19. .agents/context/SUPABASE_STORAGE_STRUCTURE.md   ← bucket names, paths, storage service
20. .agents/context/ADVANCED_FEATURES_SPEC.md       ← Phase 15: QR, Barcode, Equipment, DPR
```

---

## The 16 Modules

| # | Module | Priority | Phase | Status |
|---|--------|----------|-------|--------|
| 1 | Project Management | P0 | 1 | ⬜ |
| 2 | BOQ Management | P0 | 3 | ⬜ |
| 3 | Material Request System | P0 | 6 | ⬜ |
| 4 | Inventory Management | P0 | 2 | ⬜ |
| 5 | Store Issuance + Issue Slip PDF | P0 | 7 | ⬜ |
| 6 | Procurement / PR | P0 | 8 | ⬜ |
| 7 | Purchase Management / PO | P0 | 8 | ⬜ |
| 8 | Supplier Management | P1 | 8 | ⬜ |
| 9 | Material Receipt Note (MRN) | P0 | 9 | ⬜ |
| 10 | Site Consumption Tracking | P0 | 10 | ⬜ |
| 11 | Project Cost Tracking | P1 | 11 | ⬜ |
| 12 | Project Zones | P0 | 1 | ⬜ |
| 13 | Document Management | P1 | 12 | ⬜ |
| 14 | Approval System | P0 | 4 | ⬜ |
| 15 | Reports (PDF + Excel) | P1 | 13 | ⬜ |
| 16 | Executive Dashboard | P0 | 1 | ⬜ |

---

## Roles

| Role | Code | Key Permissions |
|------|------|----------------|
| Admin | `admin` | Full access + system config + user management |
| Owner | `owner` | Approve all, view all, financial reports |
| Project Engineer | `engineer` | MRs, site consumption, daily progress, docs |
| Store Department | `store` | Inventory, issuance, MRN, stock adjustments |
| Purchase Department | `purchase` | PR, PO, supplier management |

Role is stored in `auth.users.raw_app_meta_data->>'role'` (set server-side only).

---

## Non-Negotiable Database Rules

| Code | Rule |
|------|------|
| DB-004 | No hard deletes — `deleted_at timestamptz` always |
| DB-005 | All tables: `id, created_at, updated_at, created_by, updated_by, deleted_at, is_active` |
| DB-008 | Every table has RLS enabled AND forced. Zero exceptions. |
| AD-001 | PKs: `bigint generated always as identity` only |
| AD-004 | `timestamptz` always, never plain `timestamp` |
| AD-005 | `text` not `varchar(n)` |
| AD-007 | RLS: `(select auth.uid())` never bare `auth.uid()` |
| AD-008 | Role from `app_metadata` only, never `user_metadata` |
| INV-001 | Inventory NEVER goes negative — DB constraint + trigger |
| INV-002 | Every stock movement = one `stock_transactions` row |

---

## Non-Negotiable Flutter Rules

| Code | Rule |
|------|------|
| AP-001 | Clean Architecture — layers never mix |
| AP-004 | Data flow: UI → Provider → UseCase → Repository → Supabase |
| AP-002 | Feature-first: `lib/features/<name>/data\|domain\|presentation` |
| UI-001 | Mobile-first design always |
| UI-003 | Every screen: Loading + Empty + Error state |
| UI-004 | Every table: Search + Filter + Sort + Export |
| UI-006 | Theme: Premium dark (see UI_SPEC.md tokens) |

---

## Critical Business Rules

| BR | Rule | Enforcement |
|----|------|-------------|
| BR-007 | MR qty cannot exceed BOQ qty without approval | DB function check |
| BR-012 | MR flow: Draft→Submitted→Approved→Issued→Closed | DB trigger |
| BR-013 | Closed MR cannot be edited | DB trigger |
| BR-016 | PO qty ≤ approved PR qty | DB trigger |
| BR-018 | MRN qty ≤ PO qty | DB trigger |
| BR-021 | Consumed qty ≤ issued qty | Repository + DB check |
| BR-029 | No hard deletes | No DELETE RLS policy for any role |
| BR-030 | All critical actions logged | Audit trigger on critical tables |

---

## Definition of Done Per Module

A module is **not complete** until ALL of these exist:

```
□ Migration file committed to supabase/migrations/
□ All FK columns indexed
□ RLS: enabled + forced + policies for every role
□ Business rule triggers installed
□ Audit trigger attached (critical tables)
□ Repository class with BaseRepository extension
□ UseCase classes for each operation
□ Riverpod provider (AsyncNotifier)
□ UI screens: list + detail + create/edit
□ Loading / Empty / Error states on all screens
□ Unit tests for UseCases
□ PROGRESS.md updated
```

---

## Agent Handoff Checklist

**Run before ending every session:**

```
□ Update PHASE/LAST_TASK/NEXT_TASK block above
□ Append session entry to .agents/PROGRESS.md
□ Record new decisions in .agents/DECISIONS.md
□ Confirm all new tables: RLS enabled + forced
□ Confirm all FK columns have indexes
□ Confirm migration runs: supabase db reset (test locally)
□ Note blockers in BLOCKED_BY