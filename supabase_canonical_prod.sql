-- ============================================================
-- Canonical Production Backend Consolidation (Flutter + Supabase)
-- Construction Inventory & Procurement ERP Workflow
-- ============================================================
-- Goals:
--  - NO client role injection (never trust raw_user_meta_data / requested_role)
--  - Canonical RLS using `private.get_user_role()` to avoid recursion
--  - Minimal safe public profile view for joins/UI display
--  - ALL inventory mutations via transactional RPCs only
--  - Explicit combined PR creation (never auto-create PR silently)
--  - Standardized statuses + editing rules enforced in RLS + RPCs
--  - Security-invoker views for reporting
--
-- Apply in a SQL editor on Supabase (recommended in a migration).
-- ============================================================

-- ---------- 0) PRIVATE HELPERS (RLS SAFE) ----------

create schema if not exists private;

-- Read role from `profiles` (authoritative for app).
-- SECURITY DEFINER avoids RLS recursion when policies call it.
create or replace function private.get_user_role()
returns text
language sql
security definer
set search_path = ''
stable
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function private.is_admin()
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select private.get_user_role() = 'admin';
$$;

-- ---------- 1) PROFILES: ROLE SECURITY + PUBLIC VIEW ----------

-- Base table (if not already created).
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null,
  role text not null check (role in ('admin', 'engineer', 'store', 'purchase', 'pending')),
  department text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure columns exist even if `profiles` table already existed.
alter table public.profiles
  add column if not exists department text,
  add column if not exists avatar_url text;

alter table public.profiles enable row level security;

-- Drop risky / recursive policies (safe to re-run).
drop policy if exists "Admin can view all profiles" on public.profiles;
drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Users can insert own profile" on public.profiles;
drop policy if exists "Admin can update all profiles" on public.profiles;
drop policy if exists "Authenticated users can view profiles for workflow joins" on public.profiles;
-- Ensure idempotency for our policy names as well
drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own_safe_fields" on public.profiles;
drop policy if exists "profiles_admin_select_all" on public.profiles;
drop policy if exists "profiles_admin_update_all" on public.profiles;

-- Minimal direct access:
-- - user can select their own row (needed to route dashboards)
create policy "profiles_select_own"
on public.profiles
for select
using (auth.uid() = id);

-- - user can insert their own profile (trigger also inserts; keep for safety)
create policy "profiles_insert_own"
on public.profiles
for insert
with check (auth.uid() = id);

-- - user can update their own display fields (NOT role/email)
create policy "profiles_update_own_safe_fields"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- - admin can select/update any profile (through helper to avoid recursion)
create policy "profiles_admin_select_all"
on public.profiles
for select
using (private.is_admin());

create policy "profiles_admin_update_all"
on public.profiles
for update
using (private.is_admin());

-- Safe public view for workflow joins & UI display.
-- Exposes: id, full_name, department, avatar_url only.
drop view if exists public.profile_public_view cascade;
create view public.profile_public_view
with (security_invoker = true)
as
select
  id,
  name as full_name,
  department,
  avatar_url
from public.profiles;

grant select on public.profile_public_view to authenticated;

-- Invoker-safe MR view for dashboards (avoids direct `profiles` access).
drop view if exists public.material_requests_with_details cascade;
create view public.material_requests_with_details
with (security_invoker = true) as
select
  mr.*,
  p.name as project_name,
  eng.full_name as engineer_name,
  eng.department as engineer_department,
  eng.avatar_url as engineer_avatar_url
from public.material_requests mr
join public.projects p on p.id = mr.project_id
left join public.profile_public_view eng on eng.id = mr.engineer_id;

grant select on public.material_requests_with_details to authenticated;

-- ---------- 2) SIGNUP TRIGGER: NEVER TRUST CLIENT ROLE ----------

-- IMPORTANT: default new users to 'pending' (or 'engineer' if you prefer).
-- Role elevation must be done via admin workflow only.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := coalesce(new.raw_user_meta_data->>'name', 'New User');
  v_email text := coalesce(new.email, new.raw_user_meta_data->>'email', '');
