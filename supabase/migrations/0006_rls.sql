-- Flying Cobra · 0006 row-level security & grants
-- Principle: users read their own rows; cards are issued only by SECURITY DEFINER functions; the only public read is lookup_serial().

alter table profiles        enable row level security;
alter table config          enable row level security;
alter table age_factors     enable row level security;
alter table seasons         enable row level security;
alter table regions         enable row level security;
alter table animals         enable row level security;
alter table animal_counters enable row level security;
alter table animal_rules    enable row level security;
alter table rule_history    enable row level security;
alter table runs            enable row level security;
alter table run_tracks      enable row level security;
alter table user_cells      enable row level security;
alter table user_areas      enable row level security;
alter table user_regions    enable row level security;
alter table user_states     enable row level security;
alter table cards           enable row level security;
alter table bonds           enable row level security;
alter table pity_state      enable row level security;
alter table tier_history    enable row level security;
alter table events          enable row level security;

-- helper to (re)create policies idempotently
create or replace function _policy(p_name text, p_table text, p_cmd text, p_using text, p_check text default null) returns void language plpgsql as $$
begin
  execute format('drop policy if exists %I on %I', p_name, p_table);
  if p_cmd = 'insert' then
    execute format('create policy %I on %I for insert with check (%s)', p_name, p_table, coalesce(p_check, p_using));
  elsif p_cmd = 'update' then
    execute format('create policy %I on %I for update using (%s) with check (%s)', p_name, p_table, p_using, coalesce(p_check, p_using));
  else
    execute format('create policy %I on %I for %s using (%s)', p_name, p_table, p_cmd, p_using);
  end if;
end $$;

-- profiles: self read/update (display_name, birth_year, sex, home_region, timezone, connected); admins read all
select _policy('profiles_self_select', 'profiles', 'select', 'id = auth.uid() or is_admin()');
select _policy('profiles_self_update', 'profiles', 'update', 'id = auth.uid()', 'id = auth.uid() and is_admin = (select is_admin from profiles p where p.id = auth.uid())');

-- reference data: readable by signed-in users, writable by admins
select _policy('config_read',      'config',      'select', 'auth.role() in (''authenticated'',''service_role'')');
select _policy('config_admin',     'config',      'all',    'is_admin()');
select _policy('age_read',         'age_factors', 'select', 'auth.role() in (''authenticated'',''service_role'')');
select _policy('age_admin',        'age_factors', 'all',    'is_admin()');
select _policy('seasons_read',     'seasons',     'select', 'true');
select _policy('seasons_admin',    'seasons',     'all',    'is_admin()');
select _policy('regions_read',     'regions',     'select', 'true');
select _policy('regions_admin',    'regions',     'all',    'is_admin()');
select _policy('rules_read',       'animal_rules','select', 'is_admin()');          -- recipes are never exposed to players (discovery-first)
select _policy('rules_admin',      'animal_rules','all',    'is_admin()');
select _policy('history_admin',    'rule_history','select', 'is_admin()');
select _policy('counters_read',    'animal_counters','select', 'auth.role() in (''authenticated'',''service_role'') or is_admin()');

-- animals: encyclopedia visible to signed-in users, but secret animals only once earned (or to admins)
select _policy('animals_read', 'animals', 'select',
  'is_admin() or (is_active and (not is_secret or exists (select 1 from cards c where c.animal_id = animals.id and c.user_id = auth.uid())))');
select _policy('animals_admin', 'animals', 'all', 'is_admin()');

-- personal data: owner only (admins may read runs/cards for support)
select _policy('runs_self',        'runs',        'select', 'user_id = auth.uid() or is_admin()');
select _policy('tracks_self',      'run_tracks',  'select', 'user_id = auth.uid()');
select _policy('cells_self',       'user_cells',  'select', 'user_id = auth.uid()');
select _policy('areas_self',       'user_areas',  'select', 'user_id = auth.uid()');
select _policy('uregions_self',    'user_regions','select', 'user_id = auth.uid()');
select _policy('states_self',      'user_states', 'select', 'user_id = auth.uid()');
select _policy('cards_self',       'cards',       'select', 'user_id = auth.uid() or is_admin()');
select _policy('cards_visibility', 'cards',       'update', 'user_id = auth.uid()', 'user_id = auth.uid()');  -- toggle is_public only (trigger below)
select _policy('bonds_self',       'bonds',       'select', 'user_id = auth.uid()');
select _policy('pity_self',        'pity_state',  'select', 'user_id = auth.uid()');
select _policy('tiers_self',       'tier_history','select', 'user_id = auth.uid()');
select _policy('events_self',      'events',      'select', 'user_id = auth.uid()');
select _policy('events_seen',      'events',      'update', 'user_id = auth.uid()');

-- a player can only ever change is_public on their card
create or replace function cards_restrict_update() returns trigger language plpgsql as $$
begin
  if not is_admin() and (new.animal_id, new.serial_no, new.scope, new.period_key, new.stage, new.finish, new.stats, new.user_id, new.run_id, new.season_id, new.tier, new.verdict, new.issued_at)
     is distinct from (old.animal_id, old.serial_no, old.scope, old.period_key, old.stage, old.finish, old.stats, old.user_id, old.run_id, old.season_id, old.tier, old.verdict, old.issued_at) then
    raise exception 'cards are immutable' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists cards_restrict on cards;
create trigger cards_restrict before update on cards for each row execute function cards_restrict_update();

-- ---------- grants ----------
grant usage on schema public to anon, authenticated, service_role;
grant select on profiles, config, age_factors, seasons, regions, animals, animal_counters, animal_rules, rule_history,
                runs, run_tracks, user_cells, user_areas, user_regions, user_states, cards, bonds, pity_state, tier_history, events
  to authenticated;
grant update (display_name, birth_year, sex, home_region, timezone, connected, updated_at) on profiles to authenticated;
grant update (is_public) on cards to authenticated;
grant update (seen_at) on events to authenticated;
grant all on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;
-- admins write through RLS 'all' policies; the table grant is what lets the policy apply
grant insert, update, delete on config, age_factors, seasons, regions, animals, animal_rules to authenticated;

-- functions: only the intended entry points are callable by clients
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function lookup_serial(text) to anon, authenticated;
grant execute on function submit_run(jsonb) to authenticated;
grant execute on function claim_pending_cards() to authenticated;
grant execute on function mark_events_seen(bigint[]) to authenticated;
grant execute on function admin_simulate_pool(jsonb, uuid) to authenticated;
grant execute on function admin_perf_preview(numeric, numeric, sex_t, int) to authenticated;
grant execute on function is_admin() to anon, authenticated;
grant execute on function card_json(cards) to authenticated;
grant execute on function age_factor(sex_t, int), v_std_kmh(sex_t, numeric), perf_index(numeric, numeric, sex_t, int), speed_band(numeric) to authenticated;
grant execute on all functions in schema public to service_role;
