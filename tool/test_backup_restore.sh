#!/usr/bin/env bash
set -euo pipefail
umask 077
root=$(mktemp -d /tmp/poulpoints-restore-XXXXXX)
export PGHOST="$root/socket" PGPORT=55439 PGUSER="$(id -un)"
unset PGSERVICE PGSERVICEFILE PGPASSWORD PGOPTIONS PGHOSTADDR
mkdir "$PGHOST"
initdb -D "$root/data" --auth=trust > "$root/init.log"
pg_ctl -D "$root/data" -l "$root/server.log" -o "-k $PGHOST -p $PGPORT -h ''" start >/dev/null
trap 'pg_ctl -D "$root/data" stop -m fast >/dev/null' EXIT
createdb poulpoints_fixture
export PGDATABASE=poulpoints_fixture
psql -X -v ON_ERROR_STOP=1 >/dev/null <<'SQL'
create role anon;
create role authenticated;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
SQL
psql -X -v ON_ERROR_STOP=1 -f supabase/migrations/001_poulapp_access.sql >/dev/null
psql -X -v ON_ERROR_STOP=1 -f supabase/migrations/002_poulpoints_tables.sql >/dev/null
psql -X -v ON_ERROR_STOP=1 >/dev/null <<'SQL'
insert into auth.users values ('00000000-0000-4000-8000-000000000001');
insert into public.poulapp_access(user_id,app_id) values ('00000000-0000-4000-8000-000000000001','poulpoints');
insert into public.poulpoints_task_records(user_id,task_id,payload) values ('00000000-0000-4000-8000-000000000001','fixture','{"id":"fixture","title":"Données fictives","reminderOffsets":[0,60,1440]}');
insert into public.poulpoints_project_records(user_id,project_name) values ('00000000-0000-4000-8000-000000000001','Essai');
SQL
export POULPOINTS_BACKUP_DIR="$root/backups"
folder=$(bash ops/backup_database.sh)
createdb poulpoints_restored
pg_restore --exit-on-error --dbname=poulpoints_restored "$folder/database.dump"
export PGDATABASE=poulpoints_restored
psql -X -v ON_ERROR_STOP=1 >/dev/null <<'SQL'
do $$ begin
if (select count(*) from public.poulpoints_task_records) <> 1 then raise exception 'Missing task'; end if;
if (select payload->'reminderOffsets' from public.poulpoints_task_records limit 1) <> '[0,60,1440]'::jsonb then raise exception 'Reminders changed'; end if;
if not (select relrowsecurity from pg_class where oid='public.poulpoints_task_records'::regclass) then raise exception 'RLS lost'; end if;
if (select count(*) from public.poulapp_access) <> 1 then raise exception 'Access lost'; end if;
end $$;
SQL
psql -X -v ON_ERROR_STOP=1 -f ops/cloud_health.sql
printf 'PASS: isolated fixture backup and restore; no production connection.\n'
