-- Flying Cobra · 0001 schema
-- Core tables. Everything the card logic needs is linked: users → runs → cards → animals (+ serial counters).
-- Rules are data (animal_rules, config), never code.

-- gen_random_uuid() is built into Postgres 13+; pgcrypto only needed on older servers
do $$ begin create extension if not exists pgcrypto; exception when others then null; end $$;

-- ---------- enums ----------
do $$ begin
  create type rarity_t as enum ('common','uncommon','rare','epic','legendary');
exception when duplicate_object then null; end $$;

do $$ begin
  create type stage_t as enum ('baby','young','adult');
exception when duplicate_object then null; end $$;

do $$ begin
  create type finish_t as enum ('plain','glow','radiant');
exception when duplicate_object then null; end $$;

do $$ begin
  create type card_scope_t as enum ('run','weekly','monthly');
exception when duplicate_object then null; end $$;

do $$ begin
  create type verdict_t as enum ('verified','unverified','rejected');
exception when duplicate_object then null; end $$;

do $$ begin
  create type sex_t as enum ('male','female');
exception when duplicate_object then null; end $$;

-- ---------- profiles ----------
create table if not exists profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  display_name    text not null default 'Runner',
  birth_year      int  check (birth_year is null or birth_year between 1900 and 2100),
  sex             sex_t,                               -- optional, age-grading only, never shown
  home_region     text,                                -- ISO 3166-2:IN code, user-chosen in settings
  timezone        text not null default 'Asia/Kolkata',
  connected       text[] not null default '{}',        -- granted purposes: location, motion, steps, heart_rate, activity, elevation
  is_admin        boolean not null default false,
  last_run_at     timestamptz,
  last_migratory_at timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ---------- configuration (every tunable number) ----------
create table if not exists config (
  key         text primary key,
  value       jsonb not null,
  description text,
  updated_at  timestamptz not null default now(),
  updated_by  uuid
);

create table if not exists age_factors (
  sex     sex_t not null,
  age     int   not null,
  factor  numeric(5,3) not null check (factor > 0 and factor <= 1.2),
  primary key (sex, age)
);

create table if not exists seasons (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,                 -- "Monsoon 2026"
  slug       text not null unique,
  starts_on  date not null,
  ends_on    date not null,
  palette    jsonb not null default '{}',   -- {"primary":"#..","accent":"#.."}
  is_active  boolean not null default true,
  check (ends_on >= starts_on)
);

create table if not exists regions (
  code      text primary key,               -- IN-KA
  name      text not null,
  kind      text not null default 'state',  -- state | ut | country
  min_lat   numeric(8,5), max_lat numeric(8,5),
  min_lon   numeric(8,5), max_lon numeric(8,5),
  centroid_lat numeric(8,5), centroid_lon numeric(8,5)
);

