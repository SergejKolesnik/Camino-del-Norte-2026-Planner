# Travel Planner instructions

Keep all user-facing data scoped to the active trip. The app is local-first; Cloud Sync is opt-in and must use authenticated Supabase access with owner-based RLS. Never place a service-role key in browser code.
