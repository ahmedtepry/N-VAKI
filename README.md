# NŌVAKI

Fashion store for Android: a clothes-rack storefront for customers and a live dashboard for the team that serves them.

| Part | Where | Tech |
|---|---|---|
| Android app (customers + team dashboard) | `app/` | Flutter · Supabase · Arabic (RTL) + English |
| Database, permissions, automation | `supabase/migrations/` | PostgreSQL + RLS + PL/pgSQL |
| APK build | `.github/workflows/build-apk.yml` | GitHub Actions |

## How it works
* **Storefront:** a horizontal rack of garments hanging on hangers; tap a piece to see it large, swap colours with the hang-tags, pick a size, add to bag. Cash on delivery.
* **Accounts:** email + password. The first account created with the owner email (see `app_settings.owner_email`) becomes the **owner**.
* **Team dashboard** (Account → Team dashboard): overview numbers, orders, customer inbox, catalog & stock, team management. Roles: `owner`, `manager`, `support`, `fulfillment`.
* **Runs by itself:** new orders and customer chats are routed automatically to the least-busy online teammate; customers get notifications on every status change; an automatic reply covers off-hours; stock is locked and restored atomically.
* **Add a teammate:** they create an account in the app, then the owner enters their email in Team and picks a role.

## Build the APK
Push to `main` (or run the workflow manually). The signed APK is attached to the latest GitHub Release and to the run's artifacts.
For updates that install over the previous version, add the repository secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`; without them each build uses a temporary key.

## Backend
Apply `supabase/migrations/*.sql` in order, then deploy `supabase/functions/novaki-signup` (creates accounts without a confirmation email).
