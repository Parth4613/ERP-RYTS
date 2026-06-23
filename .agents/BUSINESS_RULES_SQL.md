Business Rules — SQL Enforcement Reference

> Every BR maps to SQL. Agents copy-paste these triggers into migrations.
> BR = Business Rule from docs/business-rules.md

---

## Inventory Rules

### BR-001 — Inventory Never Negative
```sql
-- On stock_balances: hard constraint
ALTER TABLE public.stock_balances
  ADD CONSTRAINT chk_quantity_non_negative CHECK (quantity >= 0);

ALTER TABLE public.stock_balances
  ADD CONSTRAINT chk_reserved_non_negative CHECK (reserved_qty >= 0);
```

### BR-002 + BR-003 — Transactions Drive Balances (Core Trigger)
```sql
-- Every insert into stock_transactions updates stock_balances
-- This is the ONLY way stock_balances is modified

CREATE OR REPLACE FUNCTION public.apply_stock_transaction()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  -- Upsert stock balance
  INSERT INTO public.stock_balances (material_id, warehouse_id, quantity, reserved_qty)
  VALUES (NEW.material_id, NEW.warehouse_id, NEW.quantity, 0)
  ON CONFLICT (material_id, warehouse_id)
  DO UPDATE SET
    quantity = stock_balances.quantity + NEW.quantity,
    updated_at = NOW();

  -- Verify non-negative (BR-001)
  IF (SELECT quantity FROM public.stock_balances
      WHERE material_id = NEW.material_id
        AND warehouse_id = NEW.warehouse_id) < 0 THEN
    RAISE EXCEPTION 'Stock cannot go negative: material_id=%, warehouse_id=%',
      NEW.material_id, NEW.warehouse_id
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER stock_transactions_apply
  AFTER INSERT ON public.stock_transactions
  FOR EACH ROW EXECUTE FUNCTION public.apply_stock_transaction();
```

### BR-004 — Adjustments Require Approval
```sql
-- inventory_adjustments can only apply to stock when status = 'approved'
CREATE OR REPLACE FUNCTION public.apply_approved_adjustment()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'approved' AND OLD.status != 'approved' THEN
    INSERT INTO public.stock_transactions (
      material_id, warehouse_id, transaction_type, quantity,
      reference_type, reference_id, created_by
    ) VALUES (
      NEW.material_id, NEW.warehouse_id, 'adjustment',
      NEW.adjustment_qty, 'adjustment', NEW.id, auth.uid()
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER inventory_adjustment_apply
  AFTER UPDATE ON public.inventory_adjustments
  FOR EACH ROW EXECUTE FUNCTION public.apply_approved_adjustment();
```

### BR-005 — Reserved Stock Cannot Be Re-Issued
```sql
-- Check available_qty (quantity - reserved_qty) before issuing
-- Enforced in IssuanceRepository before creating issue_slip_items

-- Available qty check function (call from repository/trigger)
CREATE OR REPLACE FUNCTION public.get_available_qty(
  p_material_id BIGINT,
  p_warehouse_id BIGINT
) RETURNS NUMERIC LANGUAGE SQL STABLE AS $$
  SELECT COALESCE(quantity - reserved_qty, 0)
  FROM public.stock_balances
  WHERE material_id = p_material_id
    AND warehouse_id = p_warehouse_id;
$$;
```

---

## Document Number Auto-Generation

### AD-019 — All Business Document Numbers
```sql
-- Generic sequence-based number generator
CREATE OR REPLACE FUNCTION public.generate_document_number(
  p_prefix TEXT,
  p_sequence_name TEXT
) RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
  v_year TEXT := TO_CHAR(NOW(), 'YYYY');
  v_seq  BIGINT;
BEGIN
  EXECUTE FORMAT('SELECT nextval(%L)', p_sequence_name) INTO v_seq;
  RETURN p_prefix || '-' || v_year || '-' || LPAD(v_seq::TEXT, 4, '0');
END;
$$;

-- Create sequences (one per document type)
CREATE SEQUENCE IF NOT EXISTS seq_project_number START 1;
CREATE SEQUENCE IF NOT EXISTS seq_mr_number     START 1;
CREATE SEQUENCE IF NOT EXISTS seq_is_number     START 1;
CREATE SEQUENCE IF NOT EXISTS seq_pr_number     START 1;
CREATE SEQUENCE IF NOT EXISTS seq_po_number     START 1;
CREATE SEQUENCE IF NOT EXISTS seq_mrn_number    START 1;
CREATE SEQUENCE IF NOT EXISTS seq_sup_number    START 1;

-- Note: Sequences reset yearly requires a different approach (trigger + table-based counter)
-- For simplicity, use global sequences that never reset.
-- Adjust prefix to include year: PP-2024-0001

-- Project code trigger
CREATE OR REPLACE FUNCTION public.set_project_code()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.project_code IS NULL THEN
    NEW.project_code := generate_document_number('PP', 'seq_project_number');
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER projects_set_code
  BEFORE INSERT ON public.projects
  FOR EACH ROW EXECUTE FUNCTION public.set_project_code();

-- Repeat pattern for: material_requests, issue_slips, purchase_requisitions,
-- purchase_orders, mrn_headers, suppliers
```

