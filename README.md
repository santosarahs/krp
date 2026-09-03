# KRP Bread Ledger

Cart-route bookkeeping for KRP, replacing `KRP_financemaster_2026.xlsx`.
One file: [`index.html`](index.html).

Count each bread type **loaded** onto a cart before it rolls out and the
**leftover** pieces when it returns. The app works out sold pieces, gross
revenue, the seller's 15%, your route expenses, and route profit — then
subtracts monthly supply purchases for net profit and margin, the same way
the spreadsheet's `summary` sheet totalled it.

Breads (editable in Settings): Malunggay Pandesal ₱5 / 24 per tray ·
Ube Pandesal ₱6 / 20 · Spanish Bread ₱6 / 16. Two rolling carts, up to two
routes each per day.

## Where the data lives

The same `index.html` stores differently depending on where it runs:

| Opened as | Storage |
|---|---|
| Claude Artifact (`claude.ai/code/artifact/…`) | Built-in per-account sync, no login (single user) |
| This site on Vercel | **Supabase** — email sign-in, shared team ledger, roles |
| Local file / Supabase not reachable | That browser only (offline) |

## Roles (Supabase copy)

Managed from the **Users** tab (admins only). The first person to sign in
becomes admin automatically.

| Role | Can |
|---|---|
| **Admin** | Everything — routes, supplies, Settings, and the Users list |
| **Member** | Add and edit routes and supplies |
| **View only** | Read routes, supplies, and reports; change nothing |

Inviting: add the person's email in Users, pick a role, then send them the
site link. They sign in with that address and land straight in. Keep
"Allow new users to sign up" **on** in Supabase → Authentication →
Providers → Email so first-time sign-ins work.

## Deploy (Vercel + Supabase)

Supabase lives in the **same project** as `santosfamilyhealth` — a separate
`krp_docs` table with its own row-level security, so it doesn't count
against the free 2-project limit.

1. **Schema** — Supabase → SQL Editor → run [`supabase/schema.sql`](supabase/schema.sql).
   Creates `krp_members`, `krp_docs`, and the role policies. (It drops the old
   single-user `krp_docs` — harmless, that table held no real data.)
2. **Keys** — the Project URL and `anon` key are already set near the top of
   `index.html`. The anon key is public by design; the policies are the boundary.
3. **Redirect URL** — Supabase → Authentication → URL Configuration: add your
   KRP site URL as the Site URL and `https://<your-krp-site>/**` under Redirect URLs.
4. **Vercel** — import this repo (no build step, static). Push to `main` redeploys.
5. Open the site, enter your email, click the link — you're now admin. Invite
   the rest from the **Users** tab.

`KRP_financemaster_2026.xlsx` is gitignored — the historical spreadsheet stays local.
