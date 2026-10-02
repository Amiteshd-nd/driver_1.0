# Manual tasks for Amitesh

Things only you can do (accounts, downloads, keys). Work top to bottom; tick as you go. Everything else is built and waiting for these.

## 1. Create the Supabase project (≈ 10 minutes)

1. Go to https://supabase.com → **Start your project** → sign in with GitHub or email.
2. Click **New project**. Organization: your personal one. Name: `pugmark`. Database password: click **Generate a password** and save it in your password manager (you will rarely need it). Region: **Mumbai (ap-south-1)** — closest to users in India. Click **Create new project** and wait ~2 minutes.
3. In the left sidebar click **Project Settings** (gear) → **API**. Copy three things into a note:
   - **Project URL** (looks like `https://abcdefgh.supabase.co`)
   - **anon public** key (long string starting `eyJ…`) — safe to ship in the app
   - **service_role** key — SECRET; never paste into the app, only into the SQL editor steps below if asked
4. Paste the Project URL and anon key into `app/.env` (copy `app/.env.example` to `app/.env` first; the file has two lines, replace the placeholders). Also paste them into `web/marketing/verify-config.js` (two lines).

## 2. Run the database migrations (≈ 5 minutes)

In the Supabase dashboard: left sidebar → **SQL Editor** → **New query**. For each file below, open it from this project in any text editor, select all, copy, paste into the SQL editor, click **Run**. Do them **in this order**; each should end with "Success. No rows returned".

1. `supabase/migrations/0001_schema.sql`
2. `supabase/migrations/0002_math.sql`
3. `supabase/migrations/0003_engine.sql`
4. `supabase/migrations/0004_seed_config.sql`
5. `supabase/migrations/0005_seed_animals.sql`
6. `supabase/migrations/0006_rls.sql`
7. `supabase/migrations/0007_seed_dummy_users.sql`
8. `supabase/migrations/0008_platform.sql` (if it complains about `pg_cron`, go to **Database → Extensions**, enable `pg_cron`, run the file again; it is optional)
9. `supabase/migrations/0009_account.sql`

Then, still in the SQL editor, run this to create the six dummy play-test users:

```sql
select seed_dummy_users();
```

You should see a JSON blob mentioning Arjun, Meera, Ravi, Priya, Kabir and Sana. Their emails are `arjun@pugmark.test` … `sana@pugmark.test`; the password for all six is written at the top of `supabase/migrations/0007_seed_dummy_users.sql`. Delete these accounts before public launch (Authentication → Users).

## 3. Make yourself admin (1 minute)

1. Sign up in the app (or Authentication → Users → **Add user** with your email) once the app runs.
2. SQL editor:
```sql
update profiles set is_admin = true where id = (select id from auth.users where email = 'amitesh.debnath@netradyne.com');
```
(Use whichever email you signed up with.)

## 4. Auth settings (3 minutes) and providers (optional)

Dashboard → **Authentication → URL Configuration** → under **Redirect URLs** click **Add URL** and add `pugmark://login` (the app's magic-link return address). For the internal web build also add `http://localhost:*/**`.

Then **Authentication → Providers**. Email is on by default (magic links work immediately). For **Apple** and **Google** sign-in follow the on-screen instructions; both need developer accounts. Skip for internal testing.

## 5. Install Flutter on this Mac (≈ 20 minutes, one time)

The Mac currently has no Flutter, Xcode, or Homebrew. Easiest path:

1. Install **Xcode** from the Mac App Store (large download). Open it once and accept the licence. Then in Terminal:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -runFirstLaunch
   ```
2. Install Flutter: go to https://docs.flutter.dev/get-started/install/macos/mobile-ios and download the **Flutter SDK zip for Apple Silicon (or Intel)**. Unzip it into `~/development/flutter`. Then run:
   ```bash
   echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc && flutter doctor
   ```
3. For Android testing also install **Android Studio** (https://developer.android.com/studio) and, inside it, the Android SDK + an emulator. `flutter doctor --android-licenses` afterwards.
4. Tell Claude "Flutter is installed" — Claude will then run `flutter pub get`, `flutter analyze`, fix any compile errors, and launch the app in the simulator.

## 6. Deploy the verify page (10 minutes, needs the Supabase CLI)

The public verify page is a Supabase Edge Function. Install the CLI with `npm install -g supabase` (Node is already on this Mac), then in Terminal from the project folder:

```bash
supabase login
```
```bash
supabase link --project-ref YOUR-PROJECT-REF
```
(the ref is the part before `.supabase.co` in your Project URL)
```bash
supabase secrets set SUPABASE_URL=https://YOUR-PROJECT.supabase.co SUPABASE_ANON_KEY=YOUR-ANON-KEY
```
```bash
supabase functions deploy verify --no-verify-jwt
```
Your verify URL base is then `https://YOUR-PROJECT.supabase.co/functions/v1/verify`. Paste it into the admin panel → Config → `app` → `verify_base_url` so QR codes point there.

## 7. Domain for verify links (later)

Buy a short domain (e.g. `pugmark.run`) and point it at the marketing site host. Until then verify URLs use the Supabase Edge Function URL; update `config.app → verify_base_url` in the admin panel when the domain is live.

## 8. Card art (later)

Commission or generate original illustrations: 3 poses (baby / young / adult) per animal, 1200 × 1200 PNG with transparent background. Upload via the admin panel (Animals → edit → art) which stores them in the `card-art` bucket. Until then every card shows the procedural placeholder.

---

### Status log
- 2026-10-02: Database engine (9 migrations, 40 passing PGlite tests), algorithm/design/API/architecture docs, Flutter app source (61 files: player app + admin panel, uncompiled), marketing site + verify page (rendered and checked in a browser) — all built without a Supabase project or Flutter SDK present. Steps 1–6 above unblock running it.