---

## BOQ Rules

### BR-007 — MR Cannot Exceed BOQ Quantity
```sql
CREATE OR REPLACE FUNCTION public.check_mr_qty_vs_boq()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_planned_qty     NUMERIC;
  v_total_requested NUMERIC;
  v_mr_status       TEXT;
BEGIN
  -- Only check on submit (status change to 'submitted')
  SELECT status INTO v_mr_status FROM public.material_requests WHERE id = NEW.mr_id;
  IF v_mr_status != 'submitted' THEN RETURN NEW; END IF;

  IF NEW.boq_item_id IS NULL THEN RETURN NEW; END IF;

  SELECT planned_qty INTO v_planned_qty
  FROM public.boq_items WHERE id = NEW.boq_item_id;

  SELECT COALESCE(SUM(mri.requested_qty), 0) INTO v_total_requested
  FROM public.material_request_items mri
  JOIN public.material_requests mr ON mr.id = mri.mr_id
  WHERE mri.boq_item_id = NEW.boq_item_id
    AND mr.status NOT IN ('rejected','closed')
    AND mri.id != COALESCE(NEW.id, -1)
    AND mri.deleted_at IS NULL;

  IF (v_total_requested + NEW.requested_qty) > v_planned_qty THEN
    RAISE EXCEPTION 'MR quantity (%) would exceed BOQ planned quantity (%) for material. Get approval first.',
      v_total_requested + NEW.requested_qty, v_planned_qty
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER mr_items_check_boq_qty
  BEFORE INSERT OR UPDATE ON public.material_request_items
  FOR EACH ROW EXECUTE FUNCTION public.check_mr_qty_vs_boq();
```

---

## Material Request Rules

### BR-012 + BR-013 — MR Status Flow + Closed Cannot Edit
```sql
CREATE OR REPLACE FUNCTION public.enforce_mr_status_flow()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- BR-013: Closed MR cannot be edited at all
  IF OLD.status = 'closed' THEN
    RAISE EXCEPTION 'Cannot modify a closed Material Request (BR-013)'
      USING ERRCODE = 'P0001';
  END IF;

  -- BR-012: Valid status transitions only
  IF NOT (
    (OLD.status = 'draft'             AND NEW.status IN ('submitted', 'draft')) OR
    (OLD.status = 'submitted'         AND NEW.status IN ('approved', 'rejected', 'submitted')) OR
    (OLD.status = 'approved'          AND NEW.status IN ('partially_issued', 'fully_issued')) OR
    (OLD.status = 'partially_issued'  AND NEW.status IN ('fully_issued', 'closed')) OR
    (OLD.status = 'fully_issued'      AND NEW.status = 'closed') OR
    (OLD.status = 'rejected'          AND NEW.status = 'draft')  -- allow re-draft
  ) THEN
    RAISE EXCEPTION 'Invalid MR status transition: % → %', OLD.status, NEW.status
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER mr_status_flow
  BEFORE UPDATE ON public.material_requests
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.enforce_mr_status_flow();
```

### MR Approval → Reserve Stock
```sql
CREATE OR REPLACE FUNCTION public.reserve_stock_on_mr_approval()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- When MR approved: reserve stock for each item
  IF NEW.status = 'approved' AND OLD.status = 'submitted' THEN
    UPDATE public.stock_balances sb
    SET reserved_qty = reserved_qty + mri.approved_qty
    FROM public.material_request_items mri
    WHERE mri.mr_id = NEW.id
      AND sb.material_id = mri.material_id
      AND mri.deleted_at IS NULL;
  END IF;

  -- When MR rejected: release any reservations
  IF NEW.status = 'rejected' AND OLD.status = 'submitted' THEN
    UPDATE public.stock_balances sb
    SET reserved_qty = GREATEST(0, reserved_qty - mri.approved_qty)
    FROM public.material_request_items mri
    WHERE mri.mr_id = NEW.id
      AND sb.material_id = mri.material_id
      AND mri.deleted_at IS NULL;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER mr_approval_reserve_stock
  AFTER UPDATE ON public.material_requests
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.reserve_stock_on_mr_approval();
```

