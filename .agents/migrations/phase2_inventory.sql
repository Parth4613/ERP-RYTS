-- ============================================================
-- PHASE 2 — Inventory
-- Tables: material_categories, materials, warehouses,
--         stock_balances, stock_transactions, inventory_adjustments
-- Run via: supabase migration new phase2_inventory
-- ============================================================

-- ============================================================
-- MATERIAL CATEGORIES (hierarchical)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.material_categories (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        TEXT NOT NULL,
  parent_id   BIGINT REFERENCES public.material_categories(id),  -- nullable = root
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by  UUID REFERENCES auth.users(id),
  updated_by  UUID REFERENCES auth.users(id),
  deleted_at  TIMESTAMPTZ,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX material_categories_parent_id_idx ON public.material_categories(parent_id);

CREATE TRIGGER material_categories_updated_at
  BEFORE UPDATE ON public.material_categories
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.material_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.material_categories FORCE ROW LEVEL SECURITY;

CREATE POLICY "mat_cat_read" ON public.material_categories
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "mat_cat_admin_write" ON public.material_categories
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');

-- Seed categories for gas pipeline company
INSERT INTO public.material_categories (name, description) VALUES
  ('Pipes & Fittings',    'GI pipes, HDPE pipes, elbows, tees, reducers'),
  ('Valves',              'Ball valves, gate valves, pressure relief valves'),
  ('Meters & Regulators', 'Gas meters, pressure regulators, governors'),
  ('Electrical',          'Cables, conduits, junction boxes, switches'),
  ('Civil Materials',     'Cement, sand, bricks, RCC materials'),
  ('Safety Equipment',    'PPE, helmets, harnesses, fire extinguishers'),
  ('Tools & Hardware',    'Hand tools, fasteners, clamps, gaskets'),
  ('Consumables',         'Welding rods, teflon tape, solvents, lubricants')
ON CONFLICT DO NOTHING;

-- ============================================================
-- MATERIALS (master catalog)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.materials (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  category_id     BIGINT REFERENCES public.material_categories(id),
  code            TEXT UNIQUE,
  name            TEXT NOT NULL,
  description     TEXT,
  unit_of_measure TEXT NOT NULL,              -- m, kg, nos, set, litre
  min_stock_level NUMERIC(15,3) DEFAULT 0,   -- for low-stock alerts
  hsn_code        TEXT,                       -- GST HSN/SAC code
  is_critical     BOOLEAN NOT NULL DEFAULT FALSE,  -- flag critical materials
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by      UUID REFERENCES auth.users(id),
  updated_by      UUID REFERENCES auth.users(id),
  deleted_at      TIMESTAMPTZ,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX materials_category_id_idx ON public.materials(category_id);
CREATE INDEX materials_name_idx        ON public.materials(name);  -- for search
CREATE INDEX materials_active_idx      ON public.materials(id)
  WHERE deleted_at IS NULL AND is_active = TRUE;

CREATE TRIGGER materials_updated_at
  BEFORE UPDATE ON public.materials
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials FORCE ROW LEVEL SECURITY;

CREATE POLICY "materials_read" ON public.materials
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "materials_admin_store_write" ON public.materials
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin', 'store'));

-- ============================================================
-- WAREHOUSES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.warehouses (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        TEXT NOT NULL,
  location    TEXT,
  project_id  BIGINT,    -- NULL = central warehouse; set for project-site store
  is_central  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by  UUID REFERENCES auth.users(id),
  updated_by  UUID REFERENCES auth.users(id),
  deleted_at  TIMESTAMPTZ,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX warehouses_project_id_idx ON public.warehouses(project_id);

CREATE TRIGGER warehouses_updated_at
  BEFORE UPDATE ON public.warehouses
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouses FORCE ROW LEVEL SECURITY;

CREATE POLICY "warehouses_read" ON public.warehouses
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "warehouses_admin_write" ON public.warehouses
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin', 'store'));

-- Seed: central warehouse
INSERT INTO public.warehouses (name, location, is_central)
VALUES ('Central Store', 'Head Office', TRUE)
ON CONFLICT DO NOTHING;

-- ============================================================
-- STOCK BALANCES (maintained by trigger — never update directly)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.stock_balances (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  material_id   BIGINT NOT NULL REFERENCES public.materials(id),
  warehouse_id  BIGINT NOT NULL REFERENCES public.warehouses(id),
  quantity      NUMERIC(15,3) NOT NULL DEFAULT 0
                  CONSTRAINT chk_qty_non_negative CHECK (quantity >= 0),
  reserved_qty  NUMERIC(15,3) NOT NULL DEFAULT 0
                  CONSTRAINT chk_reserved_non_negative CHECK (reserved_qty >= 0),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(material_id, warehouse_id)
);

CREATE INDEX stock_balances_material_id_idx  ON public.stock_balances(material_id);
CREATE INDEX stock_balances_warehouse_id_idx ON public.stock_balances(warehouse_id);
-- Index for low-stock alert query
CREATE INDEX stock_balances_low_stock_idx ON public.stock_balances(material_id)
  WHERE quantity <= 0;

ALTER TABLE public.stock_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_balances FORCE ROW LEVEL SECURITY;

-- Read: all authenticated; Write: trigger only (no role insert/update policy)
CREATE POLICY "stock_balances_read" ON public.stock_balances
  FOR SELECT TO authenticated USING (TRUE);

-- ============================================================
-- STOCK TRANSACTIONS (immutable audit trail of every movement)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.stock_transactions (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  material_id      BIGINT NOT NULL REFERENCES public.materials(id),
  warehouse_id     BIGINT NOT NULL REFERENCES public.warehouses(id),
  transaction_type TEXT NOT NULL
                   CHECK (transaction_type IN
                     ('stock_in','stock_out','return_in','adjustment','transfer_in','transfer_out')),
  quantity         NUMERIC(15,3) NOT NULL,   -- positive = in, negative = out
  reference_type   TEXT,                     -- 'mrn','issue_slip','return','adjustment','transfer'
  reference_id     BIGINT,                   -- ID of the source document
  project_id       BIGINT,
  notes            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by       UUID REFERENCES auth.users(id),
  -- No updated_at/deleted_at — transactions are immutable
  CONSTRAINT chk_stock_in_positive
    CHECK (transaction_type IN ('stock_in','return_in','transfer_in') AND quantity > 0
        OR transaction_type IN ('stock_out','transfer_out') AND quantity < 0
        OR transaction_type = 'adjustment')  -- adjustment can be +/-
);

CREATE INDEX stock_tx_material_id_idx   ON public.stock_transactions(material_id);
CREATE INDEX stock_tx_warehouse_id_idx  ON public.stock_transactions(warehouse_id);
CREATE INDEX stock_tx_project_id_idx    ON public.stock_transactions(project_id);
CREATE INDEX stock_tx_reference_idx     ON public.stock_transactions(reference_type, reference_id);
CREATE INDEX stock_tx_created_at_brin   ON public.stock_transactions USING BRIN(created_at);
-- Composite for stock balance recalculation
CREATE INDEX stock_tx_balance_idx       ON public.stock_transactions(material_id, warehouse_id);

ALTER TABLE public.stock_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_transactions FORCE ROW LEVEL SECURITY;

CREATE POLICY "stock_tx_read" ON public.stock_transactions
  FOR SELECT TO authenticated USING (TRUE);
-- INSERT only via SECURITY DEFINER triggers — no direct insert policy for app roles

-- ============================================================
-- TRIGGER: stock_transactions → update stock_balances (BR-002, BR-003)
-- ============================================================

CREATE OR REPLACE FUNCTION public.apply_stock_transaction()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.stock_balances (material_id, warehouse_id, quantity, reserved_qty)
  VALUES (NEW.material_id, NEW.warehouse_id, NEW.quantity, 0)
  ON CONFLICT (material_id, warehouse_id)
  DO UPDATE SET
    quantity   = public.stock_balances.quantity + NEW.quantity,
    updated_at = NOW();

  -- BR-001: Enforce non-negative (belt + suspenders alongside CHECK constraint)
  IF (SELECT quantity FROM public.stock_balances
      WHERE material_id = NEW.material_id AND warehouse_id = NEW.warehouse_id) < 0 THEN
    RAISE EXCEPTION 'Stock cannot go negative: material=%, warehouse=%',
      NEW.material_id, NEW.warehouse_id USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER stock_transactions_apply_balance
  AFTER INSERT ON public.stock_transactions
  FOR EACH ROW EXECUTE FUNCTION public.apply_stock_transaction();

-- ============================================================
-- INVENTORY ADJUSTMENTS (BR-004 — require approval)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.inventory_adjustments (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  material_id    BIGINT NOT NULL REFERENCES public.materials(id),
  warehouse_id   BIGINT NOT NULL REFERENCES public.warehouses(id),
  adjustment_qty NUMERIC(15,3) NOT NULL,   -- positive = add, negative = remove
  reason         TEXT NOT NULL,
  status         TEXT NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','approved','rejected')),
  requested_by   UUID REFERENCES auth.users(id),
  approved_by    UUID REFERENCES auth.users(id),
  approved_at    TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by     UUID REFERENCES auth.users(id),
  updated_by     UUID REFERENCES auth.users(id),
  deleted_at     TIMESTAMPTZ,
  is_active      BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX inv_adj_material_id_idx  ON public.inventory_adjustments(material_id);
CREATE INDEX inv_adj_warehouse_id_idx ON public.inventory_adjustments(warehouse_id);
CREATE INDEX inv_adj_status_idx       ON public.inventory_adjustments(status)
  WHERE status = 'pending';

CREATE TRIGGER inventory_adjustments_updated_at
  BEFORE UPDATE ON public.inventory_adjustments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER inventory_adjustments_audit
  AFTER INSERT OR UPDATE ON public.inventory_adjustments
  FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();

ALTER TABLE public.inventory_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_adjustments FORCE ROW LEVEL SECURITY;

CREATE POLICY "inv_adj_read" ON public.inventory_adjustments
  FOR SELECT TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','owner','store'));
CREATE POLICY "inv_adj_store_insert" ON public.inventory_adjustments
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.current_user_role()) IN ('admin','store'));
CREATE POLICY "inv_adj_admin_approve" ON public.inventory_adjustments
  FOR UPDATE TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');

-- Trigger: apply adjustment to stock when approved
CREATE OR REPLACE FUNCTION public.apply_approved_adjustment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.status = 'approved' AND OLD.status = 'pending' THEN
    INSERT INTO public.stock_transactions (
      material_id, warehouse_id, transaction_type, quantity,
      reference_type, reference_id, notes, created_by
    ) VALUES (
      NEW.material_id, NEW.warehouse_id, 'adjustment',
      NEW.adjustment_qty, 'adjustment', NEW.id, NEW.reason, auth.uid()
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER inventory_adjustment_apply
  AFTER UPDATE ON public.inventory_adjustments
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.apply_approved_adjustment();

-- ============================================================
-- HELPER: available quantity (used in issue validation)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_available_qty(
  p_material_id  BIGINT,
  p_warehouse_id BIGINT
) RETURNS NUMERIC LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT COALESCE(quantity - reserved_qty, 0)
  FROM public.stock_balances
  WHERE material_id = p_material_id AND warehouse_id = p_warehouse_id;
$$;

-- ============================================================
-- VIEW: inventory_summary (low-stock dashboard widget)
-- ============================================================

CREATE OR REPLACE VIEW public.inventory_summary AS
SELECT
  m.id              AS material_id,
  m.code,
  m.name,
  m.unit_of_measure AS uom,
  m.min_stock_level,
  m.is_critical,
  mc.name           AS category_name,
  w.id              AS warehouse_id,
  w.name            AS warehouse_name,
  COALESCE(sb.quantity, 0)     AS quantity,
  COALESCE(sb.reserved_qty, 0) AS reserved_qty,
  COALESCE(sb.quantity - sb.reserved_qty, 0) AS available_qty,
  CASE
    WHEN COALESCE(sb.quantity, 0) = 0              THEN 'out_of_stock'
    WHEN COALESCE(sb.quantity, 0) <= m.min_stock_level THEN 'low_stock'
    ELSE 'in_stock'
  END AS stock_status
FROM public.materials m
LEFT JOIN public.material_categories mc ON mc.id = m.category_id
CROSS JOIN public.warehouses w
LEFT JOIN public.stock_balances sb
  ON sb.material_id = m.id AND sb.warehouse_id = w.id
WHERE m.deleted_at IS NULL AND w.deleted_at IS NULL;