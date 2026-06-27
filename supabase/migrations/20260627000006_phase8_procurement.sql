-- ============================================================
-- PHASE 8 — Procurement: Suppliers, PR, PO (Modules 6, 7, 8)
-- Run via: supabase migration new phase8_procurement
-- ============================================================

-- ============================================================
-- SUPPLIERS (Module 8)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.suppliers (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  supplier_code  TEXT UNIQUE,   -- auto: SUP-NNN
  name           TEXT NOT NULL,
  gstin          TEXT,
  pan            TEXT,
  iso_certified  BOOLEAN NOT NULL DEFAULT FALSE,
  payment_terms  TEXT,          -- e.g. "30 days net"
  address        TEXT,
  city           TEXT,
  state          TEXT,
  rating         NUMERIC(3,2) DEFAULT 0.00 CHECK (rating >= 0 AND rating <= 5),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by     UUID REFERENCES auth.users(id),
  updated_by     UUID REFERENCES auth.users(id),
  deleted_at     TIMESTAMPTZ,
  is_active      BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX suppliers_name_idx ON public.suppliers(name);

CREATE TRIGGER suppliers_updated_at
  BEFORE UPDATE ON public.suppliers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.set_supplier_code()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.supplier_code IS NULL THEN
    NEW.supplier_code := 'SUP-' || LPAD(nextval('seq_sup_number')::TEXT, 3, '0');
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER suppliers_set_code
  BEFORE INSERT ON public.suppliers
  FOR EACH ROW EXECUTE FUNCTION public.set_supplier_code();

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers FORCE ROW LEVEL SECURITY;

CREATE POLICY "suppliers_read" ON public.suppliers
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "suppliers_purchase_write" ON public.suppliers
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','purchase'));

-- ============================================================
-- SUPPLIER CONTACTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.supplier_contacts (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  supplier_id BIGINT NOT NULL REFERENCES public.suppliers(id),
  name        TEXT NOT NULL,
  designation TEXT,
  phone       TEXT,
  email       TEXT,
  is_primary  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX supplier_contacts_supplier_id_idx ON public.supplier_contacts(supplier_id);

CREATE TRIGGER supplier_contacts_updated_at
  BEFORE UPDATE ON public.supplier_contacts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.supplier_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_contacts FORCE ROW LEVEL SECURITY;

CREATE POLICY "sup_contacts_read" ON public.supplier_contacts
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "sup_contacts_purchase_write" ON public.supplier_contacts
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','purchase'));

-- ============================================================
-- SUPPLIER PRODUCTS (rate catalog)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.supplier_products (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  supplier_id   BIGINT NOT NULL REFERENCES public.suppliers(id),
  material_id   BIGINT NOT NULL REFERENCES public.materials(id),
  description   TEXT,
  unit_rate     NUMERIC(15,2),
  lead_time_days INT,
  last_updated  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE(supplier_id, material_id)
);

CREATE INDEX supplier_products_supplier_id_idx ON public.supplier_products(supplier_id);
CREATE INDEX supplier_products_material_id_idx ON public.supplier_products(material_id);

CREATE TRIGGER supplier_products_updated_at
  BEFORE UPDATE ON public.supplier_products
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.supplier_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_products FORCE ROW LEVEL SECURITY;

CREATE POLICY "sup_products_read" ON public.supplier_products
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "sup_products_purchase_write" ON public.supplier_products
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','purchase'));

-- ============================================================
-- SUPPLIER RATINGS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.supplier_ratings (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  supplier_id         BIGINT NOT NULL REFERENCES public.suppliers(id),
  po_id               BIGINT,                 -- rated per PO
  delivery_score      INT CHECK (delivery_score BETWEEN 1 AND 5),
  quality_score       INT CHECK (quality_score BETWEEN 1 AND 5),
  communication_score INT CHECK (communication_score BETWEEN 1 AND 5),
  overall_score       NUMERIC(3,2) GENERATED ALWAYS AS
    ((delivery_score + quality_score + communication_score)::NUMERIC / 3) STORED,
  comments            TEXT,
  rated_by            UUID REFERENCES auth.users(id),
  rated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX supplier_ratings_supplier_id_idx ON public.supplier_ratings(supplier_id);

ALTER TABLE public.supplier_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_ratings FORCE ROW LEVEL SECURITY;

CREATE POLICY "sup_ratings_read" ON public.supplier_ratings
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "sup_ratings_store_write" ON public.supplier_ratings
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.current_user_role()) IN ('admin','store','purchase'));

-- Auto-update supplier.rating when a rating is inserted
CREATE OR REPLACE FUNCTION public.update_supplier_rating()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.suppliers
  SET rating = (
    SELECT ROUND(AVG(overall_score)::NUMERIC, 2)
    FROM public.supplier_ratings
    WHERE supplier_id = NEW.supplier_id
  )
  WHERE id = NEW.supplier_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER supplier_ratings_update_avg
  AFTER INSERT ON public.supplier_ratings
  FOR EACH ROW EXECUTE FUNCTION public.update_supplier_rating();

-- ============================================================
-- PURCHASE REQUISITIONS (Module 6)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.purchase_requisitions (
  id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  pr_number             TEXT UNIQUE,   -- auto: PR-YYYY-NNNN
  project_id            BIGINT REFERENCES public.projects(id),
  status                TEXT NOT NULL DEFAULT 'draft'
                        CHECK (status IN
                          ('draft','submitted','approved','converted','closed','rejected')),
  priority              TEXT NOT NULL DEFAULT 'medium'
                        CHECK (priority IN ('low','medium','high','urgent')),
  required_by           DATE,
  total_estimated_value NUMERIC(15,2) DEFAULT 0,
  approved_by           UUID REFERENCES auth.users(id),
  approved_at           TIMESTAMPTZ,
  rejection_reason      TEXT,
  notes                 TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by            UUID REFERENCES auth.users(id),
  updated_by            UUID REFERENCES auth.users(id),
  deleted_at            TIMESTAMPTZ,
  is_active             BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX pr_project_id_idx ON public.purchase_requisitions(project_id);
CREATE INDEX pr_status_idx     ON public.purchase_requisitions(status)
  WHERE deleted_at IS NULL;

CREATE TRIGGER pr_updated_at
  BEFORE UPDATE ON public.purchase_requisitions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER pr_audit
  AFTER INSERT OR UPDATE ON public.purchase_requisitions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();

CREATE OR REPLACE FUNCTION public.set_pr_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.pr_number IS NULL THEN
    NEW.pr_number := public.generate_doc_number('PR', 'seq_pr_number');
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER pr_set_number
  BEFORE INSERT ON public.purchase_requisitions
  FOR EACH ROW EXECUTE FUNCTION public.set_pr_number();

ALTER TABLE public.purchase_requisitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_requisitions FORCE ROW LEVEL SECURITY;

CREATE POLICY "pr_admin_all" ON public.purchase_requisitions
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');
CREATE POLICY "pr_read" ON public.purchase_requisitions
  FOR SELECT TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','owner','store','purchase')
    AND deleted_at IS NULL);
CREATE POLICY "pr_store_purchase_write" ON public.purchase_requisitions
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.current_user_role()) IN ('admin','store','purchase'));
CREATE POLICY "pr_owner_approve" ON public.purchase_requisitions
  FOR UPDATE TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','owner'));

