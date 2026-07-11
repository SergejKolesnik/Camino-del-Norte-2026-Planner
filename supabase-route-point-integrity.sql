-- Camino Planner route_points integrity migration.
-- Run the PREVIEW queries first. Run the TRANSACTION only after reviewing the output.

-- 1) PREVIEW: exact duplicate groups that are safe candidates for automatic cleanup.
with enriched as (
  select
    rp.*,
    concat_ws('|',
      rp.trip_code,
      coalesce(rp.date, ''),
      coalesce(rp.time, ''),
      lower(trim(coalesce(rp.type, ''))),
      lower(trim(coalesce(rp.title, ''))),
      lower(trim(coalesce(rp.from_place, ''))),
      lower(trim(coalesce(rp.to_place, '')))
    ) as duplicate_key,
    (
      case when nullif(trim(coalesce(rp.date, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.time, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.type, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.from_place, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.to_place, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.title, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.address, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.note, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.maps_url, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.status, '')), '') is not null then 1 else 0 end
    ) as filled_score,
    (select count(*) from public.ticket_files tf where tf.ticket_id = rp.id) as ticket_files_count,
    (select count(*) from public.tickets t where t.related_point_id = rp.id) as linked_tickets_count
  from public.route_points rp
  where rp.trip_code in ('camino-2026', 'camino2026')
),
groups as (
  select
    duplicate_key,
    count(*) as duplicate_count,
    count(*) filter (where ticket_files_count > 0) as rows_with_files,
    count(*) filter (where linked_tickets_count > 0) as rows_with_tickets,
    count(distinct nullif(trim(coalesce(note, '')), '')) as distinct_notes,
    max(coalesce(time, '')) as time_norm
  from enriched
  group by duplicate_key
  having count(*) > 1
)
select
  g.duplicate_key,
  g.duplicate_count,
  g.rows_with_files,
  g.rows_with_tickets,
  g.distinct_notes,
  jsonb_agg(
    jsonb_build_object(
      'id', e.id,
      'date', e.date,
      'time', e.time,
      'type', e.type,
      'title', e.title,
      'from_place', e.from_place,
      'to_place', e.to_place,
      'ticket_files', e.ticket_files_count,
      'linked_tickets', e.linked_tickets_count,
      'filled_score', e.filled_score,
      'updated_at', e.updated_at
    )
    order by e.ticket_files_count desc, e.linked_tickets_count desc, e.filled_score desc, e.updated_at desc
  ) as rows
from groups g
join enriched e using (duplicate_key)
group by g.duplicate_key, g.duplicate_count, g.rows_with_files, g.rows_with_tickets, g.distinct_notes, g.time_norm
order by g.duplicate_count desc, g.duplicate_key;

-- 2) PREVIEW: possible duplicates that require manual review and are NOT cleaned automatically.
with enriched as (
  select
    rp.*,
    concat_ws('|',
      rp.trip_code,
      coalesce(rp.date, ''),
      coalesce(rp.time, ''),
      lower(trim(coalesce(rp.type, ''))),
      lower(trim(coalesce(rp.title, ''))),
      lower(trim(coalesce(rp.from_place, ''))),
      lower(trim(coalesce(rp.to_place, '')))
    ) as duplicate_key,
    (select count(*) from public.ticket_files tf where tf.ticket_id = rp.id) as ticket_files_count,
    (select count(*) from public.tickets t where t.related_point_id = rp.id) as linked_tickets_count
  from public.route_points rp
  where rp.trip_code in ('camino-2026', 'camino2026')
),
groups as (
  select
    duplicate_key,
    count(*) as duplicate_count,
    count(*) filter (where ticket_files_count > 0) as rows_with_files,
    count(*) filter (where linked_tickets_count > 0) as rows_with_tickets,
    count(distinct nullif(trim(coalesce(note, '')), '')) as distinct_notes,
    max(coalesce(time, '')) as time_norm
  from enriched
  group by duplicate_key
  having count(*) > 1
)
select e.*
from enriched e
join groups g using (duplicate_key)
where g.rows_with_files > 1
   or g.rows_with_tickets > 1
   or (g.time_norm = '' and g.distinct_notes > 1)
order by e.duplicate_key, e.updated_at desc;

-- 3) TRANSACTION: canonical trip_code + safe duplicate cleanup.
begin;

insert into public.trips (code, title)
values ('camino-2026', 'Camino del Norte 2026')
on conflict (code) do update
set title = excluded.title,
    updated_at = now();

