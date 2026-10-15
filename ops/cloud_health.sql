-- Read-only administrator check; no task contents or user identities returned.
begin read only;
select json_build_object(
  'checked_at', now(),
  'database_bytes', pg_database_size(current_database()),
  'task_records', (select count(*) from public.poulpoints_task_records),
  'deleted_task_records', (select count(*) from public.poulpoints_task_records where deleted),
  'project_records', (select count(*) from public.poulpoints_project_records),
  'approved_users', (select count(*) from public.poulapp_access where app_id = 'poulpoints'),
  'tasks_rls_enabled', (select relrowsecurity from pg_class where oid = 'public.poulpoints_task_records'::regclass),
  'projects_rls_enabled', (select relrowsecurity from pg_class where oid = 'public.poulpoints_project_records'::regclass)
);
commit;