begin
  -- Ensure private logging table exists for diagnostics
  create table if not exists private.user_creation_errors (
    user_id uuid primary key,
    err text,
    payload jsonb,
    created_at timestamptz not null default now()
  );

  -- Defensive insert: coalesce email to empty string to satisfy not-null
  -- and avoid raising during auth.user creation. Log any unexpected errors.
  begin
    insert into public.profiles (id, name, email, role)
    values (
      new.id,
      v_name,
      v_email,
      'pending'
    )
    on conflict (id) do update
    set
      name = excluded.name,
      email = excluded.email,
      updated_at = now();
  exception when others then
    insert into private.user_creation_errors (user_id, err, payload)
    values (new.id, sqlerrm, row_to_json(new.*)::jsonb)
    on conflict (user_id) do update set err = excluded.err, payload = excluded.payload, created_at = now();
  end;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Admin-only role change RPC (explicit).
create or replace function public.admin_set_user_role(
  p_user_id uuid,
  p_new_role text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_admin() then
    raise exception 'Only admin can change roles';
  end if;

  if p_new_role not in ('admin', 'engineer', 'store', 'purchase', 'pending') then
    raise exception 'Invalid role %', p_new_role;
  end if;

  update public.profiles
  set role = p_new_role, updated_at = now()
  where id = p_user_id;

  return jsonb_build_object('success', true, 'user_id', p_user_id, 'role', p_new_role);
end;
$$;

grant execute on function public.admin_set_user_role(uuid, text) to authenticated;

-- ---------- 3) STATUS STANDARDIZATION ----------

-- Material Requests: canonical statuses (approval tracked separately via reserve step)
alter table public.material_requests
  add column if not exists approved_at timestamptz,
  add column if not exists approved_by uuid references public.profiles(id);

alter table public.material_requests
  drop constraint if exists material_requests_status_check;

-- Backup and normalize any existing non-conforming statuses to avoid
-- constraint violations when the new check constraint is added.
create schema if not exists private;

create table if not exists private.material_requests_status_backup (
  mr_id uuid primary key,
  old_status text
);

insert into private.material_requests_status_backup (mr_id, old_status)
select id, status from public.material_requests
where status not in (
  'pending',
  'waiting_procurement',
  'partially_issued',
  'fully_issued',
  'completed',
  'rejected'
);

update public.material_requests
set status = 'pending'
where status not in (
  'pending',
  'waiting_procurement',
  'partially_issued',
  'fully_issued',
  'completed',
  'rejected'
);

alter table public.material_requests
  add constraint material_requests_status_check
  check (status in (
    'pending',
    'waiting_procurement',
    'partially_issued',
    'fully_issued',
    'completed',
    'rejected'
  ));

-- Purchase Requests
alter table public.purchase_requests
  drop constraint if exists purchase_requests_status_check;

alter table public.purchase_requests
  add constraint purchase_requests_status_check
  check (status in (
    'draft',
    'pending',
    'approved',
    'ordered',
    'delivered',
    'cancelled'
  ));

-- Purchase Orders (expanded workflow)
alter table public.purchase_orders
  drop constraint if exists purchase_orders_status_check;

alter table public.purchase_orders
  add constraint purchase_orders_status_check
  check (status in (
    'draft',
    'approved',
    'sent',
    'partially_received',
    'completed'
  ));

-- ---------- 4) INVENTORY INTEGRITY (NON-NEGOTIABLE) ----------

-- Reservation layer
alter table public.inventory
  add column if not exists quantity_reserved integer not null default 0;

alter table public.inventory
  drop constraint if exists inventory_quantity_available_non_negative;
alter table public.inventory
  add constraint inventory_quantity_available_non_negative check (quantity_available >= 0);

alter table public.inventory
  drop constraint if exists inventory_quantity_reserved_non_negative;
alter table public.inventory
  add constraint inventory_quantity_reserved_non_negative check (quantity_reserved >= 0);

alter table public.inventory
  drop constraint if exists inventory_reserved_not_over_available;
alter table public.inventory
  add constraint inventory_reserved_not_over_available check (quantity_reserved <= quantity_available);

alter table public.material_request_items
  add column if not exists quantity_reserved integer not null default 0;

alter table public.material_request_items
  drop constraint if exists material_request_items_issued_not_over_requested;
