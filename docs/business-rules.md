# Business Rules

## Inventory Rules

### BR-001

Inventory can never become negative.

### BR-002

Every inventory movement must create a stock transaction.

### BR-003

Stock balances are calculated from transactions.

### BR-004

Inventory adjustments require approval.

### BR-005

Reserved stock cannot be issued to another project.

---

## BOQ Rules

### BR-006

Every project must have an approved BOQ.

### BR-007

Material Requests cannot exceed BOQ quantity without approval.

### BR-008

BOQ revisions require management approval.

### BR-009

BOQ variance must be calculated automatically.

---

## Material Request Rules

### BR-010

MR must belong to a project.

### BR-011

MR must belong to a project zone.

### BR-012

MR status flow:

Draft → Submitted → Approved → Issued → Closed

### BR-013

Closed MR cannot be edited.

---

## Procurement Rules

### BR-014

Shortages should be consolidated into a single PR.

### BR-015

Purchase Orders can only be generated from approved PRs.

### BR-016

PO quantity cannot exceed approved PR quantity.

### BR-017

PO revisions require approval.

---

## Material Receipt Rules

### BR-018

MRN cannot exceed PO quantity.

### BR-019

Rejected quantity must be recorded separately.

### BR-020

Inventory updates only after MRN approval.

---

## Consumption Rules

### BR-021

Consumed quantity cannot exceed issued quantity.

### BR-022

Returned quantity must update inventory.

### BR-023

Wastage quantity must be tracked separately.

### BR-024

Wastage percentage must be calculated automatically.

---

## Approval Rules

### BR-025

High-value PR requires Owner approval.

### BR-026

High-value PO requires Owner approval.

### BR-027

Project closure requires approval.

### BR-028

Budget revisions require approval.

---

## Audit Rules

### BR-029

No hard delete allowed.

### BR-030

All actions must be logged.

### BR-031

Every approval action must be auditable.

### BR-032

Every inventory action must be traceable.

---

## Security Rules

### BR-033

All access is role-based.

### BR-034

Project Engineers cannot modify inventory.

### BR-035

Store users cannot approve POs.

### BR-036

Purchase users cannot alter issued stock.

### BR-037

Admins have full access.