---

## Procurement Rules

### BR-016 — PO Quantity Cannot Exceed Approved PR Quantity
```sql
CREATE OR REPLACE FUNCTION public.enforce_po_qty_vs_pr()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_approved_qty   NUMERIC;
  v_already_po_qty NUMERIC;
BEGIN
  IF NEW.pr_item_id IS NULL THEN RETURN NEW; END IF;

  SELECT approved_qty INTO v_approved_qty
  FROM public.purchase_requisition_items WHERE id = NEW.pr_item_id;

  SELECT COALESCE(SUM(poi.ordered_qty), 0) INTO v_already_po_qty
  FROM public.purchase_order_items poi
  JOIN public.purchase_orders po ON po.id = poi.po_id
  WHERE poi.pr_item_id = NEW.pr_item_id
    AND po.status NOT IN ('cancelled')
    AND poi.id != COALESCE(NEW.id, -1)
    AND poi.deleted_at IS NULL;

  IF (v_already_po_qty + NEW.ordered_qty) > v_approved_qty THEN
    RAISE EXCEPTION 'PO quantity (%) exceeds approved PR quantity (%) for this item',
      v_already_po_qty + NEW.ordered_qty, v_approved_qty
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER po_items_check_pr_qty
  BEFORE INSERT OR UPDATE ON public.purchase_order_items
  FOR EACH ROW EXECUTE FUNCTION public.enforce_po_qty_vs_pr();
```

### BR-018 — MRN Quantity Cannot Exceed PO Quantity
```sql
CREATE OR REPLACE FUNCTION public.enforce_mrn_qty_vs_po()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_ordered_qty      NUMERIC;
  v_already_received NUMERIC;
BEGIN
  SELECT ordered_qty INTO v_ordered_qty
  FROM public.purchase_order_items WHERE id = NEW.po_item_id;

  SELECT COALESCE(SUM(mi.received_qty), 0) INTO v_already_received
  FROM public.mrn_items mi
  JOIN public.mrn_headers mh ON mh.id = mi.mrn_id
  WHERE mi.po_item_id = NEW.po_item_id
    AND mh.status != 'cancelled'
    AND mi.id != COALESCE(NEW.id, -1)
    AND mi.deleted_at IS NULL;

  IF (v_already_received + NEW.received_qty) > v_ordered_qty THEN
    RAISE EXCEPTION 'MRN received quantity (%) exceeds PO ordered quantity (%)',
      v_already_received + NEW.received_qty, v_ordered_qty
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER mrn_items_check_po_qty
  BEFORE INSERT OR UPDATE ON public.mrn_items
  FOR EACH ROW EXECUTE FUNCTION public.enforce_mrn_qty_vs_po();
```

### MRN Approval → Stock In
```sql
CREATE OR REPLACE FUNCTION public.stock_in_on_mrn_approval()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'approved' AND OLD.status = 'draft' THEN
    INSERT INTO public.stock_transactions (
      material_id, warehouse_id, transaction_type, quantity,
      reference_type, reference_id, created_by
    )
    SELECT
      mi.material_id,
      mi.warehouse_id,
      'stock_in',
      mi.accepted_qty,
      'mrn',
      NEW.id,
      auth.uid()
    FROM public.mrn_items mi
    WHERE mi.mrn_id = NEW.id
      AND mi.accepted_qty > 0
      AND mi.deleted_at IS NULL;

    -- Update PO received quantities
    UPDATE public.purchase_order_items poi
    SET received_qty = received_qty + mi.received_qty
    FROM public.mrn_items mi
    WHERE mi.mrn_id = NEW.id
      AND poi.id = mi.po_item_id;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER mrn_approval_stock_in
  AFTER UPDATE ON public.mrn_headers
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.stock_in_on_mrn_approval();
```

---

## Issue Slip Rules

