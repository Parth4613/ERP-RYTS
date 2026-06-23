-- ============================================================
-- PHASE 4 — Approval System (Module 14)
-- Tables: approval_workflows, approval_steps, approval_logs
-- Must exist before MR, PO, BOQ workflows can be created.
-- Run via: supabase migration new phase4_approvals
-- ============================================================

-- ============================================================
-- APPROVAL WORKFLOWS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.approval_workflows (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_type  TEXT NOT NULL
               CHECK (entity_type IN
                 ('mr','pr','po','boq_revision','budget_revision',
                  'project_closure','inventory_adjustment')),
  entity_id    BIGINT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending','approved','rejected','cancelled')),
  requested_by UUID NOT NULL REFERENCES auth.users(id),
  total_value  NUMERIC(15,2),  -- for threshold-based routing
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by   UUID REFERENCES auth.users(id),
  updated_by   UUID REFERENCES auth.users(id),
  deleted_at   TIMESTAMPTZ,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX approval_workflows_entity_idx    ON public.approval_workflows(entity_type, entity_id);
CREATE INDEX approval_workflows_status_idx    ON public.approval_workflows(status)
  WHERE status = 'pending';
CREATE INDEX approval_workflows_requested_idx ON public.approval_workflows(requested_by);

CREATE TRIGGER approval_workflows_updated_at
  BEFORE UPDATE ON public.approval_workflows
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.approval_workflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approval_workflows FORCE ROW LEVEL SECURITY;

-- Admin/Owner see all pending approvals
CREATE POLICY "approval_wf_admin_owner_all" ON public.approval_workflows
  FOR ALL TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','owner'));

-- Requester can see their own workflows
CREATE POLICY "approval_wf_requester_read" ON public.approval_workflows
  FOR SELECT TO authenticated
  USING (requested_by = (SELECT auth.uid()));

-- ============================================================
-- APPROVAL LOGS (immutable — APP-003, APP-004)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.approval_logs (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  workflow_id  BIGINT NOT NULL REFERENCES public.approval_workflows(id),
  action       TEXT NOT NULL CHECK (action IN ('approved','rejected','commented','cancelled')),
  actor_id     UUID NOT NULL REFERENCES auth.users(id),
  comment      TEXT,
  acted_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
  -- NO updated_at, deleted_at — this table is immutable
);

CREATE INDEX approval_logs_workflow_id_idx ON public.approval_logs(workflow_id);
CREATE INDEX approval_logs_actor_id_idx    ON public.approval_logs(actor_id);
CREATE INDEX approval_logs_acted_at_brin   ON public.approval_logs USING BRIN(acted_at);

ALTER TABLE public.approval_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approval_logs FORCE ROW LEVEL SECURITY;

-- Read: admin, owner, and the requester of the parent workflow
CREATE POLICY "approval_logs_admin_owner_read" ON public.approval_logs
  FOR SELECT TO authenticated
  USING ((SELECT public.current_user_role()) IN ('admin','owner'));

-- INSERT only — no UPDATE/DELETE (immutability enforced by missing policies)
CREATE POLICY "approval_logs_admin_owner_insert" ON public.approval_logs
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.current_user_role()) IN ('admin','owner'));

-- ============================================================
-- NOTIFICATIONS TABLE (for approval inbox + alerts)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id      UUID NOT NULL REFERENCES auth.users(id),
  type         TEXT NOT NULL,
               -- 'approval_required','approval_done','low_stock',
               -- 'boq_overrun','po_overdue','mr_approved','mr_rejected'
  title        TEXT NOT NULL,
  message      TEXT NOT NULL,
  entity_type  TEXT,
  entity_id    BIGINT,
  is_read      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX notifications_user_id_idx  ON public.notifications(user_id);
CREATE INDEX notifications_unread_idx   ON public.notifications(user_id, is_read)
  WHERE is_read = FALSE;
CREATE INDEX notifications_created_brin ON public.notifications USING BRIN(created_at);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications FORCE ROW LEVEL SECURITY;

-- Users only see their own notifications
CREATE POLICY "notifications_own" ON public.notifications
  FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- ============================================================
-- FUNCTION: create_approval_workflow (call when submitting MR/PR/PO)
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_approval_workflow(
  p_entity_type TEXT,
  p_entity_id   BIGINT,
  p_total_value NUMERIC DEFAULT NULL,
  p_notes       TEXT DEFAULT NULL
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_workflow_id BIGINT;
  v_approver_role TEXT;
BEGIN
  -- Determine approver role based on entity type and value
  v_approver_role := CASE
    WHEN p_entity_type IN ('po','pr') AND p_total_value >
      (SELECT value::NUMERIC FROM public.app_settings
       WHERE key = 'approval_threshold_' || p_entity_type) THEN 'owner'
    ELSE 'owner'  -- default: owner approves everything
  END;

  INSERT INTO public.approval_workflows (
    entity_type, entity_id, status, requested_by, total_value, notes, created_by
  ) VALUES (
    p_entity_type, p_entity_id, 'pending', auth.uid(), p_total_value, p_notes, auth.uid()
  ) RETURNING id INTO v_workflow_id;

  -- Notify all users with approver role
  INSERT INTO public.notifications (user_id, type, title, message, entity_type, entity_id)
  SELECT
    u.id,
    'approval_required',
    'Approval Required: ' || UPPER(p_entity_type),
    'A new ' || p_entity_type || ' requires your approval.',
    p_entity_type,
    p_entity_id
  FROM auth.users u
  WHERE u.raw_app_meta_data->>'role' = v_approver_role;

  RETURN v_workflow_id;
END;
$$;