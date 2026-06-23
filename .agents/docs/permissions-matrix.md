# Permission Matrix
## Gas Pipeline ERP — Role × Module × Action

> This is the authoritative RBAC matrix. RLS policies in `.agents/RLS_PATTERNS.md`
> are derived from this table. If they conflict, this document wins.

**Roles:** Admin (A) · Owner (O) · Engineer (E) · Store (S) · Purchase (P)
**Legend:** ✅ Full · 👁 Read Only · 📝 Limited · ❌ No Access

---

## Projects & Zones

| Action | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| View all projects | ✅ | ✅ | 👁 Assigned only | 👁 All active | 👁 All active |
| Create project | ✅ | ❌ | ❌ | ❌ | ❌ |
| Edit project details | ✅ | ❌ | 📝 Description only | ❌ | ❌ |
| Change project status | ✅ | ❌ | ❌ | ❌ | ❌ |
| Archive/Close project | ✅ | ❌ | ❌ | ❌ | ❌ |
| Assign engineer | ✅ | ❌ | ❌ | ❌ | ❌ |
| Manage zones | ✅ | ❌ | 📝 Own projects | ❌ | ❌ |

---

## BOQ

| Action | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| View BOQ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Create BOQ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Edit BOQ (draft) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Submit BOQ for approval | ✅ | ❌ | ❌ | ❌ | ❌ |
| Approve BOQ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Upload BOQ file | ✅ | ❌ | ❌ | ❌ | ❌ |
| View BOQ variance | ✅ | ✅ | ✅ | 👁 | 👁 |

---

## Material Requests

| Action | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| Create MR | ✅ | ❌ | ✅ Own projects | ❌ | ❌ |
| Edit draft MR | ✅ | ❌ | ✅ Own MRs | ❌ | ❌ |
| Submit MR | ✅ | ❌ | ✅ Own MRs | ❌ | ❌ |
| View all MRs | ✅ | ✅ | 👁 Own projects | ✅ | 👁 |
| Approve/Reject MR | ✅ | ✅ | ❌ | ❌ | ❌ |
| View MR status | ✅ | ✅ | ✅ | ✅ | 👁 |

---

## Inventory

| Action | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| View stock levels | ✅ | ✅ | 👁 | ✅ | 👁 |
| View stock transactions | ✅ | ✅ | ❌ | ✅ | 👁 |
| Record stock in (manual) | ✅ | ❌ | ❌ | ✅ | ❌ |
| Record stock out (manual) | ✅ | ❌ | ❌ | ✅ | ❌ |
| Request adjustment | ✅ | ❌ | ❌ | ✅ | ❌ |
| Approve adjustment | ✅ | ❌ | ❌ | ❌ | ❌ |
| View low-stock alerts | ✅ | ✅ | ❌ | ✅ | ✅ |
| Manage material master | ✅ | ❌ | ❌ | ✅ | ❌ |
| Manage warehouses | ✅ | ❌ | ❌ | ✅ | ❌ |

---

## Store Issuance

| Action | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| View pending issuances | ✅ | 👁 | ❌ | ✅ | ❌ |
| Create issue slip | ✅ | ❌ | ❌ | ✅ | ❌ |
| Issue full quantity | ✅ | ❌ | ❌ | ✅ | ❌ |
| Issue partial quantity | ✅ | ❌ | ❌ | ✅ | ❌ |
| Generate issue slip PDF | ✅ | ❌ | ❌ | ✅ | ❌ |
| View issue history | ✅ | ✅ | 👁 Own projects | ✅ | ❌ |

---

## Procurement (PR)

| Action | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| Create PR | ✅ | ❌ | ❌ | ✅ | ✅ |
| Edit draft PR | ✅ | ❌ | ❌ | ✅ | ✅ |
| Submit PR | ✅ | ❌ | ❌ | ✅ | ✅ |
| View all PRs | ✅ | ✅ | ❌ | ✅ | ✅ |
| Approve PR | ✅ | ✅ | ❌ | ❌ | ❌ |
| Convert PR to PO | ✅ | ❌ | ❌ | ❌ | ✅ |

---

## Purchase Orders

| Action | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| Create PO | ✅ | ❌ | ❌ | ❌ | ✅ |
| Edit draft PO | ✅ | ❌ | ❌ | ❌ | ✅ |
| Approve PO | ✅ | ✅ | ❌ | ❌ | ❌ |
| View all POs | ✅ | ✅ | ❌ | ✅ | ✅ |
| Track delivery | ✅ | 👁 | ❌ | ✅ | ✅ |
| Mark as received | ✅ | ❌ | ❌ | ✅ | ✅ |

