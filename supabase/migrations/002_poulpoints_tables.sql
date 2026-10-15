-- Poulpoints, hosted together with other Poulapp applications.
-- Records are per user, authenticated + invite-only, and keep tombstones.
-- This migration builds the database foundation; the Flutter sync client
-- and conflict-resolution algorithm are separate future work.

begin;

create schema if not exists private;

create table if not exists public.poulpoints_task_records (
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id text not null check (char_length(task_id) between 1 and 128),
  payload jsonb not null default '{}'::jsonb
    check (jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 65536),
  deleted boolean not null default false,
  revision bigint not null default 1 check (revision >= 1),
  changed_at timestamptz not null default now(),
  primary key (user_id, task_id),
  constraint task_payload_id check (deleted or payload->>'id' = task_id)
);

create table if not exists public.poulpoints_project_records (
  user_id uuid not null references auth.users(id) on delete cascade,
  project_name text not null check (char_length(trim(project_name)) between 1 and 150),
  deleted boolean not null default false,
  revision bigint not null default 1 check (revision >= 1),
  changed_at timestamptz not null default now(),
  primary key (user_id, project_name)
);

-- Server-controlled revision and timestamp for all writes.
-- A client must not rely on unconditional UPSERT for conflicting edits.
create or replace function private.poulpoints_set_revision()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if TG_OP = 'INSERT' then
    new.revision := 1;
  else
    new.revision := old.revision + 1;
  end if;
  new.changed_at := clock_timestamp();
  return new;
end;
$$;

drop trigger if exists poulpoints_task_revision on public.poulpoints_task_records;
create trigger poulpoints_task_revision
  before insert or update on public.poulpoints_task_records
  for each row execute function private.poulpoints_set_revision();

drop trigger if exists poulpoints_project_revision on public.poulpoints_project_records;
create trigger poulpoints_project_revision
  before insert or update on public.poulpoints_project_records
  for each row execute function private.poulpoints_set_revision();

alter table public.poulpoints_task_records enable row level security;
alter table public.poulpoints_project_records enable row level security;

revoke all on table public.poulpoints_task_records from public, anon, authenticated;
revoke all on table public.poulpoints_project_records from public, anon, authenticated;
grant select, insert, update on table public.poulpoints_task_records to authenticated;
grant select, insert, update on table public.poulpoints_project_records to authenticated;
-- No hard delete for clients: update "deleted=true" so offline clients
-- cannot resurrect items. Admins can perform maintenance separately.

create policy "Poulpoints task read by approved owner"
  on public.poulpoints_task_records for select to authenticated
  using (user_id = (select auth.uid()) and exists (
    select 1 from public.poulapp_access a
    where a.user_id = (select auth.uid()) and a.app_id = 'poulpoints'
  ));
create policy "Poulpoints task insert by approved owner"
  on public.poulpoints_task_records for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (
    select 1 from public.poulapp_access a
    where a.user_id = (select auth.uid()) and a.app_id = 'poulpoints'
  ));
create policy "Poulpoints task update by approved owner"
  on public.poulpoints_task_records for update to authenticated
  using (user_id = (select auth.uid()) and exists (
    select 1 from public.poulapp_access a
    where a.user_id = (select auth.uid()) and a.app_id = 'poulpoints'
  ))
  with check (user_id = (select auth.uid()) and exists (
    select 1 from public.poulapp_access a
    where a.user_id = (select auth.uid()) and a.app_id = 'poulpoints'
  ));

create policy "Poulpoints project read by approved owner"
  on public.poulpoints_project_records for select to authenticated
  using (user_id = (select auth.uid()) and exists (
    select 1 from public.poulapp_access a
    where a.user_id = (select auth.uid()) and a.app_id = 'poulpoints'
  ));
create policy "Poulpoints project insert by approved owner"
  on public.poulpoints_project_records for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (
    select 1 from public.poulapp_access a
    where a.user_id = (select auth.uid()) and a.app_id = 'poulpoints'
  ));
create policy "Poulpoints project update by approved owner"
  on public.poulpoints_project_records for update to authenticated
  using (user_id = (select auth.uid()) and exists (
    select 1 from public.poulapp_access a
    where a.user_id = (select auth.uid()) and a.app_id = 'poulpoints'
  ))
  with check (user_id = (select auth.uid()) and exists (
    select 1 from public.poulapp_access a
    where a.user_id = (select auth.uid()) and a.app_id = 'poulpoints'
  ));

create index if not exists poulpoints_task_changes
  on public.poulpoints_task_records (user_id, changed_at, task_id);
create index if not exists poulpoints_project_changes
  on public.poulpoints_project_records (user_id, changed_at, project_name);

commit;
