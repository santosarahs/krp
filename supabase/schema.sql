-- ============================================================
--  KRP Bread Ledger — Supabase schema  (multi-user)
--  Runs alongside the santosfamilyhealth tables in the SAME project.
--  Paste into SQL Editor -> New query -> Run. Safe to re-run.
--
--  Roles:
--    admin   - everything, incl. Settings and the Users list
--    member  - add / edit routes and supplies
--    viewer  - read only
--  The FIRST person to sign in is made admin automatically. After that,
--  only admins can add or change members.
-- ============================================================

create extension if not exists "pgcrypto";

-- If you ran the earlier single-user schema, this drops that empty table.
drop table if exists public.krp_docs cascade;

-- ---------- who has access ----------
create table if not exists public.krp_members (
  id          uuid primary key default gen_random_uuid(),
  email       text not null unique,
  role        text not null default 'member' check (role in ('admin','member','viewer')),
  invited_by  uuid,
  created_at  timestamptz not null default now()
);
create unique index if not exists krp_members_email_lower on public.krp_members (lower(email));
alter table public.krp_members enable row level security;

-- current signed-in user's role (SECURITY DEFINER: bypasses RLS, avoids recursion)
create or replace function public.krp_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.krp_members
  where lower(email) = lower(auth.jwt() ->> 'email')
  limit 1
$$;

-- Called by the app right after sign-in. Claims admin if the list is empty,
-- otherwise just returns the caller's role (or null if not a member).
create or replace function public.krp_bootstrap_admin()
returns text language plpgsql security definer set search_path = public as $$
declare em text := lower(auth.jwt() ->> 'email');
begin
  if em is null then return null; end if;
  if exists (select 1 from public.krp_members) then
    return (select role from public.krp_members where lower(email) = em limit 1);
  end if;
  insert into public.krp_members (email, role, invited_by) values (em, 'admin', auth.uid());
  return 'admin';
end $$;

-- ---------- the ledger (shared by all members) ----------
create table public.krp_docs (
  path        text primary key,          -- 'settings/config' | 'days/2026-09-02' | 'supplies/2026-09'
  data        jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  updated_by  uuid
);
alter table public.krp_docs enable row level security;

-- ---------- policies: krp_members ----------
drop policy if exists krp_members_read  on public.krp_members;
drop policy if exists krp_members_write on public.krp_members;

create policy krp_members_read on public.krp_members
  for select to authenticated
  using (public.krp_role() is not null);

create policy krp_members_write on public.krp_members
  for all to authenticated
  using (public.krp_role() = 'admin')
  with check (public.krp_role() = 'admin');

-- ---------- policies: krp_docs ----------
drop policy if exists krp_docs_select on public.krp_docs;
drop policy if exists krp_docs_insert on public.krp_docs;
drop policy if exists krp_docs_update on public.krp_docs;
drop policy if exists krp_docs_delete on public.krp_docs;

-- any member can read the whole ledger
create policy krp_docs_select on public.krp_docs
  for select to authenticated
  using (public.krp_role() in ('admin','member','viewer'));

-- members + admins can write; only admins may touch settings/config
create policy krp_docs_insert on public.krp_docs
  for insert to authenticated
  with check (
    public.krp_role() = 'admin'
    or (public.krp_role() = 'member' and path <> 'settings/config')
  );
create policy krp_docs_update on public.krp_docs
  for update to authenticated
  using (public.krp_role() in ('admin','member'))
  with check (
    public.krp_role() = 'admin'
    or (public.krp_role() = 'member' and path <> 'settings/config')
  );
create policy krp_docs_delete on public.krp_docs
  for delete to authenticated
  using (
    public.krp_role() = 'admin'
    or (public.krp_role() = 'member' and path <> 'settings/config')
  );

-- ---------- grants (no anonymous access) ----------
revoke all on public.krp_members from anon;
revoke all on public.krp_docs    from anon;
grant select, insert, update, delete on public.krp_members to authenticated;
grant select, insert, update, delete on public.krp_docs    to authenticated;
grant execute on function public.krp_role()             to authenticated;
grant execute on function public.krp_bootstrap_admin()  to authenticated;

notify pgrst, 'reload schema';

-- ---------- after running ----------
-- 1. Authentication -> URL Configuration: Site URL = your KRP site,
--    Redirect URLs += https://<your-krp-site>/**   (magic links bounce otherwise)
-- 2. Authentication -> Providers -> Email: keep "Allow new users to sign up"
--    ON so people you invite can sign in the first time.
-- 3. Open the site and sign in — you become admin. Invite the rest from Users.
