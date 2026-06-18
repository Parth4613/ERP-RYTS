# Database Schema

## Core Tables

users
roles
permissions
user_roles

projects
project_zones

clients

---

## BOQ

boq_headers
boq_items

---

## Inventory

materials

material_categories

warehouses

stock_transactions

stock_balances

inventory_adjustments

---

## Material Requests

material_requests

material_request_items

---

## Procurement

purchase_requisitions

purchase_requisition_items

purchase_orders

purchase_order_items

---

## Suppliers

suppliers

supplier_contacts

supplier_products

supplier_ratings

---

## Receiving

mrn_headers

mrn_items

---

## Site Operations

consumption_entries

return_entries

wastage_entries

daily_progress_reports

---

## Costing

cost_categories

project_costs

cost_allocations

---

## Documents

documents

document_categories

---

## Approval

approval_workflows

approval_steps

approval_logs

---

## Audit

audit_logs

activity_logs

---

## Notifications

notifications

notification_logs

---

## Future Modules

vehicles

vehicle_logs

equipment

equipment_usage

diesel_logs

forecasts
ai_predictions

All tables must include:

id
created_at
updated_at
created_by
updated_by
deleted_at
is_active
