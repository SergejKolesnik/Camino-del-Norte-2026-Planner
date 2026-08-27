-- Optional migration for universal Travel Planner trip metadata.
-- The PWA works without this migration by falling back to trips(code, title, updated_at).

alter table public.trips
  add column if not exists description text,
  add column if not exists trip_type text,
  add column if not exists start_date text,
  add column if not exists end_date text,
  add column if not exists country text,
  add column if not exists countries text,
  add column if not exists currency text not null default 'EUR',
  add column if not exists timezone text not null default 'Europe/Kiev',
  add column if not exists status text not null default 'active';

update public.trips
set
  title = coalesce(nullif(title, ''), 'Camino del Norte 2026'),
  description = coalesce(description, 'Дніпро → Варшава → Більбао → Сантандер → Таріфа → додому'),
  trip_type = coalesce(trip_type, 'camino'),
  start_date = coalesce(start_date, '2026-07-25'),
  end_date = coalesce(end_date, '2026-08-07'),
  country = coalesce(country, 'Україна, Польща, Іспанія'),
  countries = coalesce(countries, 'Україна, Польща, Іспанія'),
  currency = coalesce(currency, 'EUR'),
  timezone = coalesce(timezone, 'Europe/Kiev'),
  status = coalesce(status, 'active')
where code = 'camino-2026';

create index if not exists trips_status_idx on public.trips(status);
create index if not exists trips_start_date_idx on public.trips(start_date);
