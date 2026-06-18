# Permission Matrix

## Roles

1. Admin
2. Owner
3. Project Engineer
4. Store Department
5. Purchase Department

---

# Projects

| Action  | Admin | Owner | Engineer | Store | Purchase |
| ------- | ----- | ----- | -------- | ----- | -------- |
| View    | Yes   | Yes   | Assigned | Yes   | Yes      |
| Create  | Yes   | No    | No       | No    | No       |
| Edit    | Yes   | No    | Limited  | No    | No       |
| Archive | Yes   | No    | No       | No    | No       |

---

# BOQ

| Action  | Admin | Owner | Engineer | Store | Purchase |
| ------- | ----- | ----- | -------- | ----- | -------- |
| View    | Yes   | Yes   | Yes      | Yes   | Yes      |
| Create  | Yes   | No    | No       | No    | No       |
| Edit    | Yes   | No    | No       | No    | No       |
| Approve | Yes   | Yes   | No       | No    | No       |

---

# Material Request

| Action     | Admin | Owner | Engineer | Store | Purchase |
| ---------- | ----- | ----- | -------- | ----- | -------- |
| Create     | Yes   | No    | Yes      | No    | No       |
| Edit Draft | Yes   | No    | Yes      | No    | No       |
| Submit     | Yes   | No    | Yes      | No    | No       |
| Approve    | Yes   | Yes   | No       | No    | No       |

---

# Inventory

| Action    | Admin | Owner | Engineer  | Store | Purchase  |
| --------- | ----- | ----- | --------- | ----- | --------- |
| View      | Yes   | Yes   | Read Only | Yes   | Read Only |
| Stock In  | Yes   | No    | No        | Yes   | No        |
| Stock Out | Yes   | No    | No        | Yes   | No        |
| Adjust    | Yes   | No    | No        | Yes   | No        |

---

# Procurement

| Action     | Admin | Owner | Engineer | Store | Purchase |
| ---------- | ----- | ----- | -------- | ----- | -------- |
| Create PR  | Yes   | No    | No       | Yes   | Yes      |
| Approve PR | Yes   | Yes   | No       | No    | No       |
| Create PO  | Yes   | No    | No       | No    | Yes      |
| Approve PO | Yes   | Yes   | No       | No    | No       |

---

# MRN

| Action  | Admin | Owner | Engineer | Store | Purchase |
| ------- | ----- | ----- | -------- | ----- | -------- |
| Create  | Yes   | No    | No       | Yes   | Yes      |
| Approve | Yes   | Yes   | No       | No    | No       |

---

# Cost Tracking

| Action | Admin | Owner | Engineer | Store | Purchase |
| ------ | ----- | ----- | -------- | ----- | -------- |
| View   | Yes   | Yes   | Assigned | No    | No       |
| Edit   | Yes   | No    | No       | No    | No       |

---

# Reports

| Action | Admin | Owner | Engineer | Store   | Purchase |
| ------ | ----- | ----- | -------- | ------- | -------- |
| View   | Yes   | Yes   | Limited  | Limited | Limited  |
| Export | Yes   | Yes   | No       | No      | No       |

---

# Documents

| Action | Admin | Owner | Engineer | Store | Purchase |
| ------ | ----- | ----- | -------- | ----- | -------- |
| Upload | Yes   | No    | Yes      | Yes   | Yes      |
| Delete | Yes   | No    | No       | No    | No       |

---

# System Administration

Only Admin

Users

Roles

Permissions

Audit Logs

Settings

Approval Matrix
