-- Email authentication and private per-user cloud data for Travel Planner.
--
-- Run this only after creating your owner account in the app or in
-- Supabase Authentication > Users. Replace the UUID below with that user's id.
-- The transaction stops before policies are enabled if the UUID is invalid.

begin;

insert into storage.buckets (id, name, public)
values ('travel-planner-files', 'travel-planner-files', false)
on conflict (id) do update set public = false;

select set_config('app.travel_planner_owner_id', 'PASTE_OWNER_AUTH_USER_UUID_HERE', true);

do $$
declare
  owner_uuid uuid := current_setting('app.travel_planner_owner_id')::uuid;
  table_name text;
  fk record;
  pk record;
begin
  if not exists (select 1 from auth.users where id = owner_uuid) then
    raise exception 'No auth user exists for %. Create the owner account first.', owner_uuid;
  end if;

  foreach table_name in array array[
    'trips', 'route_points', 'tickets', 'ticket_files', 'diary_entries',
    'diary_files', 'expenses', 'notes', 'checklists'
  ] loop
    execute format('alter table public.%I add column if not exists owner_id uuid references auth.users(id)', table_name);
    execute format('update public.%I set owner_id = $1 where owner_id is null', table_name) using owner_uuid;
    execute format('alter table public.%I alter column owner_id set not null', table_name);
    if table_name = 'trips' then
      execute 'create index if not exists trips_owner_code_idx on public.trips (owner_id, code)';
    else
      execute format('create index if not exists %I on public.%I (owner_id, trip_code)', table_name || '_owner_trip_idx', table_name);
    end if;
  end loop;

  -- A trip code is only unique inside one account. Child table foreign keys to
  -- trips(code) cannot express that and are replaced by RLS ownership checks.
  for fk in
    select conrelid::regclass as table_ref, conname
    from pg_constraint
    where contype = 'f' and confrelid = 'public.trips'::regclass
  loop
    execute format('alter table %s drop constraint %I', fk.table_ref, fk.conname);
  end loop;

  execute 'alter table public.trips drop constraint if exists trips_code_key';
  execute 'drop index if exists public.trips_code_unique_idx';
  execute 'create unique index if not exists trips_owner_code_unique_idx on public.trips(owner_id, code)';

  foreach table_name in array array['notes', 'checklists'] loop
    for pk in
      select conname from pg_constraint
      where conrelid = format('public.%I', table_name)::regclass and contype = 'p'
    loop
      execute format('alter table public.%I drop constraint %I', table_name, pk.conname);
    end loop;
  end loop;
  execute 'create unique index if not exists notes_owner_trip_unique_idx on public.notes(owner_id, trip_code)';
  execute 'create unique index if not exists checklists_owner_trip_list_unique_idx on public.checklists(owner_id, trip_code, list_key)';

  -- Move existing private objects under the owner's folder and keep metadata in sync.
  update storage.objects set name = owner_uuid::text || '/' || name
    where bucket_id = 'travel-planner-files' and name not like owner_uuid::text || '/%';
  update public.ticket_files set storage_path = owner_uuid::text || '/' || storage_path
    where storage_path <> '' and storage_path not like owner_uuid::text || '/%';
  update public.diary_files set storage_path = owner_uuid::text || '/' || storage_path
    where storage_path <> '' and storage_path not like owner_uuid::text || '/%';
end $$;

-- Existing policies deliberately allowed anonymous access. Remove them before
-- granting access only to the authenticated owner of each row.
do $$
declare table_name text;
begin
  foreach table_name in array array[
    'trips', 'route_points', 'tickets', 'ticket_files', 'diary_entries',
    'diary_files', 'expenses', 'notes', 'checklists'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('revoke all on public.%I from anon', table_name);
    execute format('grant select, insert, update, delete on public.%I to authenticated', table_name);
    execute format('drop policy if exists "anon_all_%s" on public.%I', table_name, table_name);
    execute format('drop policy if exists "owner_access" on public.%I', table_name);
    execute format(
      'create policy "owner_access" on public.%I for all to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id)',
      table_name
    );
  end loop;
end $$;

-- The first path segment in Storage is the authenticated user's UUID.
drop policy if exists "owner_read_travel_files" on storage.objects;
drop policy if exists "owner_insert_travel_files" on storage.objects;
drop policy if exists "owner_update_travel_files" on storage.objects;
drop policy if exists "owner_delete_travel_files" on storage.objects;

create policy "owner_read_travel_files" on storage.objects
for select to authenticated
using (bucket_id = 'travel-planner-files' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy "owner_insert_travel_files" on storage.objects
for insert to authenticated
with check (bucket_id = 'travel-planner-files' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy "owner_update_travel_files" on storage.objects
for update to authenticated
using (bucket_id = 'travel-planner-files' and (storage.foldername(name))[1] = (select auth.uid()::text))
with check (bucket_id = 'travel-planner-files' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy "owner_delete_travel_files" on storage.objects
for delete to authenticated
using (bucket_id = 'travel-planner-files' and (storage.foldername(name))[1] = (select auth.uid()::text));

notify pgrst, 'reload schema';
commit;

-- Verify the migration as an authenticated owner: each count should be visible
-- only to the signed-in user's own rows.
select table_name, column_name
from information_schema.columns
where table_schema = 'public' and column_name = 'owner_id'
order by table_name;