-- ============================================================
-- PURCHASE REQUISITION ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.purchase_requisition_items (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  pr_id            BIGINT NOT NULL REFERENCES public.purchase_requisitions(id),
  material_id      BIGINT NOT NULL REFERENCES public.materials(id),
  requested_qty    NUMERIC(15,3) NOT NULL CHECK (requested_qty > 0),
  approved_qty     NUMERIC(15,3),
  estimated_rate   NUMERIC(15,2),
  estimated_value  NUMERIC(15,2) GENERATED ALWAYS AS
                   (approved_qty * estimated_rate) STORED,
  unit_of_measure  TEXT NOT NULL,
  remarks          TEXT,
  source_mr_ids    BIGINT[],    -- which MR items triggered this shortage
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by       UUID REFERENCES auth.users(id),
  deleted_at       TIMESTAMPTZ,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX pr_items_pr_id_idx       ON public.purchase_requisition_items(pr_id);
CREATE INDEX pr_items_material_id_idx ON public.purchase_requisition_items(material_id);

CREATE TRIGGER pr_items_updated_at
  BEFORE UPDATE ON public.purchase_requisition_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.purchase_requisition_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_requisition_items FORCE ROW LEVEL SECURITY;

CREATE POLICY "pr_items_admin_all" ON public.purchase_requisition_items
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');
CREATE POLICY "pr_items_read" ON public.purchase_requisition_items
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "pr_items_write" ON public.purchase_requisition_items
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','store','purchase'));

-- ============================================================
-- PURCHASE ORDERS (Module 7)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.purchase_orders (
  id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  po_number          TEXT UNIQUE,    -- auto: PO-YYYY-NNNN
  pr_id              BIGINT REFERENCES public.purchase_requisitions(id),
  supplier_id        BIGINT NOT NULL REFERENCES public.suppliers(id),
  project_id         BIGINT REFERENCES public.projects(id),
  status             TEXT NOT NULL DEFAULT 'draft'
                     CHECK (status IN
                       ('draft','approved','ordered','partially_received',
                        'fully_received','closed','cancelled')),
  po_date            DATE NOT NULL DEFAULT CURRENT_DATE,
  expected_delivery  DATE,
  actual_delivery    DATE,
  total_amount       NUMERIC(15,2) DEFAULT 0,
  payment_terms      TEXT,
  terms_conditions   TEXT,
  approved_by        UUID REFERENCES auth.users(id),
  approved_at        TIMESTAMPTZ,
  rejection_reason   TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by         UUID REFERENCES auth.users(id),
  updated_by         UUID REFERENCES auth.users(id),
  deleted_at         TIMESTAMPTZ,
  is_active          BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX po_pr_id_idx         ON public.purchase_orders(pr_id);
CREATE INDEX po_supplier_id_idx   ON public.purchase_orders(supplier_id);
CREATE INDEX po_project_id_idx    ON public.purchase_orders(project_id);
CREATE INDEX po_status_idx        ON public.purchase_orders(status)
  WHERE deleted_at IS NULL;
-- For overdue delivery alert: status=ordered AND expected_delivery < today
CREATE INDEX po_delivery_idx      ON public.purchase_orders(expected_delivery, status)
  WHERE status IN ('ordered','partially_received') AND deleted_at IS NULL;

CREATE TRIGGER po_updated_at
  BEFORE UPDATE ON public.purchase_orders
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER po_audit
  AFTER INSERT OR UPDATE ON public.purchase_orders
  FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();

CREATE OR REPLACE FUNCTION public.set_po_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.po_number IS NULL THEN
    NEW.po_number := public.generate_doc_number('PO', 'seq_po_number');
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER po_set_number
  BEFORE INSERT ON public.purchase_orders
  FOR EACH ROW EXECUTE FUNCTION public.set_po_number();

ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_orders FORCE ROW LEVEL SECURITY;

CREATE POLICY "po_admin_all" ON public.purchase_orders
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');
CREATE POLICY "po_read" ON public.purchase_orders
  FOR SELECT TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','owner','store','purchase')
    AND deleted_at IS NULL);
CREATE POLICY "po_purchase_write" ON public.purchase_orders
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.current_user_role()) IN ('admin','purchase'));
CREATE POLICY "po_owner_approve" ON public.purchase_orders
  FOR UPDATE TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','owner'));