### Issue Slip → Stock Out + MR Update
```sql
CREATE OR REPLACE FUNCTION public.stock_out_on_issuance()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'complete' AND OLD.status = 'draft' THEN
    -- Create stock_out transactions
    INSERT INTO public.stock_transactions (
      material_id, warehouse_id, transaction_type, quantity,
      reference_type, reference_id, project_id, created_by
    )
    SELECT
      isi.material_id,
      isi.warehouse_id,
      'stock_out',
      -isi.issued_qty,  -- negative = stock leaving
      'issue_slip',
      NEW.id,
      NEW.project_id,
      auth.uid()
    FROM public.issue_slip_items isi
    WHERE isi.slip_id = NEW.id AND isi.deleted_at IS NULL;

    -- Release reservations + update MR item issued qty
    UPDATE public.material_request_items mri
    SET issued_qty = issued_qty + isi.issued_qty
    FROM public.issue_slip_items isi
    WHERE isi.slip_id = NEW.id
      AND mri.id = isi.mr_item_id;

    -- Release reserved stock
    UPDATE public.stock_balances sb
    SET reserved_qty = GREATEST(0, reserved_qty - isi.issued_qty)
    FROM public.issue_slip_items isi
    WHERE isi.slip_id = NEW.id
      AND sb.material_id = isi.material_id;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER issue_slip_complete_stock_out
  AFTER UPDATE ON public.issue_slips
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.stock_out_on_issuance();
```

---

## Consumption Rules

### BR-021 — Consumed Qty Cannot Exceed Issued Qty
```sql
CREATE OR REPLACE FUNCTION public.enforce_consumption_vs_issued()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_issued_qty    NUMERIC;
  v_already_used  NUMERIC;
BEGIN
  -- Get issued qty for this issue_slip_item
  SELECT issued_qty INTO v_issued_qty
  FROM public.issue_slip_items WHERE id = NEW.issue_slip_item_id;

  -- Total already consumed + returned + wasted for this item
  SELECT
    COALESCE(SUM(ce.consumed_qty), 0) +
    COALESCE(SUM(re.returned_qty), 0) +
    COALESCE(SUM(we.wastage_qty), 0)
  INTO v_already_used
  FROM public.issue_slip_items isi
  LEFT JOIN public.consumption_entries ce ON ce.issue_slip_item_id = isi.id AND ce.deleted_at IS NULL
  LEFT JOIN public.return_entries re ON re.issue_slip_item_id = isi.id AND re.deleted_at IS NULL
  LEFT JOIN public.wastage_entries we ON we.issue_slip_item_id = isi.id AND we.deleted_at IS NULL
  WHERE isi.id = NEW.issue_slip_item_id;

  IF (v_already_used + NEW.consumed_qty) > v_issued_qty THEN
    RAISE EXCEPTION 'Total consumed/returned/wasted (%) cannot exceed issued quantity (%)',
      v_already_used + NEW.consumed_qty, v_issued_qty
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER consumption_check_issued_qty
  BEFORE INSERT OR UPDATE ON public.consumption_entries
  FOR EACH ROW EXECUTE FUNCTION public.enforce_consumption_vs_issued();
```

### BR-022 — Return Updates Inventory
```sql
CREATE OR REPLACE FUNCTION public.stock_in_on_return()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Returns go back into inventory
  INSERT INTO public.stock_transactions (
    material_id, warehouse_id, transaction_type, quantity,
    reference_type, reference_id, project_id, created_by
  ) VALUES (
    NEW.material_id, NEW.warehouse_id, 'return_in',
    NEW.returned_qty, 'return', NEW.id, NEW.project_id, auth.uid()
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER return_entry_stock_in
  AFTER INSERT ON public.return_entries
  FOR EACH ROW EXECUTE FUNCTION public.stock_in_on_return();
```

---

## Audit Rules

### BR-030 — All Actions Logged (Critical Tables)
```sql
-- Attach to each critical table:
-- projects, boq_headers, stock_transactions, material_requests,
-- purchase_orders, mrn_headers, approval_logs, issue_slips

CREATE TRIGGER <table>_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.<table>
  FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();
```

---

## Approval High-Value Check

### BR-025 / BR-026 — High Value Requires Owner Approval
```sql
-- Configurable threshold from app_settings
CREATE OR REPLACE FUNCTION public.check_approval_required(
  p_entity_type TEXT,
  p_amount NUMERIC
) RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT p_amount > COALESCE(
    (SELECT value::NUMERIC FROM public.app_settings
     WHERE key = 'approval_threshold_' || p_entity_type),
    500000  -- default ₹500,000
  );
$$;