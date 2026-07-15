# Camino del Norte 2026 Planner

## GitHub Pages

Окремий репозиторій для публікації:

```text
SergejKolesnik/Camino-del-Norte-2026-Planner
```

Після push у `main` увімкніть GitHub Pages:

1. `GitHub` → `Settings` → `Pages`.
2. `Source`: `Deploy from branch`.
3. Branch: `main`.
4. Folder: `/root`.
5. `Save`.

Очікуване посилання:

```text
https://sergejkolesnik.github.io/Camino-del-Norte-2026-Planner/
```

Supabase URL/key не хардкодяться. Їх потрібно ввести у вкладці `☁️ Синхр.` у самому застосунку.

Мобільний офлайн travel-planner / PWA без фреймворків. Основний режим роботи локальний: `localStorage` + `IndexedDB`. Supabase-синхронізація є необов'язковою: текстові дані синхронізуються через таблиці, а файли квитків - через Supabase Storage bucket `camino-files`.

## Основний репозиторій і workflow

GitHub є основним джерелом правди для проєкту. Робоча локальна копія:

```text
C:\Users\rjktc\Documents\Codex\2026-07-07\Camino-del-Norte-2026-Planner
```

Старі копії в `outputs` більше не редагуються, щоб не підтримувати кілька різних версій одного застосунку.

Перед початком роботи:

```bash
git checkout main
git pull origin main
```

Для нової зміни:

```bash
git checkout -b feature/nazva-zminy
```

Після перевірки:

```bash
git add .
git commit -m "Short clear change description"
git push origin feature/nazva-zminy
```

Після merge у `main` GitHub Pages автоматично публікує оновлену PWA за адресою:

```text
https://sergejkolesnik.github.io/Camino-del-Norte-2026-Planner/
```

## Route point sync integrity

Канонічний код подорожі: `camino-2026`. Старий код `camino2026` застосунок автоматично нормалізує до `camino-2026`.

Для очищення вже створених дублікатів у Supabase використайте файл:

```text
supabase-route-point-integrity.sql
```

Порядок:

1. Запустіть preview-запити з файлу в Supabase SQL Editor.
2. Перевірте manual-review кандидати.
3. Запустіть transaction-блок.
4. У застосунку відкрийте `☁️ Синхр.` → `Перевірити цілісність маршруту`.
5. Виконайте кілька `Download` / `Sync` і переконайтесь, що кількість `route_points` не зростає.

Якщо база була створена до soft-delete синхронізації, спочатку виконайте `supabase-soft-delete-sync.sql`.
Він додає `deleted_at` до `route_points`, `tickets`, `ticket_files`, `expenses` та індекси для безпечного multi-device merge.

## Запуск

PWA потрібно відкривати через HTTP, бо service worker не працює з `file://`.

```bash
python -m http.server 8080
```

На телефоні відкрийте:

```text
http://IP-АДРЕСА-КОМП'ЮТЕРА:8080/
```

## Встановлення PWA

Android / Chrome: меню `⋮` → `Додати на головний екран` або `Встановити застосунок`.

iPhone / Safari: `Поділитися` → `На Початковий екран`.

## Supabase Project

