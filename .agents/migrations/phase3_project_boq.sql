-- ============================================================
-- PHASE 3 — Projects, Zones, BOQ
-- Tables: clients, projects, project_zones, boq_headers, boq_items
-- Run via: supabase migration new phase3_projects_boq
-- ============================================================

-- ============================================================
-- CLIENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.clients (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name           TEXT NOT NULL,
  gstin          TEXT,
  pan            TEXT,
  contact_person TEXT,
  phone          TEXT,
  email          TEXT,
  address        TEXT,
  city           TEXT,
  state          TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by     UUID REFERENCES auth.users(id),
  updated_by     UUID REFERENCES auth.users(id),
  deleted_at     TIMESTAMPTZ,
  is_active      BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TRIGGER clients_updated_at
  BEFORE UPDATE ON public.clients
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients FORCE ROW LEVEL SECURITY;

CREATE POLICY "clients_read" ON public.clients
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "clients_admin_write" ON public.clients
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');

-- ============================================================
-- PROJECTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.projects (
  id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  project_code          TEXT UNIQUE,           -- auto-generated: PP-YYYY-NNNN
  name                  TEXT NOT NULL,
  client_id             BIGINT NOT NULL REFERENCES public.clients(id),
  location              TEXT,
  city                  TEXT,
  contract_value        NUMERIC(15,2),
  start_date            DATE NOT NULL,
  end_date              DATE,
  status                TEXT NOT NULL DEFAULT 'planning'
                        CHECK (status IN ('planning','active','on_hold','completed','closed')),
  assigned_engineer_id  UUID REFERENCES auth.users(id),
  description           TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by            UUID REFERENCES auth.users(id),
  updated_by            UUID REFERENCES auth.users(id),
  deleted_at            TIMESTAMPTZ,
  is_active             BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX projects_client_id_idx           ON public.projects(client_id);
CREATE INDEX projects_assigned_engineer_idx   ON public.projects(assigned_engineer_id);
CREATE INDEX projects_status_idx              ON public.projects(status)
  WHERE deleted_at IS NULL;
CREATE INDEX projects_active_idx              ON public.projects(id)
  WHERE deleted_at IS NULL AND is_active = TRUE;

CREATE TRIGGER projects_updated_at
  BEFORE UPDATE ON public.projects
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER projects_audit
  AFTER INSERT OR UPDATE ON public.projects
  FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();

-- Auto-generate project_code: PP-YYYY-NNNN
CREATE OR REPLACE FUNCTION public.set_project_code()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.project_code IS NULL THEN
    NEW.project_code := public.generate_doc_number('PP', 'seq_project_number');
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER projects_set_code
  BEFORE INSERT ON public.projects
  FOR EACH ROW EXECUTE FUNCTION public.set_project_code();

-- Enforce status flow: planning→active→on_hold→active, active→completed→closed
CREATE OR REPLACE FUNCTION public.enforce_project_status_flow()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status = 'closed' THEN
    RAISE EXCEPTION 'A closed project cannot be modified' USING ERRCODE = 'P0001';
  END IF;
  IF NOT (
    (OLD.status = 'planning'   AND NEW.status IN ('active','planning')) OR
    (OLD.status = 'active'     AND NEW.status IN ('on_hold','completed','active')) OR
    (OLD.status = 'on_hold'    AND NEW.status IN ('active','on_hold')) OR
    (OLD.status = 'completed'  AND NEW.status IN ('closed','completed')) OR
    (OLD.status = 'closed'     AND NEW.status = 'closed')
  ) THEN
    RAISE EXCEPTION 'Invalid project status transition: % → %', OLD.status, NEW.status
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER projects_status_flow
  BEFORE UPDATE ON public.projects
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.enforce_project_status_flow();

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects FORCE ROW LEVEL SECURITY;

-- Admin: all
CREATE POLICY "projects_admin_all" ON public.projects
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');

-- Owner: read all
CREATE POLICY "projects_owner_read" ON public.projects
  FOR SELECT TO authenticated
  USING ((SELECT public.current_user_role()) = 'owner' AND deleted_at IS NULL);

-- Engineer: read only assigned projects
CREATE POLICY "projects_engineer_read" ON public.projects
  FOR SELECT TO authenticated
  USING (
    (SELECT public.current_user_role()) = 'engineer'
    AND assigned_engineer_id = (SELECT auth.uid())
    AND deleted_at IS NULL
  );

-- Store + Purchase: read all active (need project context for MR/PO)
CREATE POLICY "projects_store_purchase_read" ON public.projects
  FOR SELECT TO authenticated
  USING (
    (SELECT public.current_user_role()) IN ('store','purchase')
    AND deleted_at IS NULL
  );

-- ============================================================
-- PROJECT ZONES (Module 12)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.project_zones (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  project_id  BIGINT NOT NULL REFERENCES public.projects(id),
  zone_code   TEXT NOT NULL,   -- A, B, C or custom
  name        TEXT NOT NULL,   -- e.g. "Zone A — Andheri Section"
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by  UUID REFERENCES auth.users(id),
  updated_by  UUID REFERENCES auth.users(id),
  deleted_at  TIMESTAMPTZ,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE(project_id, zone_code)
);

CREATE INDEX project_zones_project_id_idx ON public.project_zones(project_id);

CREATE TRIGGER project_zones_updated_at
  BEFORE UPDATE ON public.project_zones
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.project_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_zones FORCE ROW LEVEL SECURITY;

CREATE POLICY "project_zones_admin_all" ON public.project_zones
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');

CREATE POLICY "project_zones_read" ON public.project_zones
  FOR SELECT TO authenticated
  USING (deleted_at IS NULL AND (SELECT public.user_has_project_access(project_id)));

CREATE POLICY "project_zones_engineer_write" ON public.project_zones
  FOR INSERT TO authenticated
  WITH CHECK (
    (SELECT public.current_user_role()) IN ('admin','engineer')
    AND (SELECT public.user_has_project_access(project_id))
  );

-- ============================================================
-- BOQ HEADERS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.boq_headers (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  project_id  BIGINT NOT NULL REFERENCES public.projects(id),
  revision    INT NOT NULL DEFAULT 1,
  status      TEXT NOT NULL DEFAULT 'draft'
              CHECK (status IN ('draft','submitted','approved')),
  notes       TEXT,
  approved_by UUID REFERENCES auth.users(id),
  approved_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by  UUID REFERENCES auth.users(id),
  updated_by  UUID REFERENCES auth.users(id),
  deleted_at  TIMESTAMPTZ,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE(project_id, revision)
);

CREATE INDEX boq_headers_project_id_idx ON public.boq_headers(project_id);
CREATE INDEX boq_headers_status_idx     ON public.boq_headers(status)
  WHERE deleted_at IS NULL;

CREATE TRIGGER boq_headers_updated_at
  BEFORE UPDATE ON public.boq_headers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER boq_headers_audit
  AFTER INSERT OR UPDATE ON public.boq_headers
  FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();

ALTER TABLE public.boq_headers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boq_headers FORCE ROW LEVEL SECURITY;

CREATE POLICY "boq_admin_all" ON public.boq_headers
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');
CREATE POLICY "boq_read" ON public.boq_headers
  FOR SELECT TO authenticated
  USING (deleted_at IS NULL AND (SELECT public.user_has_project_access(project_id)));
CREATE POLICY "boq_owner_approve" ON public.boq_headers
  FOR UPDATE TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','owner'));

-- ============================================================
-- BOQ ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.boq_items (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  boq_header_id       BIGINT NOT NULL REFERENCES public.boq_headers(id),
  material_id         BIGINT NOT NULL REFERENCES public.materials(id),
  zone_id             BIGINT REFERENCES public.project_zones(id),
  planned_qty         NUMERIC(15,3) NOT NULL CHECK (planned_qty > 0),
  unit_of_measure     TEXT NOT NULL,
  unit_rate           NUMERIC(15,2),
  total_budgeted_cost NUMERIC(15,2)
                      GENERATED ALWAYS AS (planned_qty * unit_rate) STORED,
  remarks             TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by          UUID REFERENCES auth.users(id),
  updated_by          UUID REFERENCES auth.users(id),
  deleted_at          TIMESTAMPTZ,
  is_active           BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX boq_items_boq_header_id_idx ON public.boq_items(boq_header_id);
CREATE INDEX boq_items_material_id_idx   ON public.boq_items(material_id);
CREATE INDEX boq_items_zone_id_idx       ON public.boq_items(zone_id);

CREATE TRIGGER boq_items_updated_at
  BEFORE UPDATE ON public.boq_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.boq_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boq_items FORCE ROW LEVEL SECURITY;

CREATE POLICY "boq_items_admin_all" ON public.boq_items
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');
CREATE POLICY "boq_items_read" ON public.boq_items
  FOR SELECT TO authenticated
  USING (deleted_at IS NULL);

-- ============================================================
-- VIEW: boq_variance (AD-020 — derived quantities, never stored)
-- ============================================================

CREATE OR REPLACE VIEW public.boq_variance AS
SELECT
  bi.id                                                    AS boq_item_id,
  bi.boq_header_id,
  bh.project_id,
  bi.material_id,
  m.name                                                   AS material_name,
  m.unit_of_measure                                        AS uom,
  bi.zone_id,
  bi.planned_qty,
  bi.unit_rate,
  bi.total_budgeted_cost,
  COALESCE(SUM(DISTINCT mri.requested_qty), 0)             AS requested_qty,
  COALESCE(SUM(DISTINCT isi.issued_qty),    0)             AS issued_qty,
  COALESCE(SUM(DISTINCT ce.consumed_qty),   0)             AS consumed_qty,
  COALESCE(SUM(DISTINCT re.returned_qty),   0)             AS returned_qty,
  COALESCE(SUM(DISTINCT we.wastage_qty),    0)             AS wastage_qty,
  bi.planned_qty - COALESCE(SUM(DISTINCT isi.issued_qty), 0) AS remaining_qty,
  COALESCE(SUM(DISTINCT mri.requested_qty), 0)
    - bi.planned_qty                                       AS boq_variance_qty,
  ROUND(
    CASE WHEN bi.planned_qty > 0
    THEN ((COALESCE(SUM(DISTINCT mri.requested_qty), 0) - bi.planned_qty)
          / bi.planned_qty * 100)
    ELSE 0 END, 2
  )                                                        AS boq_variance_pct
FROM public.boq_items bi
JOIN public.boq_headers bh         ON bh.id = bi.boq_header_id
JOIN public.materials m             ON m.id  = bi.material_id
LEFT JOIN public.material_request_items mri
  ON mri.boq_item_id = bi.id AND mri.deleted_at IS NULL
LEFT JOIN public.issue_slip_items isi
  ON isi.boq_item_id = bi.id AND isi.deleted_at IS NULL
LEFT JOIN public.consumption_entries ce
  ON ce.boq_item_id = bi.id AND ce.deleted_at IS NULL
LEFT JOIN public.return_entries re
  ON re.boq_item_id = bi.id AND re.deleted_at IS NULL
LEFT JOIN public.wastage_entries we
  ON we.boq_item_id = bi.id AND we.deleted_at IS NULL
WHERE bi.deleted_at IS NULL
GROUP BY bi.id, bi.boq_header_id, bh.project_id, bi.material_id,
         m.name, m.unit_of_measure, bi.zone_id, bi.planned_qty,
         bi.unit_rate, bi.total_budgeted_cost;