# ERP Constitution

## Purpose

This document defines the non-negotiable architectural, business, security, and development principles for the Gas Pipeline ERP.

All generated code, database structures, workflows, UI designs, reports, and integrations must comply with this constitution.

If any generated solution conflicts with this document, this document takes precedence.

---

# Core Mission

The ERP exists to:

* Eliminate material leakage.
* Eliminate inventory mismatches.
* Improve project profitability.
* Improve procurement efficiency.
* Provide real-time project visibility.
* Ensure complete operational accountability.
* Become the company's single source of truth.

---

# Architectural Principles

## AP-001

Follow Clean Architecture.

Layers:

* Presentation
* Domain
* Data

Never mix responsibilities.

---

## AP-002

Follow Feature First Structure.

Features must remain isolated.

Each feature owns:

* Models
* Repositories
* Services
* Providers
* Screens
* Widgets

---

## AP-003

Business logic must never exist inside UI widgets.

Widgets are presentation only.

---

## AP-004

Repository Pattern is mandatory.

UI → Provider → Use Case → Repository → Supabase

Direct database calls from UI are forbidden.

---

## AP-005

All modules must be independently scalable.

---

## AP-006

No tightly coupled code.

Always favor abstraction.

---

# Database Principles

## DB-001

Database is the source of truth.

Never store duplicated business-critical data.

---

## DB-002

Inventory must be transaction driven.

Inventory balances are derived.

Never manually edit stock balances.

---

## DB-003

Every business transaction must be traceable.

Examples:

* Material Issue
* Material Return
* Purchase Order
* MRN
* Consumption Entry

---

## DB-004

No hard deletes.

Use:

deleted_at

for all removable entities.

---

## DB-005

All tables must contain:

```sql
id
created_at
updated_at
created_by
updated_by
deleted_at
is_active
```

---

## DB-006

All tables require:

* Primary Keys
* Foreign Keys
* Indexes
* Constraints

---

## DB-007

All critical tables require audit logging.

Critical tables:

* Projects
* BOQ
* Inventory
* Procurement
* Cost Tracking
* Approvals

---

## DB-008

Every table must support Row Level Security.

No exceptions.

---

# Security Principles

## SEC-001

Role Based Access Control is mandatory.

Roles:

* Admin
* Owner
* Project Engineer
* Store Department
* Purchase Department

---

## SEC-002

Users can only access data permitted by role.

---

## SEC-003

Project Engineers cannot modify inventory.

---

## SEC-004

Store users cannot approve procurement.

---

## SEC-005

Purchase users cannot manipulate stock.

---

## SEC-006

Approval permissions cannot be bypassed.

---

## SEC-007

Every authentication action must be logged.

---

# Inventory Constitution

## INV-001

Inventory can never become negative.

---

## INV-002

Every stock movement creates a transaction.

Transaction Types:

* Stock In
* Stock Out
* Material Issue
* Material Return
* Adjustment

---

## INV-003

Stock balances must be calculated.

Never edited directly.

---

## INV-004

Inventory adjustments require approval.

---

## INV-005

All inventory actions must be auditable.

---

# BOQ Constitution

## BOQ-001

Every project must have a BOQ.

---

## BOQ-002

Material Requests cannot exceed BOQ.

Unless approved.

---

## BOQ-003

BOQ revisions require approval.

---

## BOQ-004

Variance tracking is mandatory.

Track:

* Planned
* Requested
* Issued
* Consumed
* Returned
* Wasted

---

# Procurement Constitution

## PROC-001

Shortages should be consolidated.

Never generate duplicate PRs.

---

## PROC-002

Purchase Orders must originate from approved PRs.

---

## PROC-003

PO quantity cannot exceed approved PR quantity.

---

## PROC-004

MRN quantity cannot exceed PO quantity.

---

## PROC-005

Procurement actions must be fully traceable.

---

# Cost Control Constitution

## COST-001

Every cost must be linked to:

* Project
* Zone
* Cost Category

---

## COST-002

Budget vs Actual must always be available.

---

## COST-003

Cost calculations must be automatic.

Manual overrides require approval.

---

## COST-004

Project profitability must be measurable.

---

# Approval Constitution

## APP-001

Approval workflows are mandatory.

---

## APP-002

High-value transactions require approval.

Examples:

* PR
* PO
* Budget Revision
* Project Closure

---

## APP-003

Approval history must never be deleted.

---

## APP-004

Approval logs must be immutable.

---

# UI Constitution

## UI-001

Mobile First.

The application will primarily be used on-site.

---

## UI-002

Desktop support is required.

---

## UI-003

All screens must support:

* Loading State
* Empty State
* Error State

---

## UI-004

Every data table must support:

* Search
* Filter
* Sort
* Export

---

## UI-005

Use reusable widgets.

Avoid duplicated UI code.

---

## UI-006

Premium enterprise appearance is mandatory.

Inspired by:

* Linear
* Stripe
* Notion
* Monday.com

---

# Reporting Constitution

## REP-001

Reports must use real-time data.

---

## REP-002

Reports must be exportable.

Formats:

* PDF
* Excel

---

## REP-003

Reports must support filtering.

---

# Audit Constitution

## AUD-001

Every critical action must be logged.

Examples:

* Create
* Update
* Approve
* Reject
* Issue
* Receive

---

## AUD-002

Audit logs are immutable.

---

## AUD-003

Audit logs must include:

* User
* Timestamp
* Action
* Entity
* Before Value
* After Value

---

# AI Feature Constitution

Future Features:

* Material Demand Forecasting
* Supplier Recommendation
* Procurement Forecasting
* BOQ Overrun Prediction
* Cost Overrun Prediction
* Delay Prediction

AI modules must never directly modify operational data.

AI can:

* Recommend
* Predict
* Alert

AI cannot:

* Approve
* Modify
* Delete

Without human approval.

---

# Development Rules

## DEV-001

Generate database schema first.

---

## DEV-002

Generate RLS policies before UI.

---

## DEV-003

Generate repositories before screens.

---

## DEV-004

Generate tests for every module.

---

## DEV-005

Generate documentation continuously.

---

## DEV-006

Never skip architecture layers.

---

## DEV-007

Every feature must include:

* Migration
* Models
* Repository
* Service
* Provider
* UI
* Tests
* Documentation

---

# Definition Of Success

The ERP is successful when:

* Inventory leakage is reduced.
* Procurement visibility is improved.
* Project costs are measurable in real time.
* BOQ variance is visible instantly.
* Management can make decisions from dashboards without requesting spreadsheets.
* Every material movement is traceable.
* Every approval is auditable.
* Every project has measurable profitability.

This constitution is the highest authority within the ERP project and must be followed by all generated code, database structures, workflows, and future enhancements.
