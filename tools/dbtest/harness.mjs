// PGlite harness: loads the Supabase migrations into an embedded Postgres so the
// rules engine can be tested without a Supabase project. Mocks the bits of the
// Supabase platform the SQL touches (auth schema, roles).
import { PGlite } from '@electric-sql/pglite';
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
export const MIGRATIONS = join(here, '..', '..', 'supabase', 'migrations');

const PLATFORM_MOCK = `
  create schema if not exists auth;
  create table if not exists auth.users (
    id uuid primary key default gen_random_uuid(),
    email text unique,
    raw_user_meta_data jsonb default '{}',
    created_at timestamptz default now()
  );
  -- current user is driven by a session setting so tests can "sign in" as anyone
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
  $$;
  create or replace function auth.role() returns text language sql stable as $$
    select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), 'anon')
  $$;
  do $$ begin
    if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
    if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
    if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin; end if;
  end $$;
`;

export async function loadDb({ skipPlatformFiles = true, log = () => {}, dataDir = null } = {}) {
  // dataDir persists the database across runs (used by the local pipeline runner); migrations are idempotent, so re-applying is safe
  const db = dataDir ? new PGlite(dataDir) : new PGlite();
  await db.exec(PLATFORM_MOCK);
  const files = readdirSync(MIGRATIONS).filter(f => f.endsWith('.sql')).sort();
  for (const f of files) {
    if (skipPlatformFiles && f.includes('platform')) { log(`skip ${f}`); continue; }
    const sql = readFileSync(join(MIGRATIONS, f), 'utf8');
    log(`apply ${f}`);
    try { await db.exec(sql); }
    catch (e) { throw new Error(`Migration ${f} failed: ${e.message}`); }
  }
  return db;
}

export async function signIn(db, userId, role = 'authenticated') {
  await db.exec(`select set_config('request.jwt.claim.sub', '${userId ?? ''}', false);
                 select set_config('request.jwt.claim.role', '${role}', false);`);
}

export async function createUser(db, email, displayName) {
  const r = await db.query(
    `insert into auth.users(email, raw_user_meta_data) values ($1, $2) returning id`,
    [email, { display_name: displayName }]);
  return r.rows[0].id;
}
