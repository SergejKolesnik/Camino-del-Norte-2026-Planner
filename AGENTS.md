# Repository Instructions

## Product Direction

This project is now a universal offline-first Travel Planner PWA.

Camino del Norte 2026 is the first built-in trip, not the whole product.

Core product rule: every user-facing dataset must be scoped by the active trip. Do not let data from `camino-2026` leak into `greece-2026` or any future trip.

## Architecture

- Static PWA without a frontend framework.
- Main application file: `index.html`.
- PWA metadata: `manifest.json`.
- Offline shell cache: `service-worker.js`.
- Local text data: `localStorage`.
- Local file/blob cache: IndexedDB.
- Optional cloud sync: Supabase tables plus Storage bucket `camino-files`.

## Trip Context

- Canonical built-in trip: `camino-2026`.
- Legacy Camino localStorage prefix: `camino2026`.
- Active trip key: `travelplanner_active_trip`.
- Trip registry key: `travelplanner_trips`.
- New trip localStorage prefix: `travelplanner_<trip-code>`.

When adding or changing data logic, always verify that these datasets are scoped to the active trip:

- `route_points`
- `tickets`
- `ticket_files`
- `diary_entries`
- `diary_files`
- `expenses`
- `notes`
- `checklists`
- route point tombstones

## Sync Rules

- Supabase URL/key must never be hardcoded.
- Regular sync must use the active trip code.
- The visible Trip Code field in Sync is diagnostic/advanced only.
- Do not reintroduce full cloud replace for user data. Prefer upsert plus soft delete.
- Preserve `deleted_at` semantics for multi-device deletion.
- Do not assume `tickets.route_point_id` exists; linked tickets use `related_point_id`.
- `ticket_files.ticket_id` can point to either `tickets.id` or `route_points.id`.

## Backward Compatibility

- Do not migrate existing Camino localStorage keys unless explicitly requested.
- Keep existing Camino route point IDs stable.
- Do not regenerate the base Camino route for non-Camino trips.
- Preserve existing IndexedDB file caches where practical.
- If Supabase `trips` only has `code`, `title`, `created_at`, and `updated_at`, the app must keep working.

## Development Workflow

Before editing:

1. Check the actual repo path.
2. Check remote, branch, and `git status`.
3. Fetch/pull remote state when safe.
4. Use a feature branch for multi-file, data-sensitive, or architectural changes.

Validation:

- Run a JavaScript parse check when possible.
- Run `git diff --check`.
- Serve locally with `python -m http.server <port>` and verify `index.html`, `manifest.json`, and `service-worker.js` return HTTP 200.
- For PWA changes, bump `CACHE_NAME` in `service-worker.js`.

Git:

- Commit with a clear message.
- Push feature branches after coherent work.
- Direct push to `main` requires explicit user confirmation.
- Never merge into `main` without user confirmation.

## Documentation

Update `README.md` or `PROJECT_CONTEXT.md` whenever the product model, sync model, storage keys, deployment process, or current priorities change.

Do not commit credentials, anon keys, service-role keys, `.env` files, exports with private data, or downloaded production data.
