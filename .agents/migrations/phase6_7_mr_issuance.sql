-- ============================================================
-- PHASE 6 — Material Request System (Module 3)
-- PHASE 7 — Store Issuance + Issue Slip PDF (Module 5)
-- Tables: material_requests, material_request_items,
--         issue_slips, issue_slip_items
-- Run via: supabase migration new phase6_7_mr_issuance
-- ============================================================

-- ============================================================
-- MATERIAL REQUESTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.material_requests (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  mr_number      TEXT UNIQUE,    -- auto: MR-YYYY-NNNN
  project_id     BIGINT NOT NULL REFERENCES public.projects(id),
  zone_id        BIGINT REFERENCES public.project_zones(id),
  requested_by   UUID NOT NULL REFERENCES auth.users(id),
  required_date  DATE NOT NULL,
  priority       TEXT NOT NULL DEFAULT 'medium'
                 CHECK (priority IN ('low','medium','high','urgent')),
  status         TEXT NOT NULL DEFAULT 'draft'
                 CHECK (status IN
                   ('draft','submitted','approved','rejected',
                    'partially_issued','fully_issued','closed')),
  approved_by    UUID REFERENCES auth.users(id),
  approved_at    TIMESTAMPTZ,
  rejection_reason TEXT,
  remarks        TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by     UUID REFERENCES auth.users(id),
  updated_by     UUID REFERENCES auth.users(id),
  deleted_at     TIMESTAMPTZ,
  is_active      BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX mr_project_id_idx     ON public.material_requests(project_id);
CREATE INDEX mr_zone_id_idx        ON public.material_requests(zone_id);
CREATE INDEX mr_requested_by_idx   ON public.material_requests(requested_by);
CREATE INDEX mr_status_idx         ON public.material_requests(status)
  WHERE deleted_at IS NULL;
-- Composite: store dashboard filter
CREATE INDEX mr_project_status_idx ON public.material_requests(project_id, status)
  WHERE deleted_at IS NULL;

CREATE TRIGGER mr_updated_at
  BEFORE UPDATE ON public.material_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER mr_audit
  AFTER INSERT OR UPDATE ON public.material_requests
  FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();

-- Auto MR number
CREATE OR REPLACE FUNCTION public.set_mr_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.mr_number IS NULL THEN
    NEW.mr_number := public.generate_doc_number('MR', 'seq_mr_number');
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER mr_set_number
  BEFORE INSERT ON public.material_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_mr_number();

-- Status flow enforcement (BR-012, BR-013)
CREATE OR REPLACE FUNCTION public.enforce_mr_status_flow()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status = 'closed' THEN
    RAISE EXCEPTION 'Cannot modify a closed Material Request (BR-013)'
      USING ERRCODE = 'P0001';
  END IF;
  IF NOT (
    (OLD.status = 'draft'            AND NEW.status IN ('submitted','draft')) OR
    (OLD.status = 'submitted'        AND NEW.status IN ('approved','rejected','submitted')) OR
    (OLD.status = 'approved'         AND NEW.status IN ('partially_issued','fully_issued')) OR
    (OLD.status = 'partially_issued' AND NEW.status IN ('fully_issued','closed')) OR
    (OLD.status = 'fully_issued'     AND NEW.status = 'closed') OR
    (OLD.status = 'rejected'         AND NEW.status = 'draft')
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

-- Reserve stock on approval; release on rejection (AD-023)
CREATE OR REPLACE FUNCTION public.manage_stock_reservation_on_mr()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.status = 'approved' AND OLD.status = 'submitted' THEN
    -- Find warehouse for each item (use central warehouse or project warehouse)
    UPDATE public.stock_balances sb
    SET reserved_qty = reserved_qty + mri.approved_qty
    FROM public.material_request_items mri
    JOIN public.warehouses w ON w.is_central = TRUE
    WHERE mri.mr_id = NEW.id
      AND sb.material_id = mri.material_id
      AND sb.warehouse_id = w.id
      AND mri.deleted_at IS NULL;
  END IF;

  IF NEW.status = 'rejected' AND OLD.status = 'submitted' THEN
    UPDATE public.stock_balances sb
    SET reserved_qty = GREATEST(0, reserved_qty - mri.requested_qty)
    FROM public.material_request_items mri
    JOIN public.warehouses w ON w.is_central = TRUE
    WHERE mri.mr_id = NEW.id
      AND sb.material_id = mri.material_id
      AND sb.warehouse_id = w.id
      AND mri.deleted_at IS NULL;
  END IF;

  -- Notify engineer on status change
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.notifications (user_id, type, title, message, entity_type, entity_id)
    VALUES (
      NEW.requested_by, 'mr_' || NEW.status,
      'MR ' || NEW.mr_number || ' ' || INITCAP(NEW.status),
      'Your material request has been ' || NEW.status || '.',
      'mr', NEW.id
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER mr_manage_reservation
  AFTER UPDATE ON public.material_requests
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.manage_stock_reservation_on_mr();

ALTER TABLE public.material_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.material_requests FORCE ROW LEVEL SECURITY;

CREATE POLICY "mr_admin_all" ON public.material_requests
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');

CREATE POLICY "mr_owner_read" ON public.material_requests
  FOR SELECT TO authenticated
  USING ((SELECT public.current_user_role()) = 'owner' AND deleted_at IS NULL);

CREATE POLICY "mr_owner_approve" ON public.material_requests
  FOR UPDATE TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','owner'));

CREATE POLICY "mr_engineer_own" ON public.material_requests
  FOR ALL TO authenticated
  USING (
    (SELECT public.current_user_role()) = 'engineer'
    AND requested_by = (SELECT auth.uid())
  )
  WITH CHECK (
    (SELECT public.current_user_role()) = 'engineer'
    AND status IN ('draft','submitted')
  );

CREATE POLICY "mr_store_read" ON public.material_requests
  FOR SELECT TO authenticated
  USING (
    (SELECT public.current_user_role()) IN ('store','purchase')
    AND deleted_at IS NULL
  );

CREATE POLICY "mr_store_update_issued" ON public.material_requests
  FOR UPDATE TO authenticated
  USING ((SELECT public.current_user_role()) = 'store');

-- ============================================================
-- MATERIAL REQUEST ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.material_request_items (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  mr_id           BIGINT NOT NULL REFERENCES public.material_requests(id),
  material_id     BIGINT NOT NULL REFERENCES public.materials(id),
  boq_item_id     BIGINT REFERENCES public.boq_items(id),
  requested_qty   NUMERIC(15,3) NOT NULL CHECK (requested_qty > 0),
  approved_qty    NUMERIC(15,3),
  issued_qty      NUMERIC(15,3) NOT NULL DEFAULT 0,
  unit_of_measure TEXT NOT NULL,
  remarks         TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by      UUID REFERENCES auth.users(id),
  updated_by      UUID REFERENCES auth.users(id),
  deleted_at      TIMESTAMPTZ,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX mr_items_mr_id_idx       ON public.material_request_items(mr_id);
CREATE INDEX mr_items_material_id_idx ON public.material_request_items(material_id);
CREATE INDEX mr_items_boq_item_id_idx ON public.material_request_items(boq_item_id);

CREATE TRIGGER mr_items_updated_at
  BEFORE UPDATE ON public.material_request_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- BR-007: MR qty cannot exceed BOQ planned qty
CREATE OR REPLACE FUNCTION public.check_mr_qty_vs_boq()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_planned_qty     NUMERIC;
  v_total_requested NUMERIC;
  v_mr_status       TEXT;
BEGIN
  IF NEW.boq_item_id IS NULL THEN RETURN NEW; END IF;

  SELECT status INTO v_mr_status
  FROM public.material_requests WHERE id = NEW.mr_id;
  IF v_mr_status = 'draft' THEN RETURN NEW; END IF;  -- only enforce on submit

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
    RAISE EXCEPTION 'Total requested quantity (%) exceeds BOQ planned quantity (%). Seek approval first.',
      v_total_requested + NEW.requested_qty, v_planned_qty USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER mr_items_check_boq
  BEFORE INSERT OR UPDATE ON public.material_request_items
  FOR EACH ROW EXECUTE FUNCTION public.check_mr_qty_vs_boq();

ALTER TABLE public.material_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.material_request_items FORCE ROW LEVEL SECURITY;

CREATE POLICY "mr_items_admin_all" ON public.material_request_items
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');
CREATE POLICY "mr_items_read" ON public.material_request_items
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "mr_items_engineer_write" ON public.material_request_items
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) IN ('engineer','admin'));

-- ============================================================
-- ISSUE SLIPS (Module 5)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.issue_slips (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  slip_number  TEXT UNIQUE,    -- auto: IS-YYYY-NNNN
  mr_id        BIGINT NOT NULL REFERENCES public.material_requests(id),
  project_id   BIGINT NOT NULL REFERENCES public.projects(id),
  warehouse_id BIGINT NOT NULL REFERENCES public.warehouses(id),
  issued_by    UUID NOT NULL REFERENCES auth.users(id),
  issued_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status       TEXT NOT NULL DEFAULT 'draft'
               CHECK (status IN ('draft','complete')),
  pdf_url      TEXT,          -- Supabase Storage URL after generation
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by   UUID REFERENCES auth.users(id),
  updated_by   UUID REFERENCES auth.users(id),
  deleted_at   TIMESTAMPTZ,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX issue_slips_mr_id_idx      ON public.issue_slips(mr_id);
CREATE INDEX issue_slips_project_id_idx ON public.issue_slips(project_id);

CREATE TRIGGER issue_slips_updated_at
  BEFORE UPDATE ON public.issue_slips
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER issue_slips_audit
  AFTER INSERT OR UPDATE ON public.issue_slips
  FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();

CREATE OR REPLACE FUNCTION public.set_slip_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.slip_number IS NULL THEN
    NEW.slip_number := public.generate_doc_number('IS', 'seq_is_number');
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER issue_slips_set_number
  BEFORE INSERT ON public.issue_slips
  FOR EACH ROW EXECUTE FUNCTION public.set_slip_number();

ALTER TABLE public.issue_slips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.issue_slips FORCE ROW LEVEL SECURITY;

CREATE POLICY "issue_slips_admin_all" ON public.issue_slips
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');
CREATE POLICY "issue_slips_read" ON public.issue_slips
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "issue_slips_store_write" ON public.issue_slips
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','store'));

-- ============================================================
-- ISSUE SLIP ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.issue_slip_items (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  slip_id          BIGINT NOT NULL REFERENCES public.issue_slips(id),
  mr_item_id       BIGINT NOT NULL REFERENCES public.material_request_items(id),
  boq_item_id      BIGINT REFERENCES public.boq_items(id),
  material_id      BIGINT NOT NULL REFERENCES public.materials(id),
  warehouse_id     BIGINT NOT NULL REFERENCES public.warehouses(id),
  requested_qty    NUMERIC(15,3) NOT NULL,
  issued_qty       NUMERIC(15,3) NOT NULL CHECK (issued_qty > 0),
  unit_of_measure  TEXT NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by       UUID REFERENCES auth.users(id),
  deleted_at       TIMESTAMPTZ,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX issue_slip_items_slip_id_idx     ON public.issue_slip_items(slip_id);
CREATE INDEX issue_slip_items_mr_item_id_idx  ON public.issue_slip_items(mr_item_id);
CREATE INDEX issue_slip_items_material_id_idx ON public.issue_slip_items(material_id);
CREATE INDEX issue_slip_items_boq_item_id_idx ON public.issue_slip_items(boq_item_id);

CREATE TRIGGER issue_slip_items_updated_at
  BEFORE UPDATE ON public.issue_slip_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.issue_slip_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.issue_slip_items FORCE ROW LEVEL SECURITY;

CREATE POLICY "isi_admin_all" ON public.issue_slip_items
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');
CREATE POLICY "isi_read" ON public.issue_slip_items
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "isi_store_write" ON public.issue_slip_items
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','store'));

-- Trigger: on issue slip completion → stock_out + update MR items (BR-002)
CREATE OR REPLACE FUNCTION public.stock_out_on_issuance()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.status = 'complete' AND OLD.status = 'draft' THEN

    -- Create stock_out transactions (trigger on stock_transactions updates balances)
    INSERT INTO public.stock_transactions (
      material_id, warehouse_id, transaction_type, quantity,
      reference_type, reference_id, project_id, created_by
    )
    SELECT
      isi.material_id, isi.warehouse_id, 'stock_out',
      -isi.issued_qty,   -- negative = leaving inventory
      'issue_slip', NEW.id, NEW.project_id, auth.uid()
    FROM public.issue_slip_items isi
    WHERE isi.slip_id = NEW.id AND isi.deleted_at IS NULL;

    -- Update mr_item.issued_qty
    UPDATE public.material_request_items mri
    SET issued_qty = issued_qty + isi.issued_qty
    FROM public.issue_slip_items isi
    WHERE isi.slip_id = NEW.id AND mri.id = isi.mr_item_id;

    -- Release reservations
    UPDATE public.stock_balances sb
    SET reserved_qty = GREATEST(0, reserved_qty - isi.issued_qty)
    FROM public.issue_slip_items isi
    WHERE isi.slip_id = NEW.id AND sb.material_id = isi.material_id
      AND sb.warehouse_id = isi.warehouse_id;

    -- Update MR status
    UPDATE public.material_requests mr
    SET status = CASE
      WHEN (
        SELECT SUM(mri2.requested_qty) = SUM(mri2.issued_qty)
        FROM public.material_request_items mri2
        WHERE mri2.mr_id = NEW.mr_id AND mri2.deleted_at IS NULL
      ) THEN 'fully_issued'
      ELSE 'partially_issued'
    END
    WHERE mr.id = NEW.mr_id;

  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER issue_slip_complete_stock_out
  AFTER UPDATE ON public.issue_slips
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.stock_out_on_issuance();