alter table public.material_request_items
  add constraint material_request_items_issued_not_over_requested
  check (quantity_issued >= 0 and quantity_issued <= quantity_requested);

alter table public.material_request_items
  drop constraint if exists material_request_items_reserved_not_over_pending;
alter table public.material_request_items
  add constraint material_request_items_reserved_not_over_pending
  check (
    quantity_reserved >= 0
    and quantity_reserved <= greatest(quantity_requested - quantity_issued, 0)
  );

-- Prevent duplicate PR item inserts when combining.
create unique index if not exists purchase_request_items_pr_product_idx
  on public.purchase_request_items (pr_id, product_id);

-- ---------- 5) PROCUREMENT CYCLE + COMBINED PR (EXPLICIT) ----------

create sequence if not exists public.pr_number_seq start with 1 increment by 1;

alter table public.purchase_requests
  add column if not exists pr_number text unique,
  add column if not exists required_date date,
  add column if not exists source text default 'manual',
  add column if not exists last_modified_by uuid references public.profiles(id),
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by uuid references public.profiles(id);

alter table public.purchase_request_items
  add column if not exists remarks text;

create or replace function public.generate_pr_number()
returns text
language plpgsql
as $$
begin
  return 'PR-' || lpad(nextval('public.pr_number_seq')::text, 4, '0');
end;
$$;

-- Explicit combined PR creation/appending.
-- One active PR per MR (batch) while status in (draft,pending).
create or replace function public.create_combined_pr(
  p_mr_id uuid,
  p_items jsonb,
  p_required_date date default (current_date + 7),
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pr_id uuid;
  v_pr_number text;
  v_project_id uuid;
  v_item jsonb;
  v_product_id uuid;
  v_qty int;
  v_count int := 0;
  v_appended boolean := false;
begin
  if private.get_user_role() not in ('admin','store') then
    raise exception 'Only Store/Admin can create combined PR';
  end if;

  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'At least one item is required';
  end if;

  select project_id into v_project_id from public.material_requests where id = p_mr_id;
  if v_project_id is null then
    raise exception 'MR not found';
  end if;

  perform pg_advisory_xact_lock(hashtext('combined_pr:' || p_mr_id::text));

  select id into v_pr_id
  from public.purchase_requests
  where created_from_mr_id = p_mr_id
    and archived_at is null
    and status in ('draft','pending')
  order by created_at desc
  limit 1
  for update;

  if v_pr_id is not null then
    v_appended := true;
    update public.purchase_requests
    set required_date = coalesce(p_required_date, required_date),
        notes = coalesce(p_notes, notes),
        last_modified_by = auth.uid(),
        updated_at = now()
    where id = v_pr_id;
  else
    v_pr_number := public.generate_pr_number();
    insert into public.purchase_requests (
      created_from_mr_id, project_id, pr_number, required_date,
      status, source, notes, created_by, last_modified_by
    ) values (
      p_mr_id, v_project_id, v_pr_number, p_required_date,
      'pending', 'store_combined',
      coalesce(p_notes, 'Combined PR created by Store'),
      auth.uid(), auth.uid()
    ) returning id into v_pr_id;
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item ->> 'product_id')::uuid;
    v_qty := greatest((v_item ->> 'quantity_needed')::int, 1);

    insert into public.purchase_request_items (pr_id, product_id, quantity_needed, remarks)
    values (v_pr_id, v_product_id, v_qty, v_item ->> 'remarks')
    on conflict (pr_id, product_id)
    do update set
      quantity_needed = greatest(public.purchase_request_items.quantity_needed, excluded.quantity_needed),
      remarks = coalesce(excluded.remarks, public.purchase_request_items.remarks);

    v_count := v_count + 1;
  end loop;

  update public.material_requests
  set status = 'waiting_procurement', updated_at = now()
  where id = p_mr_id and status <> 'rejected';

  return jsonb_build_object(
    'success', true,
    'purchase_request_id', v_pr_id,
    'pr_number', (select pr_number from public.purchase_requests where id = v_pr_id),
    'items_count', v_count,
    'required_date', p_required_date,
    'is_appended', v_appended
  );
end;
$$;

grant execute on function public.generate_pr_number() to authenticated;
grant execute on function public.create_combined_pr(uuid, jsonb, date, text) to authenticated;

