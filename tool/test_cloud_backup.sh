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

psql -X -v ON_ERROR_STOP=1 >/dev/null <<'SQL'
create role service_role bypassrls;
create schema storage;
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint);
SQL
psql -X -v ON_ERROR_STOP=1 -f supabase/migrations/20261016113643_task_attachments.sql >/dev/null
psql -X -v ON_ERROR_STOP=1 -f supabase/migrations/20261016121419_attachment_service_access.sql >/dev/null
psql -X -v ON_ERROR_STOP=1 <<'SQL'
set role service_role;
do $$ declare a public.poulpoints_attachments; begin
 select * into a from public.poulpoints_attachment_reserve('00000000-0000-4000-8000-000000000001','fixture','test.txt',10);
 if not public.poulpoints_attachment_ready(a.id,a.user_id) then raise exception 'Cannot finalize upload'; end if;
 update public.poulpoints_task_records set payload=payload||'{"done":true}'::jsonb where task_id='fixture';
 if not exists(select 1 from public.poulpoints_attachments where id=a.id and deleted_at is not null) then raise exception 'Completion did not retire attachment'; end if;
 if public.poulpoints_attachment_ready(a.id,a.user_id) then raise exception 'Completed task accepted upload'; end if;
 update public.poulpoints_task_records set payload=payload||'{"done":false,"attachmentCycle":1}'::jsonb where task_id='fixture';
 if not exists(select 1 from public.poulpoints_attachments where id=a.id and deleted_at is not null) then raise exception 'Reopening resurrected attachment'; end if;
 begin perform public.poulpoints_attachment_reserve('00000000-0000-4000-8000-000000000002','fixture','wrong.txt',10); raise exception 'Unauthorized owner accepted'; exception when raise_exception then if sqlerrm='Unauthorized owner accepted' then raise; end if; end;
 end $$;
select has_function_privilege('authenticated','public.poulpoints_attachment_reserve(uuid,text,text,bigint)','EXECUTE') as must_be_false;
SQL
printf 'PASS: attachment lifecycle and ownership test.\n'

python3 tool/test_cloud_backup.py
