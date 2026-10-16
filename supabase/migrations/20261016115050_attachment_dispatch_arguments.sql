begin;
select cron.schedule('poulpoints-attachment-cleanup','* * * * *',$job$
 select net.http_post(url=>endpoint, headers=>jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||gateway_jwt,'x-gc-token',token),body=>'{}'::jsonb,timeout_milliseconds=>20000)
 from private.poulpoints_attachment_gc_config where endpoint is not null and gateway_jwt is not null;
$job$);
-- Dispatch after the transaction commits. Failures remain queued for cron.
create or replace function private.poulpoints_dispatch_attachment_cleanup() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is not null and auth.uid()<>new.user_id then raise exception 'Owner mismatch'; end if;
 if new.deleted_at is not null and old.deleted_at is null then
  begin
   perform net.http_post(url=>endpoint,
    headers=>jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||gateway_jwt,'x-gc-token',token),
    body=>'{}'::jsonb,timeout_milliseconds=>20000)
   from private.poulpoints_attachment_gc_config where endpoint is not null and gateway_jwt is not null;
  exception when others then null; -- Never block task saving; cron retries.
  end;
 end if;
 return new;
end; $$;
revoke all on function private.poulpoints_dispatch_attachment_cleanup() from public,anon,authenticated;
commit;