-- ---------- 6) MR APPROVAL / RESERVATION (TRANSACTIONAL) ----------

create or replace function public.approve_material_request_safe(p_mr_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_mr public.material_requests%rowtype;
  v_item record;
  v_inv public.inventory%rowtype;
  v_pending int;
  v_free int;
  v_reserve int;
  v_total_reserved int := 0;
begin
  if private.get_user_role() not in ('admin','store') then
    raise exception 'Only Store/Admin can approve MR';
  end if;

  select * into v_mr from public.material_requests where id = p_mr_id for update;
  if not found then raise exception 'MR not found'; end if;
  if v_mr.status <> 'pending' then
    raise exception 'MR must be pending to approve. Current: %', v_mr.status;
  end if;

  for v_item in
    select * from public.material_request_items
    where mr_id = p_mr_id
    order by id
    for update
  loop
    insert into public.inventory (product_id, quantity_available, quantity_reserved)
    values (v_item.product_id, 0, 0)
    on conflict (product_id) do nothing;

    select * into v_inv from public.inventory where product_id = v_item.product_id for update;

    v_pending := greatest(v_item.quantity_requested - v_item.quantity_issued - v_item.quantity_reserved, 0);
    v_free := greatest(v_inv.quantity_available - v_inv.quantity_reserved, 0);
    v_reserve := least(v_pending, v_free);

    if v_reserve > 0 then
      update public.material_request_items
      set quantity_reserved = quantity_reserved + v_reserve, updated_at = now()
      where id = v_item.id;

      update public.inventory
      set quantity_reserved = quantity_reserved + v_reserve, updated_at = now()
      where product_id = v_item.product_id;

      v_total_reserved := v_total_reserved + v_reserve;
    end if;
  end loop;

  update public.material_requests
  set approved_at = now(),
      approved_by = auth.uid(),
      updated_at = now()
  where id = p_mr_id;

  return jsonb_build_object('success', true, 'quantity_reserved', v_total_reserved);
end;
$$;

grant execute on function public.approve_material_request_safe(uuid) to authenticated;

-- ---------- 7) INVENTORY-SAFE ISSUANCE (NO AUTO PR) ----------