---

## Suppliers

| Action | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| View suppliers | ✅ | ✅ | ❌ | 👁 | ✅ |
| Create supplier | ✅ | ❌ | ❌ | ❌ | ✅ |
| Edit supplier | ✅ | ❌ | ❌ | ❌ | ✅ |
| Rate supplier | ✅ | ❌ | ❌ | ✅ | ✅ |
| View supplier catalog | ✅ | 👁 | ❌ | 👁 | ✅ |
| Manage product rates | ✅ | ❌ | ❌ | ❌ | ✅ |

---

## MRN (Material Receipt)

| Action | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| Create MRN | ✅ | ❌ | ❌ | ✅ | ✅ |
| Edit draft MRN | ✅ | ❌ | ❌ | ✅ | ✅ |
| Approve MRN | ✅ | ✅ | ❌ | ✅ | ❌ |
| View MRN history | ✅ | ✅ | ❌ | ✅ | ✅ |
| Record rejections | ✅ | ❌ | ❌ | ✅ | ✅ |

---

## Site Consumption

| Action | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| Record consumption | ✅ | ❌ | ✅ Own projects | ❌ | ❌ |
| Record returns | ✅ | ❌ | ✅ Own projects | ✅ | ❌ |
| Record wastage | ✅ | ❌ | ✅ Own projects | ❌ | ❌ |
| View consumption report | ✅ | ✅ | 👁 Own projects | 👁 | ❌ |
| View wastage report | ✅ | ✅ | 👁 Own projects | ❌ | ❌ |
| Submit daily progress | ✅ | ❌ | ✅ Own projects | ❌ | ❌ |

---

## Cost Tracking

| Action | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| View project costs | ✅ | ✅ | 👁 Own projects | ❌ | ❌ |
| Add manual cost | ✅ | ❌ | ❌ | ❌ | ❌ |
| View budget vs actual | ✅ | ✅ | 👁 Own projects | ❌ | ❌ |
| View cost breakdown | ✅ | ✅ | ❌ | ❌ | ❌ |

---

## Documents

| Action | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| View documents | ✅ | ✅ | ✅ Own projects | ✅ | ✅ |
| Upload document | ✅ | ❌ | ✅ | ✅ | ✅ |
| Delete document | ✅ | ❌ | ❌ | ❌ | ❌ |
| Share document | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## Reports

| Action | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| Inventory Report | ✅ | ✅ | ❌ | ✅ | 👁 |
| Project Cost Report | ✅ | ✅ | 👁 Own | ❌ | ❌ |
| Supplier Report | ✅ | ✅ | ❌ | 👁 | ✅ |
| Consumption Report | ✅ | ✅ | 👁 Own | 👁 | ❌ |
| BOQ Variance Report | ✅ | ✅ | 👁 Own | 👁 | ❌ |
| Wastage Report | ✅ | ✅ | 👁 Own | ❌ | ❌ |
| Procurement Report | ✅ | ✅ | ❌ | ✅ | ✅ |
| Export PDF | ✅ | ✅ | ❌ | 📝 Own | ❌ |
| Export Excel | ✅ | ✅ | ❌ | ❌ | ❌ |

---

## Executive Dashboard

| Widget | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| All KPIs | ✅ | ✅ | ❌ | ❌ | ❌ |
| Project health | ✅ | ✅ | 👁 Own | ❌ | ❌ |
| Inventory value | ✅ | ✅ | ❌ | ✅ | ❌ |
| Pending approvals | ✅ | ✅ | ❌ | ❌ | ❌ |
| Financial overview | ✅ | ✅ | ❌ | ❌ | ❌ |
| Alerts | ✅ | ✅ | 📝 Own projects | 📝 Inventory | 📝 PO delays |

---

## System Administration

| Action | Admin | Owner | Engineer | Store | Purchase |
|--------|-------|-------|----------|-------|---------|
| Manage users | ✅ | ❌ | ❌ | ❌ | ❌ |
| Assign roles | ✅ | ❌ | ❌ | ❌ | ❌ |
| View audit logs | ✅ | ❌ | ❌ | ❌ | ❌ |
| Configure settings | ✅ | ❌ | ❌ | ❌ | ❌ |
| Manage approval matrix | ✅ | ❌ | ❌ | ❌ | ❌ |