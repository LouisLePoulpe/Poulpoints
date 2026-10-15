-- Poulapp Cloud : single Supabase project, several applications.
-- Run as project administrator in Supabase SQL Editor.
-- Public sign-up must also be DISABLED in Supabase Auth settings.
-- Invitation and membership approval are administrative actions only.

begin;

create table if not exists public.poulapp_access (
  user_id uuid not null references auth.users(id) on delete cascade,
  app_id text not null check (app_id ~ '^[a-z][a-z0-9_]{1,49}$'),
  approved_at timestamptz not null default now(),
  primary key (user_id, app_id)
);

alter table public.poulapp_access enable row level security;
revoke all on table public.poulapp_access from public, anon, authenticated;
grant select on table public.poulapp_access to authenticated;

create policy "Users may read only their own application approvals"
  on public.poulapp_access for select to authenticated
  using (user_id = (select auth.uid()));

-- No insert/update/delete grant or RLS policy exists for regular users.
-- Add or revoke an approval ONLY as project administrator, e.g.:
-- insert into public.poulapp_access(user_id, app_id)
-- values ('REPLACE_WITH_USER_UUID', 'poulpoints');
-- To remove permission:
-- delete from public.poulapp_access
-- where user_id = 'REPLACE_WITH_USER_UUID' and app_id = 'poulpoints';

commit;