create or replace function public.update_mr_status(p_mr_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total int;
  v_fully int;
  v_any_issued int;
  v_any_pending int;
  v_new text;
begin
  select
    count(*),
    count(*) filter (where quantity_issued >= quantity_requested),
    count(*) filter (where quantity_issued > 0),
    count(*) filter (where quantity_issued < quantity_requested)
  into v_total, v_fully, v_any_issued, v_any_pending
  from public.material_request_items
  where mr_id = p_mr_id;

  if v_total = 0 then
    v_new := 'pending';
  elsif v_fully = v_total then
    v_new := 'fully_issued';
  elsif v_any_issued > 0 then
    v_new := 'partially_issued';
  else
    -- still not issued; keep pending or waiting_procurement if already set.
    select status into v_new from public.material_requests where id = p_mr_id;
    if v_new not in ('waiting_procurement','rejected','completed') then
      v_new := 'pending';
    end if;
  end if;

  update public.material_requests
  set status = v_new, updated_at = now()
  where id = p_mr_id and status not in ('rejected','completed');

  return v_new;
end;
$$;

grant execute on function public.update_mr_status(uuid) to authenticated;

create or replace function public.issue_materials_safe(
  p_mr_id uuid,
  p_mr_item_id uuid,
  p_product_id uuid,
  p_quantity_to_issue integer,
  p_notes text default null,
  p_auto_create_pr boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_mr public.material_requests%rowtype;
  v_item public.material_request_items%rowtype;
  v_inv public.inventory%rowtype;
  v_pending int;
  v_available int;
  v_actual int;
  v_release int;
  v_shortage int;
  v_log public.issuance_logs%rowtype;
  v_status text;
begin
  if private.get_user_role() not in ('admin','store') then
    raise exception 'Only Store/Admin can issue materials';
  end if;

  if p_quantity_to_issue <= 0 then
    raise exception 'Issued quantity must be greater than zero';
  end if;

  -- PR auto-create is forbidden in canonical workflow.
  if coalesce(p_auto_create_pr, false) then
    raise exception 'Auto PR creation is not allowed. Create PR explicitly from Store UI.';
  end if;

  select * into v_mr from public.material_requests where id = p_mr_id for update;
  if not found then raise exception 'MR not found'; end if;

  if v_mr.status in ('rejected','completed') then
    raise exception 'Cannot issue for MR in status %', v_mr.status;
  end if;

  if v_mr.approved_at is null then
    raise exception 'Approve the material request before issuing stock';
  end if;

  select * into v_item
  from public.material_request_items
  where id = p_mr_item_id and mr_id = p_mr_id and product_id = p_product_id
  for update;
  if not found then raise exception 'MR item not found'; end if;

  v_pending := v_item.quantity_requested - v_item.quantity_issued;
  if v_pending <= 0 then
    raise exception 'This MR item is already fully issued';
  end if;

  insert into public.inventory (product_id, quantity_available, quantity_reserved)
  values (p_product_id, 0, 0)
  on conflict (product_id) do nothing;

  select * into v_inv from public.inventory where product_id = p_product_id for update;

  -- Available allocatable for this item includes its own reservation.
  v_available := greatest(v_inv.quantity_available - v_inv.quantity_reserved + v_item.quantity_reserved, 0);
  v_actual := least(p_quantity_to_issue, v_pending, v_available);
  v_shortage := greatest(v_pending - v_actual, 0);

  if v_actual <= 0 then
    return jsonb_build_object(
      'success', true,
      'message', 'No stock available to issue',
      'quantity_issued', 0,
      'remaining_quantity', v_pending,
      'shortage_items', jsonb_build_array(p_product_id),
      'material_request_status', (select status from public.material_requests where id = p_mr_id)
    );
  end if;

  v_release := least(v_actual, v_item.quantity_reserved);

  update public.inventory
  set quantity_available = quantity_available - v_actual,
      quantity_reserved = greatest(quantity_reserved - v_release, 0),
      updated_at = now()
  where product_id = p_product_id and quantity_available >= v_actual;
  if not found then
    raise exception 'Insufficient stock. Refresh and retry.';
  end if;

  update public.material_request_items
  set quantity_issued = quantity_issued + v_actual,
      quantity_reserved = greatest(quantity_reserved - v_release, 0),
      updated_at = now()
  where id = p_mr_item_id;

  insert into public.issuance_logs (
    mr_id, mr_item_id, project_id, product_id, quantity_issued, issued_by, notes
  )
  values (
    p_mr_id, p_mr_item_id, v_mr.project_id, p_product_id, v_actual, auth.uid(), p_notes
  )
  returning * into v_log;

  v_status := public.update_mr_status(p_mr_id);

  return jsonb_build_object(
    'success', true,
    'issuance_log', to_jsonb(v_log),
    'quantity_issued', v_actual,
    'remaining_quantity', greatest(v_pending - v_actual, 0),
    'shortage_items', case when v_shortage > 0 then jsonb_build_array(p_product_id) else '[]'::jsonb end,
    'material_request_status', v_status
  );
end;
$$;

grant execute on function public.issue_materials_safe(uuid, uuid, uuid, integer, text, boolean) to authenticated;

-- Processes an MR to optionally issue available stock and returns shortages.
-- Does NOT create PR.
create or replace function public.process_mr_shortages(
  p_mr_id uuid,
  p_auto_issue boolean default false,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_mr public.material_requests%rowtype;
  v_item record;
  v_inv public.inventory%rowtype;
  v_free int;
  v_pending int;
  v_issue int;
  v_shortage int;
  v_shortage_items jsonb := '[]'::jsonb;
  v_issued_items jsonb := '[]'::jsonb;
  v_total_issued int := 0;
  v_total_shortage int := 0;
begin
  if private.get_user_role() not in ('admin','store') then
    raise exception 'Only Store/Admin can process MR shortages';
  end if;

  select * into v_mr from public.material_requests where id = p_mr_id for update;
  if not found then raise exception 'MR not found'; end if;
  if v_mr.approved_at is null then raise exception 'Approve MR before processing shortages'; end if;

  for v_item in
    select mri.*, prod.name as product_name, prod.unit as unit
    from public.material_request_items mri
    join public.products prod on prod.id = mri.product_id
    where mri.mr_id = p_mr_id and mri.quantity_issued < mri.quantity_requested
    order by mri.id
    for update of mri
  loop
    insert into public.inventory (product_id, quantity_available, quantity_reserved)
    values (v_item.product_id, 0, 0)
    on conflict (product_id) do nothing;

    select * into v_inv from public.inventory where product_id = v_item.product_id for update;

    v_pending := v_item.quantity_requested - v_item.quantity_issued;
    v_free := greatest(v_inv.quantity_available - v_inv.quantity_reserved + v_item.quantity_reserved, 0);

    v_issue := case when p_auto_issue then least(v_pending, v_free) else 0 end;
    v_shortage := greatest(v_pending - v_issue, 0);

    if v_issue > 0 then
      perform public.issue_materials_safe(p_mr_id, v_item.id, v_item.product_id, v_issue, p_notes, false);
      v_total_issued := v_total_issued + v_issue;
      v_issued_items := v_issued_items || jsonb_build_object(
        'product_id', v_item.product_id,
        'product_name', v_item.product_name,
        'unit', v_item.unit,
        'quantity_issued', v_issue
      );
    end if;

    if v_shortage > 0 then
      v_total_shortage := v_total_shortage + v_shortage;
      v_shortage_items := v_shortage_items || jsonb_build_object(
        'product_id', v_item.product_id,
        'product_name', v_item.product_name,
        'unit', v_item.unit,
        'quantity_needed', v_shortage
      );
    end if;
  end loop;

  perform public.update_mr_status(p_mr_id);

  return jsonb_build_object(
    'success', true,
    'material_request_id', p_mr_id,
    'total_issued', v_total_issued,
    'total_shortage', v_total_shortage,
    'issued_items', v_issued_items,
    'shortage_items', v_shortage_items
  );
end;
$$;

grant execute on function public.process_mr_shortages(uuid, boolean, text) to authenticated;

-- ---------- 8) PROCUREMENT EDITING RULES (RLS + RPC) ----------

-- RLS policies: avoid profiles recursion by using private.get_user_role().
-- purchase_requests
alter table public.purchase_requests enable row level security;
drop policy if exists "Store/purchase/admin can view PRs" on public.purchase_requests;
-- Ensure idempotency for our policy names
drop policy if exists "pr_select_store_purchase_admin" on public.purchase_requests;
drop policy if exists "pr_insert_store_admin" on public.purchase_requests;
drop policy if exists "pr_update_store_draft_pending" on public.purchase_requests;
drop policy if exists "pr_update_purchase_admin" on public.purchase_requests;
create policy "pr_select_store_purchase_admin"
on public.purchase_requests
for select
using (private.get_user_role() in ('admin','store','purchase'));

drop policy if exists "Store and admin can create PRs" on public.purchase_requests;
create policy "pr_insert_store_admin"
on public.purchase_requests
for insert
with check (private.get_user_role() in ('admin','store'));

-- store can update only draft/pending and not archived
drop policy if exists "Store can update draft/pending PRs" on public.purchase_requests;
create policy "pr_update_store_draft_pending"
on public.purchase_requests
for update
using (private.get_user_role() in ('admin','store') and archived_at is null and status in ('draft','pending'));

-- store soft-delete (archive) only draft/pending
create or replace function public.archive_purchase_request(p_pr_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_status text;
begin
  if private.get_user_role() not in ('admin','store') then
    raise exception 'Only Store/Admin can archive PR';
  end if;

  select status into v_status from public.purchase_requests where id = p_pr_id;
  if not found then raise exception 'PR not found'; end if;
  if v_status not in ('draft','pending') then
    raise exception 'Only draft/pending PRs can be archived';
  end if;

  update public.purchase_requests
  set archived_at = now(),
      archived_by = auth.uid(),
      updated_at = now()
  where id = p_pr_id;

  return jsonb_build_object('success', true, 'archived_pr_id', p_pr_id);
end;
$$;

grant execute on function public.archive_purchase_request(uuid) to authenticated;

-- purchase_request_items
alter table public.purchase_request_items enable row level security;
drop policy if exists "View PR items with PR access" on public.purchase_request_items;
-- Ensure idempotency for our policy names
drop policy if exists "pri_select_store_purchase_admin" on public.purchase_request_items;
drop policy if exists "pri_insert_store_admin" on public.purchase_request_items;
drop policy if exists "pri_update_store_admin_draft_pending" on public.purchase_request_items;
drop policy if exists "pri_delete_store_admin_draft_pending" on public.purchase_request_items;
create policy "pri_select_store_purchase_admin"
on public.purchase_request_items
for select
using (private.get_user_role() in ('admin','store','purchase'));

drop policy if exists "Store can insert PR items" on public.purchase_request_items;
create policy "pri_insert_store_admin"
on public.purchase_request_items
for insert
with check (private.get_user_role() in ('admin','store'));

drop policy if exists "Store can update PR items" on public.purchase_request_items;
create policy "pri_update_store_admin_draft_pending"
on public.purchase_request_items
for update
using (
  private.get_user_role() in ('admin','store')
  and exists (
    select 1
    from public.purchase_requests pr
    where pr.id = public.purchase_request_items.pr_id
      and pr.archived_at is null
      and pr.status in ('draft','pending')
  )
);

drop policy if exists "Store can delete PR items" on public.purchase_request_items;
create policy "pri_delete_store_admin_draft_pending"
on public.purchase_request_items
for delete
using (
  private.get_user_role() in ('admin','store')
  and exists (
    select 1
    from public.purchase_requests pr
    where pr.id = public.purchase_request_items.pr_id
      and pr.archived_at is null
      and pr.status in ('draft','pending')
  )
);

-- Purchase department transitions are enforced via UPDATE policy + RPCs (recommended).
drop policy if exists "Purchase and admin can update PRs" on public.purchase_requests;
create policy "pr_update_purchase_admin"
on public.purchase_requests
for update
using (private.get_user_role() in ('admin','purchase'));

-- ---------- 9) SECURITY INVOKER VIEWS (REPORTING) ----------

-- Purchase requests enriched view (safe aggregator)
drop view if exists public.purchase_requests_with_details cascade;
create view public.purchase_requests_with_details
with (security_invoker = true) as
select
  pr.id,
  pr.pr_number,
  pr.created_from_mr_id as mr_id,
  pr.project_id,
  p.name as project_name,
  pr.required_date,
  pr.status,
  pr.source,
  pr.notes,
  pr.created_by,
  creator.name as created_by_name,
  pr.last_modified_by,
  pr.created_at,
  pr.updated_at,
  (select count(*) from public.purchase_request_items pri where pri.pr_id = pr.id) as items_count,
  (select coalesce(sum(pri.quantity_needed * coalesce(bp.price, 0)), 0)
   from public.purchase_request_items pri
   left join lateral (
     select ps.price from public.product_suppliers ps where ps.product_id = pri.product_id
     order by ps.price asc limit 1
   ) bp on true
   where pri.pr_id = pr.id) as estimated_cost,
  (select jsonb_agg(jsonb_build_object(
     'id', pri.id,
     'product_id', pri.product_id,
     'product_name', prod.name,
     'unit', prod.unit,
     'quantity_needed', pri.quantity_needed,
     'remarks', pri.remarks,
     'unit_price', coalesce(bp.price, 0)
   ) order by prod.name)
   from public.purchase_request_items pri
   join public.products prod on prod.id = pri.product_id
   left join lateral (
     select ps.price from public.product_suppliers ps where ps.product_id = pri.product_id
     order by ps.price asc limit 1
   ) bp on true
   where pri.pr_id = pr.id) as items_detail
from public.purchase_requests pr
left join public.projects p on p.id = pr.project_id
left join public.profiles creator on creator.id = pr.created_by
where pr.archived_at is null
order by pr.created_at desc;

grant select on public.purchase_requests_with_details to authenticated;

-- ---------- 10) GRANTS (DATA API ACCESS) ----------
-- NOTE: GRANTs are separate from RLS. Keep minimal.
grant select on public.profiles to authenticated;
grant select, insert, update on public.material_requests to authenticated;
grant select, insert, update on public.material_request_items to authenticated;
grant select, insert, update on public.inventory to authenticated;
grant select, insert on public.issuance_logs to authenticated;
grant select on public.purchase_requests to authenticated;
grant select, insert, update, delete on public.purchase_request_items to authenticated;