-- ============================================================
-- PURCHASE ORDER ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.purchase_order_items (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  po_id           BIGINT NOT NULL REFERENCES public.purchase_orders(id),
  pr_item_id      BIGINT REFERENCES public.purchase_requisition_items(id),
  material_id     BIGINT NOT NULL REFERENCES public.materials(id),
  ordered_qty     NUMERIC(15,3) NOT NULL CHECK (ordered_qty > 0),
  unit_rate       NUMERIC(15,2) NOT NULL CHECK (unit_rate >= 0),
  total_value     NUMERIC(15,2) GENERATED ALWAYS AS (ordered_qty * unit_rate) STORED,
  received_qty    NUMERIC(15,3) NOT NULL DEFAULT 0,
  unit_of_measure TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by      UUID REFERENCES auth.users(id),
  deleted_at      TIMESTAMPTZ,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX po_items_po_id_idx       ON public.purchase_order_items(po_id);
CREATE INDEX po_items_pr_item_id_idx  ON public.purchase_order_items(pr_item_id);
CREATE INDEX po_items_material_id_idx ON public.purchase_order_items(material_id);

CREATE TRIGGER po_items_updated_at
  BEFORE UPDATE ON public.purchase_order_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- BR-016: PO qty cannot exceed approved PR qty
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
    RAISE EXCEPTION 'PO qty (%) exceeds approved PR qty (%)',
      v_already_po_qty + NEW.ordered_qty, v_approved_qty USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER po_items_check_pr_qty
  BEFORE INSERT OR UPDATE ON public.purchase_order_items
  FOR EACH ROW EXECUTE FUNCTION public.enforce_po_qty_vs_pr();

ALTER TABLE public.purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_order_items FORCE ROW LEVEL SECURITY;

CREATE POLICY "po_items_admin_all" ON public.purchase_order_items
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');
CREATE POLICY "po_items_read" ON public.purchase_order_items
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "po_items_purchase_write" ON public.purchase_order_items
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','purchase'));