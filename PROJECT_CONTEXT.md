# Project Context

## Current Vision

Travel Planner is an offline-first PWA for managing multiple independent trips.

The original Camino del Norte 2026 planner remains the first built-in trip:

- code: `camino-2026`
- title: `Camino del Norte 2026`
- trip_type: `camino`

Future trips, such as `greece-2026`, should start empty and must not inherit Camino route points.

## Current Architecture

The application is intentionally simple:

- no build step;
- no frontend framework;
- single-page static app in `index.html`;
- PWA metadata in `manifest.json`;
- offline app shell in `service-worker.js`;
- local structured data in `localStorage`;
- local file/blob cache in IndexedDB;
- optional Supabase sync for multi-device usage.

Supabase is a sync layer, not the only runtime dependency. The app should remain usable offline.

## Active Trip Model

The app has a single runtime active trip:

```text
travelplanner_active_trip
```

If absent, it falls back to:

```text
camino-2026
```

Trip cards are stored locally in:

```text
travelplanner_trips
```

Camino uses legacy localStorage keys for backward compatibility:

```text
camino2026_route_points
camino2026_booking_records
camino2026_ticket_files
camino2026_diary_entries
camino2026_diary_files
camino2026_expenses
camino2026_notes
camino2026_serhii
camino2026_oksana
camino2026_vitaha
camino2026_shared
camino2026_med
camino2026_deleted_route_points
```

New trips use namespaced keys:

```text
travelplanner_<trip-code>_<dataset>
```

## Sync Model

Supabase URL/key are stored locally and are never hardcoded.

The active trip code is the source of truth for sync scope. Regular users should not have to edit `trip_code` manually.

Synced tables:

- `trips`
- `route_points`
- `tickets`
- `ticket_files`
- `diary_entries`
- `diary_files`
- `expenses`
- `notes`
- `checklists`

Files are stored in Supabase Storage bucket:

```text
camino-files
```

Ticket/document files use `ticket_files.ticket_id` as owner id. It can point either to a standalone `tickets.id` or a timeline `route_points.id`.

## Important Compatibility Decisions

- Existing Camino IDs are preserved.
- Existing Camino localStorage keys are not migrated.
- `camino2026` is normalized to `camino-2026`.
- Non-Camino trips do not receive the default Camino route.
- If the Supabase `trips` table does not yet have metadata columns, the app falls back to upserting only `code`, `title`, and `updated_at`.
- Optional migration for trip metadata: `supabase-trips-metadata.sql`.

## Recently Completed

- Multi-trip selector screen: `Мої подорожі`.
- Trip creation form.
- Active trip local state.
- Local data isolation by active trip.
- PWA renamed from Camino-specific app name to `Travel Planner`.
- Sync config fallback fix so URL/key are not erased when autosync runs outside the Sync screen.

## Known Risks

- The repository name and GitHub Pages URL are still Camino-specific:
  `SergejKolesnik/Camino-del-Norte-2026-Planner`.
- Full interactive browser/mobile verification should still be repeated after major PWA changes.
- Installed PWA name/icon updates may require app reinstall or service worker refresh on some devices.
- Trip list sync is basic: trips can be read from Supabase, but the trip lifecycle can still be improved.
- Supabase schema may vary between devices/projects, so migrations should be run deliberately, not automatically.

## Recommended Next Work

1. Verify installed PWA update behavior on Android/iPhone/Windows.
2. Improve cloud lifecycle for `trips`: create/update trip on one device, pull it cleanly on another.
3. Add explicit edit/delete controls for trips.
4. Add diagnostics for active trip local key usage.
5. Consider renaming the GitHub repository later if the product is no longer Camino-branded.

Do not add new major planner features until multi-trip sync has been tested on at least two devices.
