-- ============================================================
--  KRP Bread Ledger — Supabase schema
--  Runs alongside the santosfamilyhealth tables in the SAME project.
--  Paste into SQL Editor -> New query -> Run. Safe to re-run.
-- ============================================================

-- One row per stored document. The app keeps everything as JSON docs:
--   settings/config            -> products, prices, tray sizes, carts, commission
--   days/2026-09-02            -> that day's routes (trips array)
--   supplies/2026-09           -> that month's supply purchases (items array)
create table if not exists public.krp_docs (
  owner       uuid        not null default auth.uid(),
  path        text        not null,
  data        jsonb       not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  primary key (owner, path)
);

alter table public.krp_docs enable row level security;

-- Each signed-in account sees and edits only its own rows.
drop policy if exists krp_docs_select on public.krp_docs;
drop policy if exists krp_docs_insert on public.krp_docs;
drop policy if exists krp_docs_update on public.krp_docs;
drop policy if exists krp_docs_delete on public.krp_docs;

create policy krp_docs_select on public.krp_docs
  for select using (owner = auth.uid());
create policy krp_docs_insert on public.krp_docs
  for insert with check (owner = auth.uid());
create policy krp_docs_update on public.krp_docs
  for update using (owner = auth.uid()) with check (owner = auth.uid());
create policy krp_docs_delete on public.krp_docs
  for delete using (owner = auth.uid());

-- Only authenticated users touch this table at all (no anonymous access).
revoke all on public.krp_docs from anon;
grant select, insert, update, delete on public.krp_docs to authenticated;

notify pgrst, 'reload schema';

-- ---------- notes ----------
-- * The anon API key in index.html is public by design; the policies above
--   are the real boundary. A stranger who signs in gets their own empty
--   ledger (owner = their uid) and cannot see anyone else's rows.
-- * To lock sign-in to just your address, in the dashboard go to
--   Authentication -> Providers -> Email and turn OFF "Allow new users to
--   sign up" after you have signed in once.
-- * Add your KRP site URL under Authentication -> URL Configuration
--   (Site URL + Redirect URLs, e.g. https://krp.vercel.app/**) or the
--   magic-link will be rejected on return.
