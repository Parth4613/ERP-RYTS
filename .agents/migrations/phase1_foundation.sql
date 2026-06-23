PHASE 1 — Foundation
-- Tables: audit_logs, app_settings, users, roles, user_roles, permissions
-- Run via: supabase migration new phase1_foundation
-- Then paste this content into the generated file.
-- ============================================================

-- ============================================================
-- SHARED TRIGGER FUNCTIONS (used by all tables)
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_audit_event()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.audit_logs(table_name, record_id, action, old_data, new_data, changed_by)
  VALUES (
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    TG_OP,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE TO_JSONB(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE TO_JSONB(NEW) END,
    auth.uid()
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- ============================================================
-- AUDIT LOGS (must be created before any other table)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  table_name  TEXT NOT NULL,
  record_id   BIGINT,
  action      TEXT NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE')),
  old_data    JSONB,
  new_data    JSONB,
  changed_by  UUID REFERENCES auth.users(id),
  changed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- BRIN index (ideal for append-only time-series data — 100x smaller than B-tree)
CREATE INDEX IF NOT EXISTS audit_logs_changed_at_brin
  ON public.audit_logs USING BRIN(changed_at);
CREATE INDEX IF NOT EXISTS audit_logs_table_record_idx
  ON public.audit_logs(table_name, record_id);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs FORCE ROW LEVEL SECURITY;

-- Only admin can read. Only trigger function (SECURITY DEFINER) can write.
CREATE POLICY "audit_logs_admin_read" ON public.audit_logs
  FOR SELECT TO authenticated
  USING ((SELECT auth.jwt()->'app_metadata'->>'role') = 'admin');

-- ============================================================
-- APP SETTINGS (configurable thresholds, etc.)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_settings (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  key         TEXT NOT NULL UNIQUE,
  value       TEXT NOT NULL,
  description TEXT,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by  UUID REFERENCES auth.users(id)
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings FORCE ROW LEVEL SECURITY;

CREATE POLICY "app_settings_read" ON public.app_settings
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "app_settings_admin_write" ON public.app_settings
  FOR ALL TO authenticated
  USING ((SELECT auth.jwt()->'app_metadata'->>'role') = 'admin');

-- Default settings
INSERT INTO public.app_settings (key, value, description) VALUES
  ('approval_threshold_pr', '50000',  'PR value above this requires Owner approval (₹)'),
  ('approval_threshold_po', '100000', 'PO value above this requires Owner approval (₹)'),
  ('low_stock_alert_days',  '7',      'Alert when stock runs out in X days at current rate'),
  ('wastage_alert_pct',     '5',      'Alert when wastage exceeds X% of issued quantity')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- USER PROFILES (extends auth.users)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.users (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT NOT NULL,
  avatar_url  TEXT,
  phone       TEXT,
  employee_id TEXT,
  designation TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by  UUID REFERENCES auth.users(id),
  updated_by  UUID REFERENCES auth.users(id),
  deleted_at  TIMESTAMPTZ,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TRIGGER users_set_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users FORCE ROW LEVEL SECURITY;

CREATE POLICY "users_own_read" ON public.users
  FOR SELECT TO authenticated
  USING (id = (SELECT auth.uid()));

CREATE POLICY "users_own_update" ON public.users
  FOR UPDATE TO authenticated
  USING (id = (SELECT auth.uid()))
  WITH CHECK (id = (SELECT auth.uid()));

CREATE POLICY "users_admin_all" ON public.users
  FOR ALL TO authenticated
  USING ((SELECT auth.jwt()->'app_metadata'->>'role') = 'admin');

-- All authenticated users can read basic profile info
CREATE POLICY "users_authenticated_read" ON public.users
  FOR SELECT TO authenticated
  USING (deleted_at IS NULL);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.users(id, full_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', SPLIT_PART(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.roles (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by  UUID REFERENCES auth.users(id),
  updated_by  UUID REFERENCES auth.users(id),
  deleted_at  TIMESTAMPTZ,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TRIGGER roles_set_updated_at
  BEFORE UPDATE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles FORCE ROW LEVEL SECURITY;

CREATE POLICY "roles_read" ON public.roles
  FOR SELECT TO authenticated USING (deleted_at IS NULL);
CREATE POLICY "roles_admin_write" ON public.roles
  FOR ALL TO authenticated
  USING ((SELECT auth.jwt()->'app_metadata'->>'role') = 'admin');

INSERT INTO public.roles(name, description) VALUES
  ('admin',    'Full system access + user management'),
  ('owner',    'Approve all transactions, view all data, financial reports'),
  ('engineer', 'Create material requests, record site consumption, daily progress'),
  ('store',    'Inventory management, material issuance, MRN creation'),
  ('purchase', 'Purchase requisitions, purchase orders, supplier management')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- USER ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.user_roles (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role_id     BIGINT NOT NULL REFERENCES public.roles(id),
  project_id  BIGINT,  -- NULL = global role; set for project-scoped assignments
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by  UUID REFERENCES auth.users(id),
  updated_by  UUID REFERENCES auth.users(id),
  deleted_at  TIMESTAMPTZ,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE(user_id, role_id, project_id)
);

CREATE INDEX user_roles_user_id_idx    ON public.user_roles(user_id);
CREATE INDEX user_roles_role_id_idx    ON public.user_roles(role_id);
CREATE INDEX user_roles_project_id_idx ON public.user_roles(project_id);

-- Partial index for active roles only
CREATE INDEX user_roles_active_idx     ON public.user_roles(user_id, role_id)
  WHERE deleted_at IS NULL AND is_active = TRUE;

CREATE TRIGGER user_roles_set_updated_at
  BEFORE UPDATE ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER user_roles_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles FORCE ROW LEVEL SECURITY;

CREATE POLICY "user_roles_admin_all" ON public.user_roles
  FOR ALL TO authenticated
  USING ((SELECT auth.jwt()->'app_metadata'->>'role') = 'admin');
CREATE POLICY "user_roles_own_read" ON public.user_roles
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- ============================================================
-- PERMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.permissions (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  module      TEXT NOT NULL,
  action      TEXT NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ,
  UNIQUE(module, action)
);

ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions FORCE ROW LEVEL SECURITY;

CREATE POLICY "permissions_read" ON public.permissions
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "permissions_admin" ON public.permissions
  FOR ALL TO authenticated
  USING ((SELECT auth.jwt()->'app_metadata'->>'role') = 'admin');

-- ============================================================
-- HELPER FUNCTIONS (used in future RLS policies)
-- ============================================================

-- Get current user's role (call once, cached per query)
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT COALESCE(auth.jwt()->'app_metadata'->>'role', 'anonymous');
$$;

-- Check if user has access to a project
CREATE OR REPLACE FUNCTION public.user_has_project_access(p_project_id BIGINT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = (SELECT auth.uid())
      AND (project_id = p_project_id OR project_id IS NULL)
      AND deleted_at IS NULL
      AND is_active = TRUE
  );
$$;

-- Check if user is admin or owner
CREATE OR REPLACE FUNCTION public.is_admin_or_owner()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT (SELECT auth.jwt()->'app_metadata'->>'role') IN ('admin', 'owner');
$$;

-- Document number sequences
CREATE SEQUENCE IF NOT EXISTS seq_project_number START 1;
CREATE SEQUENCE IF NOT EXISTS seq_mr_number      START 1;
CREATE SEQUENCE IF NOT EXISTS seq_is_number      START 1;
CREATE SEQUENCE IF NOT EXISTS seq_pr_number      START 1;
CREATE SEQUENCE IF NOT EXISTS seq_po_number      START 1;
CREATE SEQUENCE IF NOT EXISTS seq_mrn_number     START 1;
CREATE SEQUENCE IF NOT EXISTS seq_sup_number     START 1;

CREATE OR REPLACE FUNCTION public.generate_doc_number(p_prefix TEXT, p_seq TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE v_seq BIGINT;
BEGIN
  EXECUTE FORMAT('SELECT nextval(%L)', p_seq) INTO v_seq;
  RETURN p_prefix || '-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(v_seq::TEXT, 4, '0');
END;
$$;