update public.route_points set trip_code = 'camino-2026' where trip_code = 'camino2026';
update public.tickets set trip_code = 'camino-2026' where trip_code = 'camino2026';
update public.ticket_files set trip_code = 'camino-2026' where trip_code = 'camino2026';
update public.expenses set trip_code = 'camino-2026' where trip_code = 'camino2026';
insert into public.notes (trip_code, content, created_at, updated_at)
select 'camino-2026', content, created_at, updated_at
from public.notes
where trip_code = 'camino2026'
on conflict (trip_code) do update
set content = case
    when excluded.updated_at > public.notes.updated_at then excluded.content
    else public.notes.content
  end,
  updated_at = greatest(public.notes.updated_at, excluded.updated_at);

insert into public.checklists (trip_code, list_key, state, created_at, updated_at)
select 'camino-2026', list_key, state, created_at, updated_at
from public.checklists
where trip_code = 'camino2026'
on conflict (trip_code, list_key) do update
set state = case
    when excluded.updated_at > public.checklists.updated_at then excluded.state
    else public.checklists.state
  end,
  updated_at = greatest(public.checklists.updated_at, excluded.updated_at);

delete from public.notes where trip_code = 'camino2026';
delete from public.checklists where trip_code = 'camino2026';
delete from public.trips where code = 'camino2026';

create temporary table route_point_duplicate_map on commit drop as
with enriched as (
  select
    rp.*,
    concat_ws('|',
      rp.trip_code,
      coalesce(rp.date, ''),
      coalesce(rp.time, ''),
      lower(trim(coalesce(rp.type, ''))),
      lower(trim(coalesce(rp.title, ''))),
      lower(trim(coalesce(rp.from_place, ''))),
      lower(trim(coalesce(rp.to_place, '')))
    ) as duplicate_key,
    (
      case when nullif(trim(coalesce(rp.date, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.time, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.type, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.from_place, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.to_place, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.title, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.address, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.note, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.maps_url, '')), '') is not null then 1 else 0 end +
      case when nullif(trim(coalesce(rp.status, '')), '') is not null then 1 else 0 end
    ) as filled_score,
    (select count(*) from public.ticket_files tf where tf.ticket_id = rp.id) as ticket_files_count,
    (select count(*) from public.tickets t where t.related_point_id = rp.id) as linked_tickets_count
  from public.route_points rp
  where rp.trip_code = 'camino-2026'
),
safe_groups as (
  select
    duplicate_key,
    max(coalesce(time, '')) as time_norm,
    count(distinct nullif(trim(coalesce(note, '')), '')) as distinct_notes,
    count(*) filter (where ticket_files_count > 0) as rows_with_files,
    count(*) filter (where linked_tickets_count > 0) as rows_with_tickets
  from enriched
  group by duplicate_key
  having count(*) > 1
     and count(*) filter (where ticket_files_count > 0) <= 1
     and count(*) filter (where linked_tickets_count > 0) <= 1
     and (max(coalesce(time, '')) <> '' or count(distinct nullif(trim(coalesce(note, '')), '')) <= 1)
),
ranked as (
  select
    e.*,
    first_value(e.id) over (
      partition by e.duplicate_key
      order by e.ticket_files_count desc, e.linked_tickets_count desc, e.filled_score desc, e.updated_at desc nulls last, e.created_at desc nulls last, e.id
    ) as canonical_id,
    row_number() over (
      partition by e.duplicate_key
      order by e.ticket_files_count desc, e.linked_tickets_count desc, e.filled_score desc, e.updated_at desc nulls last, e.created_at desc nulls last, e.id
    ) as rn
  from enriched e
  join safe_groups sg using (duplicate_key)
)
select id as duplicate_id, canonical_id
from ranked
where rn > 1;

update public.tickets t
set related_point_id = m.canonical_id,
    updated_at = now()
from route_point_duplicate_map m
where t.related_point_id = m.duplicate_id;

update public.ticket_files tf
set ticket_id = m.canonical_id,
    updated_at = now()
from route_point_duplicate_map m
where tf.ticket_id = m.duplicate_id;

delete from public.route_points rp
using route_point_duplicate_map m
where rp.id = m.duplicate_id;

commit;

-- 4) VERIFY: should stay stable after repeated app Download/Sync.
select count(*) as route_points_after_cleanup
from public.route_points
where trip_code = 'camino-2026';
