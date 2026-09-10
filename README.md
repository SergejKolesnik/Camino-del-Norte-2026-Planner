# Travel Planner

Офлайн-first PWA для планування окремих подорожей. Дані кожної подорожі зберігаються локально; Cloud Sync через Supabase є необов'язковим.

## Можливості

- маршрути, квитки, бюджет, щоденник, нотатки та чек-лист;
- JSON-експорт та імпорт;
- email/password авторизація Supabase для синхронізації між пристроями;
- файли в Supabase Storage bucket `travel-planner-files` або в локальному IndexedDB.

## Запуск

Відкрийте `index.html` через статичний вебсервер або GitHub Pages. Для Cloud Sync створіть Supabase-проєкт, застосуйте `supabase-email-auth-rls.sql`, а потім введіть URL і publishable key на екрані «Синхр.» та увійдіть через email.

## Безпека Cloud Sync

Усі таблиці мають `owner_id` і RLS-політики, які обмежують доступ поточним користувачем. Не додавайте service-role key до PWA.
