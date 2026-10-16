-- Aggregate counters only, no task contents or account identifiers.
begin read only;
select json_build_object(
 'checked_at',now(),
 'database_bytes',pg_database_size(current_database()),
 'approved_users',(select count(*) from public.poulapp_access where app_id='poulpoints'),
 'task_records',(select count(*) from public.poulpoints_task_records),
 'attachment_bytes',(select coalesce(sum(size),0) from public.poulpoints_attachments),
 'storage_objects',(select count(*) from storage.objects where bucket_id='poulpoints-attachments'),
 'pending_deletions',(select count(*) from public.poulpoints_attachments where deleted_at is not null),
 'overdue_deletions',(select count(*) from public.poulpoints_attachments where deleted_at < now()-interval '15 minutes'),
 'failed_cleanup_last_hour',(select count(*) from cron.job_run_details where jobid=(select jobid from cron.job where jobname='poulpoints-attachment-cleanup') and start_time>now()-interval '1 hour' and status='failed')
);
commit;
