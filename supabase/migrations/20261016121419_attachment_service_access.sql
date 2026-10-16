-- Edge service reads approval/task ownership and locks the task during upload.
-- No additional rights for mobile/web clients.
begin;
grant select on public.poulapp_access to service_role;
grant select, update on public.poulpoints_task_records to service_role;
commit;