-- ---------- animals ----------
create table if not exists animals (
  id            uuid primary key default gen_random_uuid(),
  slug          text not null unique,        -- 'cheetah'
  code          text not null unique,        -- 'CHT' (serial prefix for typed lookups)
  name          text not null,               -- 'Cheetah'
  family        text not null,               -- swift|steady|calm|gentle|time|explorer|regional|migratory|weekly|secret|national
  rarity        rarity_t not null default 'common',
  flavour_line  text not null default '',    -- "the tireless traveller"
  encyclopedia  jsonb not null default '{}', -- {"facts":[...],"habitat":"...","size":"...","speed":"..."}
  art           jsonb not null default '{}', -- {"baby":"path","young":"path","adult":"path"} in Storage bucket card-art
  palette       jsonb not null default '{}', -- {"bg":"#..","fg":"#.."}
  is_secret     boolean not null default false,
  is_active     boolean not null default true,
  sort_order    int not null default 100,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table if not exists animal_counters (
  animal_id    uuid primary key references animals(id) on delete cascade,
  next_serial  int not null default 0
);

create table if not exists animal_rules (
  id                     uuid primary key default gen_random_uuid(),
  animal_id              uuid not null references animals(id) on delete cascade,
  scope                  card_scope_t not null default 'run',
  tier                   int not null default 0,          -- 0 speed, 1 time, 2 explorer, 3 state souvenir, 4 migratory
  predicates             jsonb not null default '{}',
  weight                 numeric(8,3) not null default 1.0,
  first_time_guaranteed  boolean not null default true,  -- tiers 1-4: guaranteed the first time the trigger ever happens
  repeat_probability     numeric(4,3) not null default 1.0 check (repeat_probability between 0 and 1),
  note                   text,
  is_active              boolean not null default true,
  updated_at             timestamptz not null default now()
);
create index if not exists animal_rules_scope_idx on animal_rules(scope, tier) where is_active;

create table if not exists rule_history (
  id          bigserial primary key,
  table_name  text not null,
  row_id      text not null,
  action      text not null,
  old_row     jsonb,
  new_row     jsonb,
  changed_by  uuid,
  changed_at  timestamptz not null default now()
);

-- ---------- runs ----------
create table if not exists runs (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references profiles(id) on delete cascade,
  client_run_id   text,
  source          text not null default 'phone',        -- phone | healthkit | health_connect | seed
  started_at      timestamptz not null,
  ended_at        timestamptz not null,
  timezone        text not null default 'Asia/Kolkata',
  local_date      date not null,
  distance_m      numeric(10,1) not null,
  flat_eq_m       numeric(10,1) not null,
  moving_s        int not null,
  elapsed_s       int not null,
  avg_speed_kmh   numeric(6,2) not null,
  max_1min_kmh    numeric(6,2),
  elev_gain_m     numeric(8,1) default 0,
  steps           int,
  splits_kmh      jsonb,                                 -- [11.2, 11.8, ...] per km
  accel           jsonb,                                 -- {"rhythm_ratio":0.8,"vertical_rms":3.1}
  activity        jsonb,                                 -- {"running":0.8,...}
  hr              jsonb,                                 -- {"mean":145,"max":172}
  centroid_lat    numeric(9,6),
  centroid_lon    numeric(9,6),
  state_code      text references regions(code),
  gh4             text,
  gh5             text,
  cells           text[] not null default '{}',          -- geohash-7 cells
  turns_per_km    numeric(6,2),
  novelty         numeric(4,3),
  flags           text[] not null default '{}',          -- new_route, untraced, zigzag, new_area, new_state, migratory_2, migratory_3, explorer
  time_window     text,                                  -- dawn | day | dusk | night
  sunrise_at      timestamptz,
  sunset_at       timestamptz,
  perf_index      numeric(5,3),
  speed_band      text,
  trust_score     numeric(4,3),
  trust_detail    jsonb,
  verdict         verdict_t not null default 'verified',
  eligible        boolean not null default false,            -- passed the §1 floor and not rejected → counts for weekly/monthly
  created_at      timestamptz not null default now(),
  unique (user_id, client_run_id)
);
create index if not exists runs_user_date_idx on runs(user_id, local_date desc);
create index if not exists runs_user_started_idx on runs(user_id, started_at desc);

-- Private track, separate so it can never leak through a card/stat query.
create table if not exists run_tracks (
  run_id    uuid primary key references runs(id) on delete cascade,
  user_id   uuid not null references profiles(id) on delete cascade,
  points    jsonb not null                               -- [[lat,lon,alt,t,acc],...]
);

create table if not exists user_cells (
  user_id    uuid not null references profiles(id) on delete cascade,
  cell       text not null,
  first_seen timestamptz not null default now(),
  last_seen  timestamptz not null default now(),
  run_count  int not null default 1,
  primary key (user_id, cell)
);
create table if not exists user_areas (
  user_id    uuid not null references profiles(id) on delete cascade,
  gh5        text not null,
  run_count  int not null default 1,
  primary key (user_id, gh5)
);
create table if not exists user_regions (
  user_id     uuid not null references profiles(id) on delete cascade,
  gh4         text not null,
  run_count   int not null default 1,
  primary key (user_id, gh4)
);
create table if not exists user_states (
  user_id       uuid not null references profiles(id) on delete cascade,
  state_code    text not null references regions(code),
  first_run_at  timestamptz not null default now(),
  run_count     int not null default 1,
  souvenir_cards int not null default 0,
  primary key (user_id, state_code)
);

-- ---------- cards ----------
create table if not exists cards (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  animal_id   uuid not null references animals(id),
  serial_no   int not null,
  scope       card_scope_t not null,
  period_key  text not null,                 -- run id | 2026-W40 | 2026-10
  tier        int not null default 0,
  stage       stage_t not null,
  finish      finish_t not null default 'plain',
  season_id   uuid references seasons(id),
  run_id      uuid references runs(id) on delete set null,
  stats       jsonb not null default '{}',   -- PUBLIC-SAFE only: distance_km, duration_s, pace_s_per_km, run_days, volume_km
  verdict     verdict_t not null default 'verified',
  is_public   boolean not null default true,
  issued_at   timestamptz not null default now(),
  unique (animal_id, serial_no),
  unique (user_id, scope, period_key)
);
create index if not exists cards_user_idx on cards(user_id, issued_at desc);
create index if not exists cards_animal_idx on cards(animal_id, serial_no);

create table if not exists bonds (
  user_id      uuid not null references profiles(id) on delete cascade,
  animal_id    uuid not null references animals(id) on delete cascade,
  earn_count   int not null default 0,
  earn_weeks   int not null default 0,
  last_week    text,
  stage        stage_t not null default 'baby',
  mastered     boolean not null default false,
  updated_at   timestamptz not null default now(),
  primary key (user_id, animal_id)
);

create table if not exists pity_state (
  user_id           uuid primary key references profiles(id) on delete cascade,
  cards_since_rare  int not null default 0,
  updated_at        timestamptz not null default now()
);

create table if not exists tier_history (
  user_id    uuid not null references profiles(id) on delete cascade,
  trigger    text not null,                  -- time:night, explorer, state:IN-KL, migratory
  first_at   timestamptz not null default now(),
  count      int not null default 1,
  primary key (user_id, trigger)
);

create table if not exists events (
  id         bigserial primary key,
  user_id    uuid not null references profiles(id) on delete cascade,
  kind       text not null,                  -- card_issued | growth | mastered | weekly_card | monthly_card | run_rejected | run_unverified
  payload    jsonb not null default '{}',
  created_at timestamptz not null default now(),
  seen_at    timestamptz
);
create index if not exists events_user_unseen_idx on events(user_id) where seen_at is null;

-- ---------- updated_at triggers ----------
create or replace function set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

do $$ declare t text; begin
  foreach t in array array['profiles','animals','animal_rules','bonds','config'] loop
    execute format('drop trigger if exists %I_updated_at on %I', t, t);
    execute format('create trigger %I_updated_at before update on %I for each row execute function set_updated_at()', t, t);
  end loop;
end $$;

-- ---------- audit trigger for data-driven rules ----------
create or replace function audit_rules() returns trigger language plpgsql security definer as $$
declare rid text;
begin
  rid := coalesce((to_jsonb(coalesce(new, old))->>'id'), (to_jsonb(coalesce(new, old))->>'key'), (to_jsonb(coalesce(new, old))->>'code'),
                  (to_jsonb(coalesce(new, old))->>'sex') || ':' || (to_jsonb(coalesce(new, old))->>'age'),
                  md5(to_jsonb(coalesce(new, old))::text));
  insert into rule_history(table_name, row_id, action, old_row, new_row, changed_by)
  values (tg_table_name, rid, tg_op, to_jsonb(old), to_jsonb(new), auth.uid());
  return coalesce(new, old);
end $$;

do $$ declare t text; begin
  foreach t in array array['animals','animal_rules','config','seasons','age_factors','regions'] loop
    execute format('drop trigger if exists %I_audit on %I', t, t);
    execute format('create trigger %I_audit after insert or update or delete on %I for each row execute function audit_rules()', t, t);
  end loop;
end $$;

-- ---------- auto-create profile on signup ----------
create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles(id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', 'Runner'))
  on conflict (id) do nothing;
  insert into pity_state(user_id) values (new.id) on conflict do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

-- ---------- counters auto-created per animal ----------
create or replace function ensure_counter() returns trigger language plpgsql as $$
begin
  insert into animal_counters(animal_id) values (new.id) on conflict do nothing;
  return new;
end $$;
drop trigger if exists animals_counter on animals;
create trigger animals_counter after insert on animals for each row execute function ensure_counter();
