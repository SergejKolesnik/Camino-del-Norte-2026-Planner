# Route point sync audit

## Root cause

`route_points` could duplicate because:

- the default route used random ids on restore/new install, so the same route on another device looked like new records;
- `uploadLocalToCloud()` replaced cloud `route_points` instead of doing an id-stable upsert;
- Supabase test records created route points and did not remove them;
- empty or nearly empty route points could be uploaded;
- legacy `camino2026` and canonical `camino-2026` trip codes could split the same trip.

## Current write path

All cloud writes to `route_points` go through:

```js
upsertRoutePointsToSupabase(client, tripCode, points)
```

This function:

- normalizes `tripCode` to `camino-2026`;
- removes local duplicate ids before upload;
- skips empty route points;
- converts empty strings to `null`;
- uses Supabase `upsert(..., { onConflict: "id" })`;
- logs local count, unique payload count, cloud before/after, inserted/updated, duplicates prevented, and empty skipped.

Direct `cloudUpsert(client, "route_points", ...)` is reserved against new use. Test writes call the unified route upsert and then delete their test rows.

## Local data protections

- Base route ids are deterministic via `stableBaseRoutePointId()`.
- `saveRoutePoints()` normalizes and filters route points.
- `savePoint()` rejects empty records and auto-generates a title from `from → to`.
- `dedupeRoutePoints()` merges by id and only performs semantic merge when it is safe.
- Semantic duplicates with no time and different notes, or with files/tickets on both records, are left for manual review.

## Supabase cleanup

Use `supabase-route-point-integrity.sql`:

1. Run preview query.
2. Review manual-review candidates.
3. Run the transaction.
4. Run app Download/Sync repeatedly and confirm cloud count stays stable.
