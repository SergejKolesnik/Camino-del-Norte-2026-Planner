-- Camino Planner route_points integrity migration.
-- Run previews first. Run the DRY RUN next. Run the TRANSACTION only after review.
-- Safety rule: linked data is relinked before route_points are deleted.

-- Canonical trip_code expression used in every duplicate_key:
-- case when rp.trip_code = 'camino2026' then 'camino-2026' else rp.trip_code end

-- PREVIEW 1: exact duplicate groups that are safe candidates for automatic cleanup.
with enriched as (
  select
    rp.*,
    concat_ws('|',
      case when rp.trip_code = 'camino2026' then 'camino-2026' else rp.trip_code end,
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

-- PREVIEW 2: possible duplicates that require manual review and are NOT cleaned automatically.
with enriched as (
  select
    rp.*,
    concat_ws('|',
      case when rp.trip_code = 'camino2026' then 'camino-2026' else rp.trip_code end,
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

-- SCHEMA AUDIT: test cleanup uses real data markers, not generated ids.
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in ('route_points', 'tickets', 'ticket_files')
  and column_name in ('id', 'type', 'title', 'from_place', 'to_place', 'note', 'booking_number', 'related_point_id', 'ticket_id', 'is_test')
order by table_name, ordinal_position;

-- PREVIEW 3: old test route points.
select id, trip_code, date, time, title, from_place, to_place, note
from public.route_points
where title like 'SYNC_TEST_%'
   or from_place = 'Supabase test'
   or to_place = 'Camino PWA'
   or note = 'Diagnostic test route point'
order by date, time, created_at;

-- CONTROL BEFORE TRANSACTION: route point counts by trip_code.
select trip_code, count(*) as route_points_count
from public.route_points
where trip_code in ('camino-2026', 'camino2026')
group by trip_code
order by trip_code;

-- CONTROL BEFORE TRANSACTION: old test route point count.
select count(*) as test_route_points_before
from public.route_points
where title like 'SYNC_TEST_%'
   or from_place = 'Supabase test'
   or to_place = 'Camino PWA'
   or note = 'Diagnostic test route point';

-- DRY RUN: build route_point_duplicate_map and show planned remaps. No DELETE.
begin;

drop table if exists route_point_duplicate_map_dry_run;
create temporary table route_point_duplicate_map_dry_run as
with enriched as (
  select
    rp.*,
    concat_ws('|',
      case when rp.trip_code = 'camino2026' then 'camino-2026' else rp.trip_code end,
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

select
  m.duplicate_id,
  m.canonical_id,
  coalesce(t.linked_tickets, 0) as linked_tickets,
  coalesce(tf.linked_files, 0) as linked_files
from route_point_duplicate_map_dry_run m
left join (
  select related_point_id, count(*) as linked_tickets
  from public.tickets
  group by related_point_id
) t on t.related_point_id = m.duplicate_id
left join (
  select ticket_id, count(*) as linked_files
  from public.ticket_files
  group by ticket_id
) tf on tf.ticket_id = m.duplicate_id
order by m.canonical_id, m.duplicate_id;

select
  rp.id as test_route_point_id,
  dm.canonical_id,
  coalesce(t.linked_tickets, 0) as linked_tickets,
  coalesce(tf.linked_files, 0) as linked_files,
  case
    when dm.canonical_id is not null then 'will relink to canonical route_point'
    when coalesce(t.linked_tickets, 0) = 0 and coalesce(tf.linked_files, 0) = 0 then 'orphan test route_point, safe to delete'
    else 'manual review: linked data exists but canonical route_point cannot be determined'
  end as dry_run_action
from public.route_points rp
left join route_point_duplicate_map_dry_run dm on dm.duplicate_id = rp.id
left join (
  select related_point_id, count(*) as linked_tickets
  from public.tickets
  group by related_point_id
) t on t.related_point_id = rp.id
left join (
  select ticket_id, count(*) as linked_files
  from public.ticket_files
  group by ticket_id
) tf on tf.ticket_id = rp.id
where rp.title like 'SYNC_TEST_%'
   or rp.from_place = 'Supabase test'
   or rp.to_place = 'Camino PWA'
   or rp.note = 'Diagnostic test route point'
order by dry_run_action, rp.created_at;

rollback;

-- TRANSACTION: collect maps, relink, verify, then delete route_points.
begin;

drop table if exists route_point_duplicate_map;
create temporary table route_point_duplicate_map as
with enriched as (
  select
    rp.*,
    concat_ws('|',
      case when rp.trip_code = 'camino2026' then 'camino-2026' else rp.trip_code end,
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

drop table if exists route_point_test_map;
create temporary table route_point_test_map as
select
  rp.id as test_route_point_id,
  dm.canonical_id,
  coalesce(t.linked_tickets, 0) as linked_tickets,
  coalesce(tf.linked_files, 0) as linked_files,
  (coalesce(t.linked_tickets, 0) = 0 and coalesce(tf.linked_files, 0) = 0) as is_orphan,
  (dm.canonical_id is null and (coalesce(t.linked_tickets, 0) > 0 or coalesce(tf.linked_files, 0) > 0)) as needs_manual_review
from public.route_points rp
left join route_point_duplicate_map dm on dm.duplicate_id = rp.id
left join (
  select related_point_id, count(*) as linked_tickets
  from public.tickets
  group by related_point_id
) t on t.related_point_id = rp.id
left join (
  select ticket_id, count(*) as linked_files
  from public.ticket_files
  group by ticket_id
) tf on tf.ticket_id = rp.id
where rp.title like 'SYNC_TEST_%'
   or rp.from_place = 'Supabase test'
   or rp.to_place = 'Camino PWA'
   or rp.note = 'Diagnostic test route point';

drop table if exists route_point_relink_map;
create temporary table route_point_relink_map as
select duplicate_id as source_id, canonical_id
from route_point_duplicate_map
where canonical_id is not null
union
select test_route_point_id as source_id, canonical_id
from route_point_test_map
where canonical_id is not null;

drop table if exists ticket_files_relinked_summary;
create temporary table ticket_files_relinked_summary as
with updated as (
  update public.ticket_files tf
  set ticket_id = m.canonical_id,
      updated_at = now()
  from route_point_relink_map m
  where tf.ticket_id = m.source_id
    and m.canonical_id is not null
  returning 1
)
select count(*) as ticket_files_relinked from updated;

drop table if exists tickets_relinked_summary;
create temporary table tickets_relinked_summary as
with updated as (
  update public.tickets t
  set related_point_id = m.canonical_id,
      updated_at = now()
  from route_point_relink_map m
  where t.related_point_id = m.source_id
    and m.canonical_id is not null
  returning 1
)
select count(*) as tickets_relinked from updated;

-- Verify remap counts before any route_point delete.
select
  (select ticket_files_relinked from ticket_files_relinked_summary) as ticket_files_relinked,
  (select tickets_relinked from tickets_relinked_summary) as tickets_relinked,
  (select count(*) from route_point_duplicate_map) as duplicate_route_points_planned_for_delete,
  (select count(*) from route_point_test_map where is_orphan and canonical_id is null) as orphan_test_route_points_planned_for_delete,
  (select count(*) from route_point_test_map where needs_manual_review) as manual_review_remaining;

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

drop table if exists route_points_deleted_summary;
create temporary table route_points_deleted_summary as
with deleted as (
  delete from public.route_points rp
  using route_point_duplicate_map m
  where rp.id = m.duplicate_id
    and m.canonical_id is not null
  returning 1
)
select count(*) as route_points_deleted from deleted;

drop table if exists test_records_deleted_summary;
create temporary table test_records_deleted_summary as
with deleted as (
  delete from public.route_points rp
  using route_point_test_map tm
  where rp.id = tm.test_route_point_id
    and tm.is_orphan
    and tm.canonical_id is null
  returning 1
)
select count(*) as test_records_deleted from deleted;

select
  (select route_points_deleted from route_points_deleted_summary) as route_points_deleted,
  (select tickets_relinked from tickets_relinked_summary) as tickets_relinked,
  (select ticket_files_relinked from ticket_files_relinked_summary) as ticket_files_relinked,
  (select test_records_deleted from test_records_deleted_summary) as test_records_deleted,
  (select count(*) from route_point_test_map where needs_manual_review) as manual_review_remaining;

select *
from route_point_test_map
where needs_manual_review
order by test_route_point_id;

commit;

-- CONTROL AFTER TRANSACTION: route point counts by trip_code.
select trip_code, count(*) as route_points_count
from public.route_points
where trip_code in ('camino-2026', 'camino2026')
group by trip_code
order by trip_code;

-- CONTROL AFTER TRANSACTION: old test route point count.
select count(*) as test_route_points_after
from public.route_points
where title like 'SYNC_TEST_%'
   or from_place = 'Supabase test'
   or to_place = 'Camino PWA'
   or note = 'Diagnostic test route point';

-- VERIFY: should stay stable after repeated app Download/Sync.
select count(*) as route_points_after_cleanup
from public.route_points
where trip_code = 'camino-2026';
