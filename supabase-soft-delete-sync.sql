-- Soft-delete support for multi-device sync.
-- Safe to run more than once. This migration does not delete data.

alter table public.route_points
  add column if not exists deleted_at timestamptz;

alter table public.tickets
  add column if not exists deleted_at timestamptz;

alter table public.ticket_files
  add column if not exists deleted_at timestamptz;

alter table public.expenses
  add column if not exists deleted_at timestamptz;

create index if not exists route_points_trip_deleted_idx
  on public.route_points(trip_code, deleted_at);

create index if not exists tickets_trip_deleted_idx
  on public.tickets(trip_code, deleted_at);

create index if not exists ticket_files_trip_deleted_idx
  on public.ticket_files(trip_code, deleted_at);

create index if not exists expenses_trip_deleted_idx
  on public.expenses(trip_code, deleted_at);
