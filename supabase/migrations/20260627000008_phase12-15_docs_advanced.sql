-- ============================================================
-- PHASE 12 — Document Management (Module 13)
-- PHASE 14 — Dashboard support tables
-- PHASE 15 — Advanced Features (Equipment, Vehicle, Diesel)
-- Run via: supabase migration new phase12_15_docs_advanced
-- ============================================================

-- ============================================================
-- DOCUMENT MANAGEMENT (Module 13)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.document_categories (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO public.document_categories (name) VALUES
  ('Drawings'), ('BOQ Files'), ('Agreements'), ('Invoices'),
  ('Test Reports'), ('Photographs'), ('Permits'), ('Miscellaneous')
ON CONFLICT DO NOTHING;

ALTER TABLE public.document_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_categories FORCE ROW LEVEL SECURITY;
CREATE POLICY "doc_cat_read" ON public.document_categories
  FOR SELECT TO authenticated USING (TRUE);

CREATE TABLE IF NOT EXISTS public.documents (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  project_id    BIGINT NOT NULL REFERENCES public.projects(id),
  category_id   BIGINT NOT NULL REFERENCES public.document_categories(id),
  name          TEXT NOT NULL,
  file_url      TEXT NOT NULL,    -- Supabase Storage URL
  file_size     BIGINT,           -- bytes
  mime_type     TEXT,
  tags          TEXT[],
  description   TEXT,
  uploaded_by   UUID NOT NULL REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by    UUID REFERENCES auth.users(id),
  updated_by    UUID REFERENCES auth.users(id),
  deleted_at    TIMESTAMPTZ,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX documents_project_id_idx   ON public.documents(project_id);
CREATE INDEX documents_category_id_idx  ON public.documents(category_id);
-- GIN index for tag search
CREATE INDEX documents_tags_gin         ON public.documents USING GIN(tags);

CREATE TRIGGER documents_updated_at
  BEFORE UPDATE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents FORCE ROW LEVEL SECURITY;

CREATE POLICY "documents_admin_all" ON public.documents
  FOR ALL TO authenticated USING ((SELECT public.current_user_role()) = 'admin');
CREATE POLICY "documents_read" ON public.documents
  FOR SELECT TO authenticated
  USING (deleted_at IS NULL AND (SELECT public.user_has_project_access(project_id)));
CREATE POLICY "documents_upload" ON public.documents
  FOR INSERT TO authenticated
  WITH CHECK (
    (SELECT public.current_user_role()) IN ('admin','engineer','store','purchase')
    AND (SELECT public.user_has_project_access(project_id))
  );
CREATE POLICY "documents_admin_delete" ON public.documents
  FOR UPDATE TO authenticated
  USING ((SELECT public.current_user_role()) = 'admin');

-- ============================================================
-- ADVANCED: EQUIPMENT TRACKING
-- ============================================================

CREATE TABLE IF NOT EXISTS public.equipment (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name            TEXT NOT NULL,
  type            TEXT,           -- excavator, crane, compressor, etc.
  registration_no TEXT,
  owned_or_hired  TEXT DEFAULT 'hired' CHECK (owned_or_hired IN ('owned','hired')),
  vendor_name     TEXT,
  rate_per_day    NUMERIC(15,2),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by      UUID REFERENCES auth.users(id),
  deleted_at      TIMESTAMPTZ,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS public.equipment_usage (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  equipment_id  BIGINT NOT NULL REFERENCES public.equipment(id),
  project_id    BIGINT NOT NULL REFERENCES public.projects(id),
  usage_date    DATE NOT NULL DEFAULT CURRENT_DATE,
  hours_used    NUMERIC(6,2),
  days_used     NUMERIC(6,2) DEFAULT 1,
  amount        NUMERIC(15,2),
  recorded_by   UUID REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by    UUID REFERENCES auth.users(id),
  deleted_at    TIMESTAMPTZ,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX equipment_usage_project_id_idx   ON public.equipment_usage(project_id);
CREATE INDEX equipment_usage_equipment_id_idx ON public.equipment_usage(equipment_id);

CREATE TRIGGER equipment_updated_at
  BEFORE UPDATE ON public.equipment
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER equipment_usage_updated_at
  BEFORE UPDATE ON public.equipment_usage
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipment FORCE ROW LEVEL SECURITY;
CREATE POLICY "equipment_read" ON public.equipment
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "equipment_admin_write" ON public.equipment
  FOR ALL TO authenticated USING ((SELECT public.current_user_role()) = 'admin');

ALTER TABLE public.equipment_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipment_usage FORCE ROW LEVEL SECURITY;
CREATE POLICY "equipment_usage_read" ON public.equipment_usage
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "equipment_usage_write" ON public.equipment_usage
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','engineer','store'));

-- ============================================================
-- ADVANCED: VEHICLE TRACKING + DIESEL
-- ============================================================

CREATE TABLE IF NOT EXISTS public.vehicles (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  registration_no TEXT NOT NULL UNIQUE,
  type            TEXT,     -- truck, pickup, excavator, car
  owned_or_hired  TEXT DEFAULT 'hired' CHECK (owned_or_hired IN ('owned','hired')),
  driver_name     TEXT,
  driver_phone    TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by      UUID REFERENCES auth.users(id),
  deleted_at      TIMESTAMPTZ,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS public.vehicle_logs (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  vehicle_id    BIGINT NOT NULL REFERENCES public.vehicles(id),
  project_id    BIGINT NOT NULL REFERENCES public.projects(id),
  log_date      DATE NOT NULL DEFAULT CURRENT_DATE,
  purpose       TEXT,
  km_start      NUMERIC(10,1),
  km_end        NUMERIC(10,1),
  km_travelled  NUMERIC(10,1) GENERATED ALWAYS AS (km_end - km_start) STORED,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by    UUID REFERENCES auth.users(id),
  deleted_at    TIMESTAMPTZ,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS public.diesel_logs (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  vehicle_id    BIGINT REFERENCES public.vehicles(id),
  equipment_id  BIGINT REFERENCES public.equipment(id),
  project_id    BIGINT NOT NULL REFERENCES public.projects(id),
  log_date      DATE NOT NULL DEFAULT CURRENT_DATE,
  litres        NUMERIC(10,2) NOT NULL CHECK (litres > 0),
  rate_per_litre NUMERIC(8,2),
  total_cost    NUMERIC(15,2) GENERATED ALWAYS AS (litres * rate_per_litre) STORED,
  recorded_by   UUID REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by    UUID REFERENCES auth.users(id),
  deleted_at    TIMESTAMPTZ,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT chk_vehicle_or_equipment
    CHECK (vehicle_id IS NOT NULL OR equipment_id IS NOT NULL)
);

CREATE INDEX vehicle_logs_vehicle_id_idx   ON public.vehicle_logs(vehicle_id);
CREATE INDEX vehicle_logs_project_id_idx   ON public.vehicle_logs(project_id);
CREATE INDEX diesel_logs_project_id_idx    ON public.diesel_logs(project_id);

ALTER TABLE public.vehicles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles       FORCE  ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_logs   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_logs   FORCE  ROW LEVEL SECURITY;
ALTER TABLE public.diesel_logs    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diesel_logs    FORCE  ROW LEVEL SECURITY;

CREATE POLICY "vehicles_read" ON public.vehicles
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "vehicles_admin" ON public.vehicles
  FOR ALL TO authenticated USING ((SELECT public.current_user_role()) = 'admin');

CREATE POLICY "vehicle_logs_read" ON public.vehicle_logs
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "vehicle_logs_write" ON public.vehicle_logs
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','engineer','store'));

CREATE POLICY "diesel_logs_read" ON public.diesel_logs
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "diesel_logs_write" ON public.diesel_logs
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','engineer','store'));

-- ============================================================
-- NOTIFICATION LOGS (for tracking notification delivery)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.notification_logs (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  notification_id BIGINT NOT NULL REFERENCES public.notifications(id),
  channel         TEXT NOT NULL CHECK (channel IN ('in_app','push','email','whatsapp')),
  status          TEXT NOT NULL CHECK (status IN ('sent','delivered','failed')),
  sent_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  error_message   TEXT
);

CREATE INDEX notification_logs_notif_id_idx ON public.notification_logs(notification_id);

ALTER TABLE public.notification_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_logs FORCE ROW LEVEL SECURITY;
CREATE POLICY "notif_logs_admin" ON public.notification_logs
  FOR ALL TO authenticated USING ((SELECT public.current_user_role()) = 'admin');

-- ============================================================
-- EXECUTIVE DASHBOARD: materialized-style views
-- ============================================================

-- Project health summary (used on executive dashboard)
CREATE OR REPLACE VIEW public.project_health AS
SELECT
  p.id,
  p.project_code,
  p.name,
  p.status,
  p.start_date,
  p.end_date,
  p.contract_value,
  -- Cost
  COALESCE(SUM(pc.amount), 0)                         AS total_cost_to_date,
  p.contract_value - COALESCE(SUM(pc.amount), 0)      AS cost_remaining,
  CASE WHEN p.contract_value > 0
    THEN ROUND(COALESCE(SUM(pc.amount), 0) / p.contract_value * 100, 2)
    ELSE 0 END                                         AS cost_utilization_pct,
  -- Schedule
  CASE
    WHEN p.end_date < CURRENT_DATE AND p.status NOT IN ('completed','closed')
    THEN 'delayed'
    WHEN p.end_date <= CURRENT_DATE + INTERVAL '30 days' AND p.status = 'active'
    THEN 'at_risk'
    ELSE 'on_track'
  END                                                  AS schedule_status,
  -- Pending approvals
  COUNT(DISTINCT aw.id) FILTER (WHERE aw.status = 'pending') AS pending_approvals
FROM public.projects p
LEFT JOIN public.project_costs pc ON pc.project_id = p.id AND pc.deleted_at IS NULL
LEFT JOIN public.approval_workflows aw ON aw.entity_type IN ('mr','pr','po')
  AND aw.status = 'pending'
WHERE p.deleted_at IS NULL
GROUP BY p.id, p.project_code, p.name, p.status,
         p.start_date, p.end_date, p.contract_value;