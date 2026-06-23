-- ============================================================
-- AUDIT LOG INFRASTRUCTURE
-- Run once. Referenced by all table audit triggers.
-- ============================================================

-- Audit log table (AUD-001–003, DB-007)
create table if not exists public.audit_logs (
  id            bigint generated always as identity primary key,
  table_name    text not null,
  record_id     bigint,
  action        text not null check (action in ('INSERT','UPDATE','DELETE')),
  old_data      jsonb,
  new_data      jsonb,
  changed_by    uuid references auth.users(id),
  changed_at    timestamptz not null default now()
);

-- Audit logs are immutable — no update or delete (AUD-002)
alter table public.audit_logs enable row level security;
alter table public.audit_logs force row level security;

create policy "audit_logs_admin_read" on public.audit_logs
  for select
  to authenticated
  using (
    (select auth.jwt()->'app_metadata'->>'role') = 'admin'
  );

-- No INSERT/UPDATE/DELETE policies — only the trigger function can write
-- (trigger runs as SECURITY DEFINER)

-- Index for fast lookup by table + record
create index if not exists audit_logs_table_record_idx
  on public.audit_logs(table_name, record_id);

create index if not exists audit_logs_changed_at_idx
  on public.audit_logs(changed_at desc);

-- ============================================================
-- GENERIC AUDIT TRIGGER FUNCTION
-- Attach to any critical table with:
--   CREATE TRIGGER <table>_audit
--     AFTER INSERT OR UPDATE OR DELETE ON public.<table>
--     FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();
-- ============================================================
create or replace function public.log_audit_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.audit_logs (
    table_name,
    record_id,
    action,
    old_data,
    new_data,
    changed_by
  ) values (
    tg_table_name,
    coalesce(new.id, old.id),
    tg_op,
    case when tg_op = 'INSERT' then null else to_jsonb(old) end,
    case when tg_op = 'DELETE' then null else to_jsonb(new) end,
    auth.uid()
  );
  return coalesce(new, old);
end;
$$;
