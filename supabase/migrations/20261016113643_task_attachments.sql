begin;
insert into storage.buckets(id,name,public,file_size_limit) values ('poulpoints-attachments','poulpoints-attachments',false,10485760) on conflict(id) do nothing;
create table public.poulpoints_attachments (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null, task_id text not null, cycle bigint not null default 0,
 name text not null check(length(name) between 1 and 255),
 size bigint not null check(size between 1 and 10485760),
 path text unique not null,
 created_at timestamptz not null default now(), ready boolean not null default false,
 deleted_at timestamptz
);
alter table public.poulpoints_attachments enable row level security;
revoke all on public.poulpoints_attachments from public,anon,authenticated;
grant all on public.poulpoints_attachments to service_role;
create index on public.poulpoints_attachments(user_id,task_id);
create index on public.poulpoints_attachments(deleted_at);
-- Metadata is deliberately separate from task payloads, so older clients cannot erase it.
-- Only the authenticated Edge API may manage this private bucket; no public Storage policies.
create table private.poulpoints_attachment_gc_config(token text not null);
alter table private.poulpoints_attachment_gc_config enable row level security;
revoke all on private.poulpoints_attachment_gc_config from public,anon,authenticated;
grant usage on schema private to service_role;
grant select on private.poulpoints_attachment_gc_config to service_role;
insert into private.poulpoints_attachment_gc_config values(gen_random_uuid()::text || gen_random_uuid()::text);
create function public.poulpoints_attachment_gc_authorized(token text) returns boolean
language sql security invoker set search_path='' as $$
 select exists(select 1 from private.poulpoints_attachment_gc_config c where c.token=$1);
$$;
revoke all on function public.poulpoints_attachment_gc_authorized(text) from public,anon,authenticated;
grant execute on function public.poulpoints_attachment_gc_authorized(text) to service_role;
create function public.poulpoints_attachment_reserve(owner_id uuid, task text, filename text, bytes bigint)
returns public.poulpoints_attachments language plpgsql security invoker set search_path='' as $$
declare t public.poulpoints_task_records; a public.poulpoints_attachments; aid uuid:=gen_random_uuid();
begin
 perform pg_advisory_xact_lock(hashtextextended(owner_id::text,0));
 if not exists(select 1 from public.poulapp_access where user_id=owner_id and app_id='poulpoints') then raise exception 'Access denied'; end if;
 select * into t from public.poulpoints_task_records where user_id=owner_id and task_id=task for update;
 if not found or t.deleted or coalesce((t.payload->>'done')::boolean,false) then raise exception 'Task unavailable'; end if;
 if (select count(*) from public.poulpoints_attachments where user_id=owner_id and task_id=task and deleted_at is null)>=10 then raise exception '10 files maximum'; end if;
 if (select coalesce(sum(size),0) from public.poulpoints_attachments where user_id=owner_id)+bytes>104857600 then raise exception '100 MiB quota'; end if;
 insert into public.poulpoints_attachments(id,user_id,task_id,cycle,name,size,path)
 values(aid,owner_id,task,coalesce((t.payload->>'attachmentCycle')::bigint,0),filename,bytes,owner_id::text||'/'||aid::text) returning * into a;
 return a;
end; $$;
revoke all on function public.poulpoints_attachment_reserve(uuid,text,text,bigint) from public,anon,authenticated;
grant execute on function public.poulpoints_attachment_reserve(uuid,text,text,bigint) to service_role;
create function public.poulpoints_attachment_ready(attachment_id uuid, owner_id uuid) returns boolean
language plpgsql security invoker set search_path='' as $$
declare a public.poulpoints_attachments; t public.poulpoints_task_records;
begin
 select * into a from public.poulpoints_attachments where id=attachment_id and user_id=owner_id;
 if not found then return false; end if;
 select * into t from public.poulpoints_task_records where user_id=owner_id and task_id=a.task_id for update;
 if not found or t.deleted or coalesce((t.payload->>'done')::boolean,false) or coalesce((t.payload->>'attachmentCycle')::bigint,0)<>a.cycle then
 update public.poulpoints_attachments set deleted_at=coalesce(deleted_at,now()) where id=a.id; return false;
 end if;
 update public.poulpoints_attachments set ready=true where id=a.id and deleted_at is null;
 return found;
end; $$;
revoke all on function public.poulpoints_attachment_ready(uuid,uuid) from public,anon,authenticated;
grant execute on function public.poulpoints_attachment_ready(uuid,uuid) to service_role;
-- This internal trigger needs to enqueue deletions even for clients without attachment-table grants.
create function private.poulpoints_retire_attachments() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is not null and auth.uid()<>new.user_id then raise exception 'Owner mismatch'; end if;
 if new.deleted or coalesce((new.payload->>'done')::boolean,false) or
 coalesce(new.payload->>'attachmentCycle','0')<>coalesce(old.payload->>'attachmentCycle','0') then
 update public.poulpoints_attachments set deleted_at=coalesce(deleted_at,now()) where user_id=new.user_id and task_id=new.task_id;
 end if;
 return new;
end; $$;
revoke all on function private.poulpoints_retire_attachments() from public,anon,authenticated;
create trigger poulpoints_retire_attachments after update on public.poulpoints_task_records for each row execute function private.poulpoints_retire_attachments();
commit;
