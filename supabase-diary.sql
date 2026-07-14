create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.diary_entries (
  id text primary key,
  trip_code text not null references public.trips(code) on delete cascade,
  date text,
  route_point_id text,
  title text,
  mood text,
  weather text,
  content text,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.diary_files (
  id text primary key,
  trip_code text not null references public.trips(code) on delete cascade,
  entry_id text not null,
  filename text not null,
  mime_type text not null default 'image/jpeg',
  storage_path text not null,
  caption text,
  size_bytes bigint not null default 0,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists diary_entries_trip_date_idx on public.diary_entries(trip_code, date);
create index if not exists diary_entries_trip_deleted_idx on public.diary_entries(trip_code, deleted_at);
create index if not exists diary_files_trip_entry_idx on public.diary_files(trip_code, entry_id);
create index if not exists diary_files_trip_deleted_idx on public.diary_files(trip_code, deleted_at);
create unique index if not exists diary_files_storage_path_unique_idx on public.diary_files(storage_path);

drop trigger if exists trg_diary_entries_updated_at on public.diary_entries;
create trigger trg_diary_entries_updated_at
before update on public.diary_entries
for each row execute function public.set_updated_at();

drop trigger if exists trg_diary_files_updated_at on public.diary_files;
create trigger trg_diary_files_updated_at
before update on public.diary_files
for each row execute function public.set_updated_at();

alter table public.diary_entries enable row level security;
alter table public.diary_files enable row level security;

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.diary_entries to anon, authenticated;
grant select, insert, update, delete on public.diary_files to anon, authenticated;

drop policy if exists "anon_all_diary_entries" on public.diary_entries;
create policy "anon_all_diary_entries" on public.diary_entries
for all to anon using (true) with check (true);

drop policy if exists "anon_all_diary_files" on public.diary_files;
create policy "anon_all_diary_files" on public.diary_files
for all to anon using (true) with check (true);

notify pgrst, 'reload schema';