1. Зайдіть на [supabase.com](https://supabase.com/).
2. Створіть новий project.
3. Відкрийте `SQL Editor`.
4. Вставте SQL нижче і натисніть `Run`.
5. Відкрийте `Project Settings` → `API`.
6. Скопіюйте `Project URL` і `anon public key`.
7. У PWA відкрийте розділ `Синхр.` і вставте URL, anon key та код подорожі, наприклад `camino-2026`.

## SQL Schema

Цей SQL створює таблиці, індекси, `updated_at` тригери і прості RLS policies для персонального використання через anon key.

```sql
create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null default 'Camino del Norte 2026',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.route_points (
  id text primary key,
  trip_code text not null references public.trips(code) on delete cascade,
  date text,
  time text,
  type text,
  from_place text,
  to_place text,
  title text,
  address text,
  note text,
  maps_url text,
  status text,
  sort_order int not null default 0,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tickets (
  id text primary key,
  trip_code text not null references public.trips(code) on delete cascade,
  type text,
  title text,
  date text,
  related_point_id text,
  booking_number text,
  note text,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ticket_files (
  id text primary key,
  trip_code text not null references public.trips(code) on delete cascade,
  -- owner id: either tickets.id or route_points.id for timeline travel documents
  ticket_id text not null,
  filename text not null,
  mime_type text not null default 'application/octet-stream',
  storage_path text not null,
  size_bytes bigint not null default 0,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

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
  mime_type text not null default 'application/octet-stream',
  storage_path text not null,
  caption text,
  size_bytes bigint not null default 0,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.expenses (
  id text primary key,
  trip_code text not null references public.trips(code) on delete cascade,
  category text,
  title text,
  amount numeric(12,2) not null default 0,
  currency text not null default 'EUR',
  date text,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notes (
  trip_code text primary key references public.trips(code) on delete cascade,
  content text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.checklists (
  trip_code text not null references public.trips(code) on delete cascade,
  list_key text not null,
  state jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (trip_code, list_key)
);

create index if not exists route_points_trip_code_sort_idx on public.route_points(trip_code, sort_order);
create index if not exists route_points_trip_deleted_idx on public.route_points(trip_code, deleted_at);
create index if not exists tickets_trip_code_idx on public.tickets(trip_code);
create index if not exists tickets_trip_deleted_idx on public.tickets(trip_code, deleted_at);
create index if not exists ticket_files_trip_ticket_idx on public.ticket_files(trip_code, ticket_id);
create index if not exists ticket_files_trip_deleted_idx on public.ticket_files(trip_code, deleted_at);
create unique index if not exists ticket_files_storage_path_unique_idx on public.ticket_files(storage_path);
create index if not exists diary_entries_trip_date_idx on public.diary_entries(trip_code, date);
create index if not exists diary_entries_trip_deleted_idx on public.diary_entries(trip_code, deleted_at);
create index if not exists diary_files_trip_entry_idx on public.diary_files(trip_code, entry_id);
create index if not exists diary_files_trip_deleted_idx on public.diary_files(trip_code, deleted_at);
create unique index if not exists diary_files_storage_path_unique_idx on public.diary_files(storage_path);

-- Migration for older installs where ticket_files.ticket_id had an FK to tickets(id).
-- Timeline documents use route_points.id as the same owner id, so this FK must be removed.
alter table public.ticket_files
  drop constraint if exists ticket_files_ticket_id_fkey;
alter table public.ticket_files
  alter column ticket_id set not null;
create index if not exists expenses_trip_code_idx on public.expenses(trip_code);
create index if not exists expenses_trip_deleted_idx on public.expenses(trip_code, deleted_at);
create unique index if not exists trips_code_unique_idx on public.trips(code);

drop trigger if exists trg_trips_updated_at on public.trips;
create trigger trg_trips_updated_at
before update on public.trips
for each row execute function public.set_updated_at();

drop trigger if exists trg_route_points_updated_at on public.route_points;
create trigger trg_route_points_updated_at
before update on public.route_points
for each row execute function public.set_updated_at();

drop trigger if exists trg_tickets_updated_at on public.tickets;
create trigger trg_tickets_updated_at
before update on public.tickets
for each row execute function public.set_updated_at();

drop trigger if exists trg_ticket_files_updated_at on public.ticket_files;
create trigger trg_ticket_files_updated_at
before update on public.ticket_files
for each row execute function public.set_updated_at();

drop trigger if exists trg_diary_entries_updated_at on public.diary_entries;
create trigger trg_diary_entries_updated_at
before update on public.diary_entries
for each row execute function public.set_updated_at();

drop trigger if exists trg_diary_files_updated_at on public.diary_files;
create trigger trg_diary_files_updated_at
before update on public.diary_files
for each row execute function public.set_updated_at();

drop trigger if exists trg_expenses_updated_at on public.expenses;
create trigger trg_expenses_updated_at
before update on public.expenses
for each row execute function public.set_updated_at();

drop trigger if exists trg_notes_updated_at on public.notes;
create trigger trg_notes_updated_at
before update on public.notes
for each row execute function public.set_updated_at();

drop trigger if exists trg_checklists_updated_at on public.checklists;
create trigger trg_checklists_updated_at
before update on public.checklists
for each row execute function public.set_updated_at();

alter table public.trips enable row level security;
alter table public.route_points enable row level security;
alter table public.tickets enable row level security;
alter table public.ticket_files enable row level security;
alter table public.diary_entries enable row level security;
alter table public.diary_files enable row level security;
alter table public.expenses enable row level security;
alter table public.notes enable row level security;
alter table public.checklists enable row level security;

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.diary_entries to anon, authenticated;
grant select, insert, update, delete on public.diary_files to anon, authenticated;

drop policy if exists "anon_all_trips" on public.trips;
create policy "anon_all_trips" on public.trips
for all to anon using (true) with check (true);

drop policy if exists "anon_all_route_points" on public.route_points;
create policy "anon_all_route_points" on public.route_points
for all to anon using (true) with check (true);

drop policy if exists "anon_all_tickets" on public.tickets;
create policy "anon_all_tickets" on public.tickets
for all to anon using (true) with check (true);

drop policy if exists "anon_all_ticket_files" on public.ticket_files;
create policy "anon_all_ticket_files" on public.ticket_files
for all to anon using (true) with check (true);

drop policy if exists "anon_all_diary_entries" on public.diary_entries;
create policy "anon_all_diary_entries" on public.diary_entries
for all to anon using (true) with check (true);

drop policy if exists "anon_all_diary_files" on public.diary_files;
create policy "anon_all_diary_files" on public.diary_files
for all to anon using (true) with check (true);

notify pgrst, 'reload schema';

drop policy if exists "anon_all_expenses" on public.expenses;
create policy "anon_all_expenses" on public.expenses
for all to anon using (true) with check (true);

drop policy if exists "anon_all_notes" on public.notes;
create policy "anon_all_notes" on public.notes
for all to anon using (true) with check (true);

drop policy if exists "anon_all_checklists" on public.checklists;
create policy "anon_all_checklists" on public.checklists
for all to anon using (true) with check (true);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'camino-files',
  'camino-files',
  false,
  20971520,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'audio/webm', 'audio/mp4', 'audio/mpeg', 'application/pdf']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "anon_read_camino_files" on storage.objects;
create policy "anon_read_camino_files" on storage.objects
for select to anon
using (bucket_id = 'camino-files');

drop policy if exists "anon_insert_camino_files" on storage.objects;
create policy "anon_insert_camino_files" on storage.objects
for insert to anon
with check (bucket_id = 'camino-files');

drop policy if exists "anon_update_camino_files" on storage.objects;
create policy "anon_update_camino_files" on storage.objects
for update to anon
using (bucket_id = 'camino-files')
with check (bucket_id = 'camino-files');

drop policy if exists "anon_delete_camino_files" on storage.objects;
create policy "anon_delete_camino_files" on storage.objects
for delete to anon
using (bucket_id = 'camino-files');
```

Важливо: ці RLS policies відкривають таблиці для anon key. Для приватного персонального project це найпростіший режим. Не публікуйте URL/key у відкритому репозиторії. Для публічного multi-user сценарію потрібна Supabase Auth і жорсткіші policies.

## Як підключити перший телефон

1. Встановіть PWA.
2. Відкрийте `Синхр.`.
3. Введіть Supabase URL, anon key і код подорожі.
4. Натисніть `Підключити`.
5. Натисніть `Перевірити Supabase`.
6. Якщо статус `Supabase працює`, натисніть `Завантажити локальні дані в хмару`.

## Як підключити другий телефон

1. Встановіть PWA на другому телефоні.
2. Введіть той самий Supabase URL, anon key і той самий код подорожі.
3. Натисніть `Підключити`.
4. Натисніть `Підтягнути дані з хмари`.
5. Далі використовуйте `Синхронізувати зараз`.

## Що синхронізується

- маршрутні точки;
- квитки та бронювання;
- файли квитків і бронювань через Supabase Storage bucket `camino-files` та таблицю `ticket_files`;
- записи щоденника через таблицю `diary_entries`;
- фото й голосові нотатки щоденника через Supabase Storage bucket `camino-files` та таблицю `diary_files`;
- бюджет;
- нотатки;
- стани чек-листів.

Синхронізація порівнює `updated_at` і використовує правило `lastUpdated wins`. Після локальних змін застосунок запускає autosync через debounce приблизно 2.5 секунди, додатково синхронізується при відкритті, поверненні вкладки у фокус, відновленні інтернету та з обраним інтервалом 5 / 15 / 30 хв. Якщо Supabase недоступний, застосунок не падає і показує статус `Є локальні зміни` або `Помилка синхронізації`.

## Файли та fallback

Якщо Supabase підключений, скріншоти квитків, PDF, бронювання, фото й голосові нотатки щоденника завантажуються у Storage bucket `camino-files`. Metadata квиткових файлів зберігається в `ticket_files`, metadata медіа щоденника - в `diary_files`.

Якщо Supabase не підключений або недоступний, файл зберігається локально в IndexedDB і застосунок показує повідомлення на кшталт `Файл збережено локально. Для синхронізації підключіть Supabase.`

Після підключення Supabase локальні IndexedDB-файли автоматично завантажуються у Storage під час `Upload` або `Sync`, якщо вони ще не мають `cloudId`.

Видалення хмарного файлу робить soft-delete запису в `ticket_files` і під час sync пробує прибрати відповідний object зі Storage. Якщо Storage delete policy не налаштована, застосунок не падає: metadata все одно синхронізується, а помилка буде в журналі синхронізації.

Локальні IndexedDB-файли без `cloudId` не потрапляють на інші пристрої, доки не відбудеться успішний sync із Supabase.

Для роботи Storage у SQL мають бути створені bucket `camino-files`, таблиці `ticket_files` / `diary_files` і policies на `storage.objects` для `select`, `insert`, `update`, `delete`. Якщо файли не завантажуються або не видаляються, спочатку перевірте саме цей блок SQL.

## Щоденник подорожі

Вкладка `Щоденник` дозволяє створювати записи з датою, прив'язкою до точки маршруту, настроєм, погодою, текстом, фото і голосовими поясненнями.

Медіа щоденника зберігаються так:

- з Supabase: `camino-files/camino-2026/diary/<entry_id>/...`;
- без Supabase: локально в IndexedDB store `diaryFiles`;
- JSON backup експортує тільки текстові записи щоденника, без фото й аудіо.

Щоб фото й голосові нотатки щоденника були доступні на другому телефоні, виконайте SQL schema з таблицями `diary_entries` і `diary_files`, підключіть Supabase в PWA і натисніть `Sync`.

Для вже налаштованої бази можна не запускати весь великий SQL повторно, а виконати тільки файл:

```text
supabase-diary.sql
```

## Як перевірити синхронізацію

У розділі `Синхр.` натисніть `Перевірити Supabase`.

Кнопка:

- створює або оновлює trip;
- записує тестову точку маршруту;
- читає її назад;
- показує `Supabase працює` або конкретну помилку.

Останні 10 подій видно в журналі синхронізації.

## Офлайн режим

Якщо Supabase не налаштовано, CDN недоступний або немає інтернету, застосунок не падає і продовжує працювати локально.

Локальні дані:

- маршрут, квитки, бюджет, нотатки, чек-листи, щоденник, sync config - `localStorage`;
- локальні fallback-скріни, PDF, вкладення, фото й голосові нотатки щоденника - `IndexedDB`;
- хмарні файли квитків, фото й голосові нотатки щоденника - Supabase Storage `camino-files`.

## Експорт та імпорт

У розділі `☁️ Синхр.` є блок `Backup JSON`: там можна експортувати або імпортувати JSON. Файли, фото й аудіо не входять у JSON-експорт.
