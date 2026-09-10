# Контекст проєкту

Travel Planner — статичний offline-first застосунок для кількох незалежних подорожей.

Дані мають бути ізольовані кодом активної подорожі. Нова подорож починається порожньою та має префікс localStorage `travelplanner_<trip-code>_`.

Cloud Sync є opt-in. Він використовує email/password Supabase Auth, RLS з `owner_id` для всіх таблиць і bucket `travel-planner-files` для вкладень. У браузер можна додавати лише URL і publishable key Supabase.
