# RLS Policy Patterns

> Reference for agents writing RLS policies. Always follow AD-006, AD-007, AD-008.
> Copy the correct pattern; substitute `<table_name>` and role conditions.

---

## Key Rules (must follow every time)

1. **Enable AND force RLS on every table** — both statements required
2. **Wrap `auth.uid()` in a subquery** — `(select auth.uid())` not `auth.uid()`
3. **Read role from `app_metadata`** — never `user_metadata`
4. **Index the column used in the USING clause** (usually `user_id`, `project_id`)
5. **UPDATE policies need a SELECT policy too** — without it, updates return 0 rows silently

---

## Role Helper (use in policies)

```sql
-- Get current user's role (from app_metadata — server-set, safe for auth)
(select auth.jwt()->'app_metadata'->>'role')

-- Get current user's ID (cached — one call per query not per row)
(select auth.uid())
```

---

## Pattern 1 — Admin Full Access

```sql
create policy "<table>_admin_all" on public.<table_name>
  for all
  to authenticated
  using (
    (select auth.jwt()->'app_metadata'->>'role') = 'admin'
  )
  with check (
    (select auth.jwt()->'app_metadata'->>'role') = 'admin'
  );
```

---

## Pattern 2 — Multi-Role Read Access

```sql
create policy "<table>_read" on public.<table_name>
  for select
  to authenticated
  using (
    (select auth.jwt()->'app_metadata'->>'role') in ('admin', 'owner', 'engineer')
  );
```

---

## Pattern 3 — Own Rows Only (user-scoped)

```sql
create policy "<table>_own_rows" on public.<table_name>
  for all
  to authenticated
  using (
    user_id = (select auth.uid())
  )
  with check (
    user_id = (select auth.uid())
  );
```

---

## Pattern 4 — Project-Scoped Access

```sql
-- User can access rows for projects they're assigned to
create policy "<table>_project_member" on public.<table_name>
  for select
  to authenticated
  using (
    project_id in (
      select project_id from public.user_roles
      where user_id = (select auth.uid())
        and deleted_at is null
    )
  );
```

---

## Pattern 5 — Owner Approve Only

```sql
create policy "<table>_owner_approve" on public.<table_name>
  for update
  to authenticated
  using (
    (select auth.jwt()->'app_metadata'->>'role') in ('admin', 'owner')
  )
  with check (
    (select auth.jwt()->'app_metadata'->>'role') in ('admin', 'owner')
  );
```

---

## Pattern 6 — Store Can Insert/Update, Not Delete

```sql
create policy "<table>_store_write" on public.<table_name>
  for insert
  to authenticated
  with check (
    (select auth.jwt()->'app_metadata'->>'role') in ('admin', 'store')
  );

create policy "<table>_store_update" on public.<table_name>
  for update
  to authenticated
  using (
    (select auth.jwt()->'app_metadata'->>'role') in ('admin', 'store')
  )
  with check (
    (select auth.jwt()->'app_metadata'->>'role') in ('admin', 'store')
  );
-- No delete policy = no deletes (use soft delete instead)
```

---

## Pattern 7 — Immutable Records (audit logs, approval logs)

```sql
-- Read only for admin
create policy "<table>_admin_read" on public.<table_name>
  for select
  to authenticated
  using (
    (select auth.jwt()->'app_metadata'->>'role') = 'admin'
  );

-- No INSERT/UPDATE/DELETE policies — only SECURITY DEFINER functions can write
```

---

## Full Table Example — material_requests

```sql
alter table public.material_requests enable row level security;
alter table public.material_requests force row level security;

-- Admin: everything
create policy "mr_admin_all" on public.material_requests
  for all to authenticated
  using ((select auth.jwt()->'app_metadata'->>'role') = 'admin');

-- Owner: read all
create policy "mr_owner_read" on public.material_requests
  for select to authenticated
  using ((select auth.jwt()->'app_metadata'->>'role') in ('admin','owner'));

-- Owner: approve (update status only)
create policy "mr_owner_approve" on public.material_requests
  for update to authenticated
  using ((select auth.jwt()->'app_metadata'->>'role') in ('admin','owner'))
  with check ((select auth.jwt()->'app_metadata'->>'role') in ('admin','owner'));

-- Engineer: create and edit own drafts on assigned projects
create policy "mr_engineer_insert" on public.material_requests
  for insert to authenticated
  with check (
    (select auth.jwt()->'app_metadata'->>'role') = 'engineer'
    and project_id in (
      select project_id from public.user_roles
      where user_id = (select auth.uid()) and deleted_at is null
    )
  );

create policy "mr_engineer_update_draft" on public.material_requests
  for update to authenticated
  using (
    (select auth.jwt()->'app_metadata'->>'role') = 'engineer'
    and created_by = (select auth.uid())
    and status = 'draft'
  )
  with check (
    (select auth.jwt()->'app_metadata'->>'role') = 'engineer'
    and status in ('draft','submitted')
  );

-- Store and Purchase: read MRs for assigned projects
create policy "mr_store_purchase_read" on public.material_requests
  for select to authenticated
  using (
    (select auth.jwt()->'app_metadata'->>'role') in ('store','purchase')
    and project_id in (
      select project_id from public.user_roles
      where user_id = (select auth.uid()) and deleted_at is null
    )
  );
```

---

## Performance: Security Definer for Complex Checks

```sql
-- For expensive membership checks used in many policies
create or replace function public.user_has_project_access(p_project_id bigint)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = (select auth.uid())
      and (project_id = p_project_id or project_id is null)
      and deleted_at is null
  );
$$;

-- Use in policy (evaluated once, not per row)
create policy "<table>_project_access" on public.<table_name>
  for select to authenticated
  using ((select public.user_has_project_access(project_id)));
```
