-- ============================================================
-- MIGRATION TEMPLATE — Gas Pipeline ERP
-- Copy this template for every new table migration.
-- Replace all <PLACEHOLDERS> before running.
-- ============================================================

-- ------------------------------------------------------------
-- 1. TABLE
-- ------------------------------------------------------------
create table if not exists public.<table_name> (
  -- Standard PK (AD-001)
  id                bigint generated always as identity primary key,

  -- Domain columns go here
  -- <column_name>  <type> not null,

  -- Foreign keys (always index these — AD-013)
  -- <fk_column>    bigint not null references public.<ref_table>(id),

  -- Standard audit columns (AD-003, DB-005)
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid references auth.users(id),
  updated_by        uuid references auth.users(id),
  deleted_at        timestamptz,                        -- soft delete (AD-002)
  is_active         boolean not null default true
);

-- ------------------------------------------------------------
-- 2. INDEXES
-- ------------------------------------------------------------

-- Always index FK columns (AD-013)
-- create index <table>_<fk_col>_idx on public.<table_name>(<fk_column>);

-- Partial index for soft-delete filter (AD-015) — use on high-traffic tables
-- create index <table>_active_idx on public.<table_name>(id)
--   where deleted_at is null;

-- Composite index for common query patterns (AD-014 — equality cols first)
-- create index <table>_<col1>_<col2>_idx on public.<table_name>(<equality_col>, <range_col>);

-- ------------------------------------------------------------
-- 3. UPDATED_AT TRIGGER
-- ------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$ begin
  if not exists (
    select 1 from pg_trigger
    where tgname = '<table_name>_set_updated_at'
  ) then
    create trigger <table_name>_set_updated_at
      before update on public.<table_name>
      for each row execute function public.set_updated_at();
  end if;
end $$;

-- ------------------------------------------------------------
-- 4. ROW LEVEL SECURITY (DB-008 — no exceptions)
-- ------------------------------------------------------------
alter table public.<table_name> enable row level security;
alter table public.<table_name> force row level security;

-- Always wrap auth.uid() in a subquery (AD-007 — 100x faster)

-- Admin: full access
create policy "<table_name>_admin_all" on public.<table_name>
  for all
  to authenticated
  using (
    (select auth.jwt()->'app_metadata'->>'role') = 'admin'
  );

-- Example: owner read
-- create policy "<table_name>_owner_read" on public.<table_name>
--   for select
--   to authenticated
--   using (
--     (select auth.jwt()->'app_metadata'->>'role') in ('admin', 'owner')
--   );

-- Tailor remaining policies per permissions-matrix.md

-- ------------------------------------------------------------
-- 5. AUDIT LOG TRIGGER (DB-007, AUD-001–003)
-- ------------------------------------------------------------
-- Only add to tables marked "critical" in DB-007.
-- create trigger <table_name>_audit
--   after insert or update or delete on public.<table_name>
--   for each row execute function public.log_audit_event();

-- ------------------------------------------------------------
-- 6. GRANTS (expose to Data API if needed)
-- ------------------------------------------------------------
-- grant select on public.<table_name> to authenticated;
-- grant insert, update on public.<table_name> to authenticated;
