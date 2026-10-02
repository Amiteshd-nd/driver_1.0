-- Pugmark · 0003 rules engine
-- Server-authoritative. The client submits a run; the database decides eligibility, trust, pool, draw,
-- serial number and growth. A modified client cannot forge a card.
-- Spec: docs/ALGORITHMS.md

-- ---------- identity helpers ----------
create or replace function is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from profiles where id = auth.uid()), false)
$$;

create or replace function week_key(d date) returns text language sql immutable as $$
  select to_char(d, 'IYYY-"W"IW')
$$;
create or replace function week_start(d date) returns date language sql immutable as $$
  select (d - ((extract(isodow from d)::int) - 1))::date
$$;

create or replace function active_season(d date) returns uuid language sql stable as $$
  select id from seasons where is_active and d between starts_on and ends_on order by starts_on desc limit 1
$$;

-- ---------- §6.1 predicate matching ----------
-- ctx keys: speed_band, distance_km, time_window, flags[], state_code, run_days, connected[], moving_s, volume_km, variety
create or replace function rule_matches(p jsonb, ctx jsonb) returns boolean language plpgsql immutable as $$
declare arr text[]; x text;
begin
  if p ? 'speed_bands' then
    select array_agg(v) into arr from jsonb_array_elements_text(p->'speed_bands') v;
    if not (coalesce(ctx->>'speed_band','') = any(arr)) then return false; end if;
  end if;
  if p ? 'min_km' and coalesce((ctx->>'distance_km')::numeric, 0) < (p->>'min_km')::numeric then return false; end if;
  if p ? 'max_km' and coalesce((ctx->>'distance_km')::numeric, 0) > (p->>'max_km')::numeric then return false; end if;
  if p ? 'min_moving_s' and coalesce((ctx->>'moving_s')::numeric, 0) < (p->>'min_moving_s')::numeric then return false; end if;
  if p ? 'time_windows' then
    select array_agg(v) into arr from jsonb_array_elements_text(p->'time_windows') v;
    if not (coalesce(ctx->>'time_window','') = any(arr)) then return false; end if;
  end if;
  if p ? 'region_codes' then
    select array_agg(v) into arr from jsonb_array_elements_text(p->'region_codes') v;
    if not (coalesce(ctx->>'state_code','') = any(arr)) then return false; end if;
  end if;
  if p ? 'requires_flags' then
    for x in select v from jsonb_array_elements_text(p->'requires_flags') v loop
      if not (ctx->'flags') ? x then return false; end if;
    end loop;
  end if;
  if p ? 'requires_connected' then
    for x in select v from jsonb_array_elements_text(p->'requires_connected') v loop
      if not (coalesce(ctx->'connected','[]'::jsonb)) ? x then return false; end if;
    end loop;
  end if;
  if p ? 'min_run_days' and coalesce((ctx->>'run_days')::int, 0) < (p->>'min_run_days')::int then return false; end if;
  if p ? 'min_volume_km' and coalesce((ctx->>'volume_km')::numeric, 0) < (p->>'min_volume_km')::numeric then return false; end if;
  if p ? 'requires_variety' and (p->>'requires_variety')::boolean and not coalesce((ctx->>'variety')::boolean, false) then return false; end if;
  return true;
end $$;

-- ---------- §10 trust score ----------
create or replace function trust_score(p_distance_km numeric, p_moving_s int, p_avg_kmh numeric, p_max1_kmh numeric,
  p_steps int, p_splits jsonb, p_accel jsonb, p_activity jsonb, p_hr jsonb, p_has_track boolean,
  out score numeric, out verdict verdict_t, out detail jsonb)
language plpgsql stable as $$
declare
  ac jsonb := cfg('anticheat');
  sum_w numeric := 0; sum_we numeric := 0;
  e numeric; w numeric;
  stride numeric; cadence numeric; rr numeric; rms numeric; runwalk numeric; vehicle numeric;
  cv numeric; med numeric; spike boolean := false; n int; hrm numeric; hrx numeric;
  ev jsonb := '[]'::jsonb;
  procedure_note text;
begin
  detail := '{}'::jsonb;
  -- hard rules
  if p_avg_kmh > coalesce((ac#>>'{hard,max_avg_kmh}')::numeric, 20) or coalesce(p_max1_kmh, 0) > coalesce((ac#>>'{hard,max_1min_kmh}')::numeric, 24) then
    score := 0; verdict := 'rejected';
    detail := jsonb_build_object('hard_fail', true, 'avg_kmh', p_avg_kmh, 'max_1min_kmh', p_max1_kmh);
    return;
  end if;

  -- stride & cadence (need steps)
  if p_steps is not null and p_distance_km > 0 and p_moving_s > 0 then
    w := coalesce((ac#>>'{stride,w}')::numeric, 2);
    if p_steps = 0 then e := -1;
    else
      stride := p_distance_km * 1000 / p_steps;
      e := case when stride between (ac#>>'{stride,ok_min}')::numeric and (ac#>>'{stride,ok_max}')::numeric then 1
                when stride > (ac#>>'{stride,bad}')::numeric then -1
                when stride > (ac#>>'{stride,ok_max}')::numeric then -0.5
                else 0.3 end;  -- very short stride = shuffle/walk, mildly positive (still human)
    end if;
    sum_w := sum_w + w; sum_we := sum_we + w*e; ev := ev || jsonb_build_object('k','stride','v',round(coalesce(stride,0),2),'e',e,'w',w);

    w := coalesce((ac#>>'{cadence,w}')::numeric, 1.5);
    cadence := p_steps / (p_moving_s / 60.0);
    e := case when cadence between (ac#>>'{cadence,ok_min}')::numeric and (ac#>>'{cadence,ok_max}')::numeric then 1
              when cadence >= (ac#>>'{cadence,walk_min}')::numeric then 0.3
              when cadence < (ac#>>'{cadence,bad}')::numeric then -1
              else 0 end;
    sum_w := sum_w + w; sum_we := sum_we + w*e; ev := ev || jsonb_build_object('k','cadence','v',round(cadence,0),'e',e,'w',w);
  end if;

  -- footfall rhythm
  if p_accel is not null and p_accel ? 'rhythm_ratio' then
    w := coalesce((ac#>>'{rhythm,w}')::numeric, 2);
    rr := (p_accel->>'rhythm_ratio')::numeric; rms := (p_accel->>'vertical_rms')::numeric;
    e := case when rr >= (ac#>>'{rhythm,ok}')::numeric then 1 when rr >= (ac#>>'{rhythm,mid}')::numeric then 0 else -1 end;
    if rms is not null and rms < (ac#>>'{rhythm,min_rms}')::numeric and p_avg_kmh > (ac#>>'{rhythm,rms_speed_kmh}')::numeric then e := -1; end if;
    sum_w := sum_w + w; sum_we := sum_we + w*e; ev := ev || jsonb_build_object('k','rhythm','v',rr,'rms',rms,'e',e,'w',w);
  end if;

  -- platform activity classification
  if p_activity is not null then
    w := coalesce((ac#>>'{activity,w}')::numeric, 1.5);
    runwalk := coalesce((p_activity->>'running')::numeric,0) + coalesce((p_activity->>'walking')::numeric,0);
    vehicle := coalesce((p_activity->>'automotive')::numeric,0) + coalesce((p_activity->>'cycling')::numeric,0);
    e := case when vehicle >= (ac#>>'{activity,bad}')::numeric then -1 when runwalk >= (ac#>>'{activity,ok}')::numeric then 1 else 0 end;
    sum_w := sum_w + w; sum_we := sum_we + w*e; ev := ev || jsonb_build_object('k','activity','v',runwalk,'vehicle',vehicle,'e',e,'w',w);
  end if;

  -- consistency across the whole run (km splits)
  if p_splits is not null and jsonb_array_length(p_splits) >= 2 then
    w := coalesce((ac#>>'{consistency,w}')::numeric, 1);
    select count(*), percentile_cont(0.5) within group (order by v::numeric),
           stddev_pop(v::numeric) / nullif(avg(v::numeric),0)
      into n, med, cv from jsonb_array_elements_text(p_splits) v;
    select bool_or(v::numeric > med * (ac#>>'{consistency,spike_ratio}')::numeric and v::numeric > (ac#>>'{consistency,spike_kmh}')::numeric)
      into spike from jsonb_array_elements_text(p_splits) v;
    e := case when spike then -1 when coalesce(cv,1) <= (ac#>>'{consistency,cv_ok}')::numeric then 0.5 else 0 end;
    sum_w := sum_w + w; sum_we := sum_we + w*e; ev := ev || jsonb_build_object('k','consistency','cv',round(coalesce(cv,0),3),'spike',spike,'e',e,'w',w);
  end if;

  -- heart rate (watch)
  if p_hr is not null and p_hr ? 'mean' then
    w := coalesce((ac#>>'{hr,w}')::numeric, 2.5);
    hrm := (p_hr->>'mean')::numeric; hrx := coalesce((p_hr->>'max')::numeric, hrm);
    e := case when hrm < (ac#>>'{hr,mean_bad}')::numeric and p_avg_kmh > (ac#>>'{hr,bad_speed_kmh}')::numeric then -1
              when hrm >= (ac#>>'{hr,mean_ok}')::numeric and hrx >= (ac#>>'{hr,max_ok}')::numeric then 1
              else 0 end;
    sum_w := sum_w + w; sum_we := sum_we + w*e; ev := ev || jsonb_build_object('k','hr','mean',hrm,'max',hrx,'e',e,'w',w);
  end if;

  if sum_w = 0 then
    -- GPS only, no splits: nothing to weigh. Neutral-positive: the hard pace rules already passed.
    score := case when p_has_track then 0.65 else 0.5 end;
  else
    score := round(0.5 + 0.5 * (sum_we / sum_w), 3);
  end if;
  verdict := case when score >= coalesce((ac->>'verified')::numeric, 0.6) then 'verified'
                  when score >= coalesce((ac->>'unverified')::numeric, 0.4) then 'unverified'
                  else 'rejected' end;
  detail := jsonb_build_object('evidence', ev, 'sum_w', sum_w);
end $$;

-- ---------- §6.2 weighted draw ----------
-- pool: [{"animal_id":..., "w": ...}, ...]
create or replace function pick_weighted(pool jsonb) returns uuid language plpgsql volatile as $$
declare total numeric := 0; r numeric; acc numeric := 0; item jsonb;
begin
  for item in select * from jsonb_array_elements(pool) loop total := total + (item->>'w')::numeric; end loop;
  if total <= 0 then return null; end if;
  r := random() * total;
  for item in select * from jsonb_array_elements(pool) loop
    acc := acc + (item->>'w')::numeric;
    if r < acc then return (item->>'animal_id')::uuid; end if;
  end loop;
  return (pool->(jsonb_array_length(pool)-1)->>'animal_id')::uuid;
end $$;

-- Builds the pool for a run context. Returns {"tier":n,"trigger":"...","pool":[{animal_id,slug,name,rarity,w,p}]}
-- p_user may be null (admin rule tester: no pity / wild / history).
create or replace function build_run_pool(p_user uuid, ctx jsonb, p_verdict verdict_t) returns jsonb
language plpgsql volatile as $$
declare
  t int; trig text; fire boolean; seen boolean; any_guar boolean; max_rep numeric;
  rw jsonb := cfg('rarity_weights'); pity jsonb := cfg('pity'); wild jsonb := cfg('wild');
  n_since int := 0; has_master boolean := false;
  pool jsonb := '[]'::jsonb; total numeric := 0; item jsonb; w numeric; pm numeric;
  rec record; chosen_tier int := 0; has_rare boolean := false;
begin
  if p_user is not null then
    select cards_since_rare into n_since from pity_state where user_id = p_user;
    select exists(select 1 from bonds where user_id = p_user and mastered) into has_master;
  end if;

  if p_verdict = 'verified' then
    for t in reverse 4..1 loop
      trig := case t when 4 then 'migratory' when 3 then 'state:' || coalesce(ctx->>'state_code','?') when 2 then 'explorer' else 'time:' || coalesce(ctx->>'time_window','?') end;
      select bool_or(r.first_time_guaranteed), max(r.repeat_probability)
        into any_guar, max_rep
        from animal_rules r join animals a on a.id = r.animal_id
       where r.is_active and a.is_active and r.scope = 'run' and r.tier = t and rule_matches(r.predicates, ctx);
      continue when any_guar is null;  -- no matching rules at this tier
      seen := false;
      if p_user is not null then select exists(select 1 from tier_history where user_id = p_user and trigger = trig) into seen; end if;
      fire := (not seen and any_guar) or (random() < coalesce(max_rep, 0));
      if fire then chosen_tier := t; exit; end if;
    end loop;
  end if;
  trig := case chosen_tier when 4 then 'migratory' when 3 then 'state:' || coalesce(ctx->>'state_code','?') when 2 then 'explorer' when 1 then 'time:' || coalesce(ctx->>'time_window','?') else 'speed:' || coalesce(ctx->>'speed_band','?') end;

  for rec in
    select a.id, a.slug, a.name, a.rarity, r.weight,
           coalesce((select mastered from bonds b where b.user_id = p_user and b.animal_id = a.id), false) as mastered
      from animal_rules r join animals a on a.id = r.animal_id
     where r.is_active and a.is_active and r.scope = 'run' and r.tier = chosen_tier and rule_matches(r.predicates, ctx)
  loop
    w := coalesce((rw->>rec.rarity::text)::numeric, 1) * rec.weight;
    if rarity_rank(rec.rarity) >= 2 then
      has_rare := true;
      pm := least(coalesce((pity->>'cap')::numeric, 8), 1 + coalesce((pity->>'k')::numeric, 0.6) * greatest(0, n_since - coalesce((pity->>'n0')::int, 4)));
      w := w * pm;
      if has_master then w := w * coalesce((wild->>'rare_boost')::numeric, 1.5); end if;
    end if;
    if rec.mastered then w := w * coalesce((wild->>'mastered_weight_mult')::numeric, 0.25); end if;
    pool := pool || jsonb_build_object('animal_id', rec.id, 'slug', rec.slug, 'name', rec.name, 'rarity', rec.rarity, 'w', round(w, 4));
  end loop;

  -- hard pity: drop commons/uncommons when the user has waited long enough and a rare exists in this pool
  if has_rare and n_since >= coalesce((pity->>'hard_pity')::int, 15) then
    select coalesce(jsonb_agg(i), '[]'::jsonb) into pool from jsonb_array_elements(pool) i where rarity_rank((i->>'rarity')::rarity_t) >= 2;
  end if;

  for item in select * from jsonb_array_elements(pool) loop total := total + (item->>'w')::numeric; end loop;
  select coalesce(jsonb_agg(i || jsonb_build_object('p', case when total > 0 then round((i->>'w')::numeric / total, 4) else 0 end)), '[]'::jsonb)
    into pool from jsonb_array_elements(pool) i;
  return jsonb_build_object('tier', chosen_tier, 'trigger', trig, 'pity_n', n_since, 'pool', pool);
end $$;

-- ---------- §11 serial + card insert ----------
create or replace function issue_card(p_user uuid, p_animal uuid, p_scope card_scope_t, p_period_key text, p_tier int,
  p_stage stage_t, p_finish finish_t, p_run_id uuid, p_stats jsonb, p_verdict verdict_t, p_local_date date)
returns cards language plpgsql volatile as $$
declare s int; c cards;
begin
  update animal_counters set next_serial = next_serial + 1 where animal_id = p_animal returning next_serial into s;
  if s is null then
    insert into animal_counters(animal_id, next_serial) values (p_animal, 1) returning next_serial into s;
  end if;
  insert into cards(user_id, animal_id, serial_no, scope, period_key, tier, stage, finish, season_id, run_id, stats, verdict)
  values (p_user, p_animal, s, p_scope, p_period_key, p_tier, p_stage, p_finish, active_season(p_local_date), p_run_id, p_stats, p_verdict)
  returning * into c;
  return c;
end $$;

-- ---------- §4.2 bond update; returns {stage, grew, mastered_now} ----------
create or replace function update_bond(p_user uuid, p_animal uuid, p_week text) returns jsonb language plpgsql volatile as $$
declare
  b bonds; new_stage stage_t; grew boolean := false; mastered_now boolean := false;
  bc jsonb := cfg('bond');
begin
  insert into bonds(user_id, animal_id) values (p_user, p_animal) on conflict do nothing;
  select * into b from bonds where user_id = p_user and animal_id = p_animal for update;
  b.earn_count := b.earn_count + 1;
  if b.last_week is distinct from p_week then b.earn_weeks := b.earn_weeks + 1; b.last_week := p_week; end if;
  new_stage := case when b.earn_weeks >= coalesce((bc->>'adult_weeks')::int, 6) then 'adult'
                    when b.earn_weeks >= coalesce((bc->>'young_weeks')::int, 3) then 'young' else 'baby' end;
  if stage_rank(new_stage) > stage_rank(b.stage) then grew := true; b.stage := new_stage; end if;
  if not b.mastered and b.stage = 'adult' and b.earn_count >= coalesce((bc->>'mastered_earns')::int, 10) then b.mastered := true; mastered_now := true; end if;
  update bonds set earn_count = b.earn_count, earn_weeks = b.earn_weeks, last_week = b.last_week, stage = b.stage, mastered = b.mastered
   where user_id = p_user and animal_id = p_animal;
  return jsonb_build_object('stage', b.stage, 'grew', grew, 'mastered_now', mastered_now, 'earn_count', b.earn_count, 'earn_weeks', b.earn_weeks);
end $$;

create or replace function card_json(c cards) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', c.id, 'animal_id', c.animal_id, 'slug', a.slug, 'name', a.name, 'code', a.code, 'family', a.family, 'rarity', a.rarity,
    'flavour_line', a.flavour_line, 'palette', a.palette, 'art', a.art,
    'serial_no', c.serial_no, 'serial', a.name || ' #' || lpad(c.serial_no::text, coalesce((cfg('app')->>'serial_pad')::int, 4), '0'),
    'scope', c.scope, 'period_key', c.period_key, 'tier', c.tier, 'stage', c.stage, 'finish', c.finish,
    'season', (select name from seasons s where s.id = c.season_id), 'stats', c.stats, 'verdict', c.verdict, 'issued_at', c.issued_at,
    'verify_url', (cfg('app')->>'verify_base_url') || '/' || a.slug || '/' || c.serial_no)
  from animals a where a.id = c.animal_id
$$;

-- ---------- the main entry: submit a run ----------
create or replace function submit_run_for(p_user uuid, p jsonb) returns jsonb language plpgsql volatile as $$
declare
  prof profiles;
  tr record;
  pts jsonb := p->'track';
  started timestamptz := (p->>'started_at')::timestamptz;
  ended timestamptz;
  tz text;
  local_d date;
  elapsed_s int; moving_s int;
  dist_m numeric; flat_m numeric; dist_km numeric;
  v numeric; v_eq numeric;
  floor_ok boolean;
  age int; pidx numeric; band text;
  tw record;
  v_state text := nullif(p->>'state_code', '');
  reg regions;
  cells text[] := '{}'; new_cells int := 0; novelty numeric := 0;
  prior_runs int; area_runs int := 0; region_seen boolean := false; state_seen boolean := false; n_states int := 0; is_home boolean := false;
  flags text[] := '{}';
  states21 int := 0;
  ts record;
  run_row runs;
  existing runs;
  reset_bonds boolean := false;
  cards_today int; max_per_day int := coalesce((cfg('limits')->>'max_run_cards_per_day')::int, 2);
  ctx jsonb; poolinfo jsonb; animal uuid; chosen_tier int;
  d7 int; wk text;
  bond jsonb; st stage_t; fin finish_t; card cards;
  celebrations jsonb := '[]'::jsonb;
  a animals;
  copy jsonb := cfg('copy');
  ex jsonb := cfg('explore'); mg jsonb := cfg('migratory');
  has_track boolean;
begin
  select * into prof from profiles where id = p_user;
  if prof is null then raise exception 'profile not found'; end if;
  tz := coalesce(nullif(p->>'timezone',''), prof.timezone, 'Asia/Kolkata');
  if started is null then raise exception 'started_at required'; end if;

  -- idempotency: same client_run_id → return the earlier result
  if p ? 'client_run_id' then
    select * into existing from runs where user_id = p_user and client_run_id = p->>'client_run_id';
    if existing.id is not null then
      select * into card from cards where run_id = existing.id and scope = 'run';
      return jsonb_build_object('duplicate', true, 'run_id', existing.id, 'verdict', existing.verdict,
        'card', case when card.id is null then null else card_json(card) end);
    end if;
  end if;

  -- ---- geometry ----
  has_track := pts is not null and jsonb_typeof(pts) = 'array' and jsonb_array_length(pts) >= 2;
  if has_track then
    select * into tr from analyze_track(pts);
  end if;
  if has_track and tr.kept_points >= 10 and tr.distance_m > 0 then
    dist_m := tr.distance_m; flat_m := tr.flat_eq_m; cells := tr.cells;
  else
    dist_m := coalesce((p->>'distance_m')::numeric, 0); flat_m := dist_m;
  end if;
  dist_km := dist_m / 1000.0;
  elapsed_s := coalesce((p->>'elapsed_s')::int, case when p ? 'ended_at' then extract(epoch from (p->>'ended_at')::timestamptz - started)::int end, 0);
  moving_s := coalesce((p->>'moving_s')::int, elapsed_s);
  if moving_s <= 0 then moving_s := greatest(elapsed_s, 1); end if;
  elapsed_s := greatest(elapsed_s, moving_s);
  ended := started + make_interval(secs => elapsed_s);
  local_d := (started at time zone tz)::date;
  v := round(dist_km / (moving_s / 3600.0), 2);
  v_eq := round((flat_m/1000.0) / (moving_s / 3600.0), 2);

  -- ---- §1 floor ----
  floor_ok := dist_km >= cfg_num('floor','min_km',1.0)
           or (moving_s >= cfg_num('floor','min_moving_s',600) and v >= cfg_num('floor','min_speed_kmh',6.0));

  -- ---- §2 age grading ----
  age := case when prof.birth_year is null then null else extract(year from local_d)::int - prof.birth_year end;
  pidx := perf_index(v_eq, dist_km, prof.sex, age);
  band := speed_band(pidx);

  -- ---- §9.6 time window ----
  select * into tw from time_window_of(started, tr.centroid_lat, tr.centroid_lon, tz);

  -- ---- §9.4 state sanity ----
  if v_state is not null then
    select * into reg from regions where code = v_state;
    if reg.code is null then v_state := null;
    elsif tr.centroid_lat is not null and not (tr.centroid_lat between reg.min_lat and reg.max_lat and tr.centroid_lon between reg.min_lon and reg.max_lon) then
      v_state := null;  -- client claim does not match where the run happened
    end if;
  end if;

  -- ---- §9.3 novelty & exploration ----
  select count(*) into prior_runs from runs where user_id = p_user and verdict = 'verified' and eligible;
  if array_length(cells, 1) > 0 then
    select count(*) into new_cells from unnest(cells) c
     where not exists (select 1 from user_cells uc where uc.user_id = p_user and uc.cell = c
                        and uc.last_seen > now() - make_interval(days => coalesce((ex->>'history_days')::int, 180)));
    novelty := round(new_cells::numeric / array_length(cells, 1), 3);
    select coalesce(run_count, 0) into area_runs from user_areas where user_id = p_user and gh5 = geohash_encode(tr.centroid_lat, tr.centroid_lon, 5);
    select exists(select 1 from user_regions where user_id = p_user and gh4 = geohash_encode(tr.centroid_lat, tr.centroid_lon, 4)) into region_seen;
    if prior_runs >= coalesce((ex->>'min_prior_runs')::int, 3) then
      if novelty >= coalesce((ex->>'novelty_new_route')::numeric, 0.6) and array_length(cells,1) >= coalesce((ex->>'min_cells')::int, 6) then flags := array_append(flags, 'new_route'); end if;
      if novelty >= coalesce((ex->>'novelty_untraced_min')::numeric, 0.3) and novelty < coalesce((ex->>'novelty_new_route')::numeric, 0.6)
         and area_runs >= coalesce((ex->>'familiar_area_runs')::int, 3) then flags := array_append(flags, 'untraced'); end if;
      if not region_seen then flags := array_append(flags, 'new_area'); end if;
    end if;
    if tr.turns_per_km >= coalesce((ex->>'zigzag_turns_per_km')::numeric, 8) and dist_km >= coalesce((ex->>'zigzag_min_km')::numeric, 1.5) then flags := array_append(flags, 'zigzag'); end if;
    if flags && array['new_route','untraced','zigzag','new_area'] then flags := array_append(flags, 'explorer'); end if;
  end if;
  if v_state is not null then
    select exists(select 1 from user_states where user_id = p_user and state_code = v_state) into state_seen;
    select count(*) into n_states from user_states where user_id = p_user;
    -- where you live is not a souvenir: the first state ever (or the chosen home region) is home
    is_home := (prof.home_region = v_state) or (prof.home_region is null and n_states = 0);
    if prof.home_region is null and n_states = 0 then update profiles set home_region = v_state where id = p_user; end if;
    if not state_seen and not is_home then flags := array_append(flags, 'new_state'); end if;
    -- §9.5 migratory
    select count(distinct s) into states21 from (
      select r.state_code s from runs r where r.user_id = p_user and r.eligible and r.state_code is not null
         and r.started_at > started - make_interval(days => coalesce((mg->>'window_days')::int, 21))
      union select v_state) q;
    if prof.last_migratory_at is null or prof.last_migratory_at < started - make_interval(days => coalesce((mg->>'window_days')::int, 21)) then
      if states21 >= coalesce((mg->>'states_for_3')::int, 3) then flags := flags || array['migratory_2','migratory_3']::text[];
      elsif states21 >= coalesce((mg->>'states_for_2')::int, 2) then flags := array_append(flags, 'migratory_2'); end if;
    end if;
  end if;

  -- ---- §10 trust ----
  select * into ts from trust_score(dist_km, moving_s, v, tr.max_1min_kmh::numeric, (p->>'steps')::int, p->'splits_kmh', p->'accel', p->'activity', p->'hr', has_track);
  -- a run with no track and no sensor evidence from a non-platform source cannot be verified
  if not has_track and ts.verdict = 'verified' and coalesce(p->>'source','phone') = 'phone' and (p->>'steps') is null then ts.verdict := 'unverified'; end if;

  -- ---- store the run ----
  insert into runs(user_id, client_run_id, source, started_at, ended_at, timezone, local_date, distance_m, flat_eq_m, moving_s, elapsed_s,
                   avg_speed_kmh, max_1min_kmh, elev_gain_m, steps, splits_kmh, accel, activity, hr, centroid_lat, centroid_lon, state_code,
                   gh4, gh5, cells, turns_per_km, novelty, flags, time_window, sunrise_at, sunset_at, perf_index, speed_band,
                   trust_score, trust_detail, verdict, eligible)
  values (p_user, p->>'client_run_id', coalesce(p->>'source','phone'), started, ended, tz, local_d, round(dist_m,1), round(flat_m,1), moving_s, elapsed_s,
          v, round(coalesce(tr.max_1min_kmh, v)::numeric, 2), round(coalesce(tr.elev_gain_m,0)::numeric,1), (p->>'steps')::int, p->'splits_kmh', p->'accel', p->'activity', p->'hr',
          tr.centroid_lat, tr.centroid_lon, v_state,
          geohash_encode(tr.centroid_lat, tr.centroid_lon, 4), geohash_encode(tr.centroid_lat, tr.centroid_lon, 5), cells, round(coalesce(tr.turns_per_km,0)::numeric,2), novelty, flags,
          tw.win, tw.sunrise, tw.sunset, pidx, band, ts.score, ts.detail, ts.verdict, floor_ok and ts.verdict <> 'rejected')
  returning * into run_row;
  if has_track then insert into run_tracks(run_id, user_id, points) values (run_row.id, p_user, pts); end if;

  if ts.verdict = 'rejected' then
    insert into events(user_id, kind, payload) values (p_user, 'run_rejected', jsonb_build_object('run_id', run_row.id, 'message', copy->>'rejected'));
    return jsonb_build_object('run_id', run_row.id, 'verdict', 'rejected', 'trust', ts.score, 'card', null, 'message', copy->>'rejected');
  end if;

  -- ---- history ----
  if array_length(cells,1) > 0 then
    insert into user_cells(user_id, cell) select p_user, unnest(cells)
      on conflict (user_id, cell) do update set last_seen = now(), run_count = user_cells.run_count + 1;
    insert into user_areas(user_id, gh5) values (p_user, run_row.gh5) on conflict (user_id, gh5) do update set run_count = user_areas.run_count + 1;
    insert into user_regions(user_id, gh4) values (p_user, run_row.gh4) on conflict (user_id, gh4) do update set run_count = user_regions.run_count + 1;
  end if;
  if v_state is not null and floor_ok then
    insert into user_states(user_id, state_code, first_run_at) values (p_user, v_state, started)
      on conflict (user_id, state_code) do update set run_count = user_states.run_count + 1;
  end if;
  -- §4.2 reset after a long break (checked before we touch last_run_at)
  if prof.last_run_at is not null and started - prof.last_run_at >= make_interval(days => coalesce((cfg('bond')->>'reset_after_days')::int, 60)) then
    delete from bonds where user_id = p_user; reset_bonds := true;
    insert into events(user_id, kind, payload) values (p_user, 'bonds_reset', jsonb_build_object('days_away', extract(day from started - prof.last_run_at)));
  end if;
  update profiles set last_run_at = greatest(coalesce(last_run_at, started), started) where id = p_user;

  if not floor_ok then
    return jsonb_build_object('run_id', run_row.id, 'verdict', ts.verdict, 'trust', ts.score, 'card', null, 'floor', false,
      'message', 'Recorded. A run of 1 km or 10 minutes earns a card.');
  end if;

  -- ---- daily cap ----
  select count(*) into cards_today from cards c join runs r on r.id = c.run_id where c.user_id = p_user and c.scope = 'run' and r.local_date = local_d;
  if cards_today >= max_per_day then
    return jsonb_build_object('run_id', run_row.id, 'verdict', ts.verdict, 'trust', ts.score, 'card', null, 'capped', true,
      'message', 'Recorded and counted. Your card bag refills tomorrow.');
  end if;

  -- ---- pool & draw ----
  ctx := jsonb_build_object('speed_band', band, 'distance_km', round(dist_km,2), 'time_window', tw.win, 'flags', to_jsonb(flags),
                            'state_code', v_state, 'connected', to_jsonb(prof.connected), 'moving_s', moving_s);
  poolinfo := build_run_pool(p_user, ctx, ts.verdict);
  chosen_tier := (poolinfo->>'tier')::int;
  animal := pick_weighted(poolinfo->'pool');
  if animal is null then
    return jsonb_build_object('run_id', run_row.id, 'verdict', ts.verdict, 'trust', ts.score, 'card', null, 'message', 'No animal matched this run (rules need seeding).');
  end if;
  select * into a from animals where id = animal;

  -- ---- consistency, bond, stage, finish ----
  select count(distinct local_date) into d7 from runs where user_id = p_user and eligible and local_date between local_d - 6 and local_d;
  wk := week_key(local_d);
  bond := update_bond(p_user, animal, wk);
  st := case when stage_rank(stage_for('run', dist_km)) >= stage_rank((bond->>'stage')::stage_t) then stage_for('run', dist_km) else (bond->>'stage')::stage_t end;
  fin := finish_for('run', d7);

  card := issue_card(p_user, animal, 'run', run_row.id::text, chosen_tier, st, fin, run_row.id,
            jsonb_build_object('distance_km', round(dist_km,2), 'duration_s', moving_s, 'pace_s_per_km', round(moving_s / nullif(dist_km,0)),
                               'date', local_d, 'time_window', tw.win, 'band', band),
            ts.verdict, local_d);

  -- ---- bookkeeping ----
  if chosen_tier >= 1 then
    insert into tier_history(user_id, trigger) values (p_user, poolinfo->>'trigger')
      on conflict (user_id, trigger) do update set count = tier_history.count + 1;
  end if;
  if chosen_tier = 3 and v_state is not null then update user_states set souvenir_cards = souvenir_cards + 1 where user_id = p_user and state_code = v_state; end if;
  if chosen_tier = 4 then update profiles set last_migratory_at = started where id = p_user; end if;
  insert into pity_state(user_id) values (p_user) on conflict do nothing;
  if rarity_rank(a.rarity) >= 2 then update pity_state set cards_since_rare = 0, updated_at = now() where user_id = p_user;
  else update pity_state set cards_since_rare = cards_since_rare + 1, updated_at = now() where user_id = p_user; end if;

  if (bond->>'grew')::boolean then
    celebrations := celebrations || jsonb_build_object('kind', 'growth', 'stage', bond->>'stage', 'animal', a.name,
      'message', case bond->>'stage' when 'adult' then format('Your %s is all grown up!', lower(a.name)) else format('Your %s is growing!', lower(a.name)) end);
  end if;
  if (bond->>'mastered_now')::boolean then
    celebrations := celebrations || jsonb_build_object('kind', 'mastered', 'animal', a.name, 'message', format('You and the %s know each other now. The wild opens up.', lower(a.name)));
  end if;
  if reset_bonds then celebrations := celebrations || jsonb_build_object('kind', 'welcome_back', 'message', 'Welcome back. Your animals start small again — and so does the adventure.'); end if;
  if chosen_tier >= 1 then celebrations := celebrations || jsonb_build_object('kind', 'discovery', 'tier', chosen_tier, 'trigger', poolinfo->>'trigger'); end if;

  insert into events(user_id, kind, payload) values (p_user, 'card_issued', jsonb_build_object('card_id', card.id, 'celebrations', celebrations));

  return jsonb_build_object('run_id', run_row.id, 'verdict', ts.verdict, 'trust', ts.score, 'perf_index', pidx, 'band', band,
    'time_window', tw.win, 'flags', to_jsonb(flags), 'novelty', novelty, 'tier', chosen_tier, 'trigger', poolinfo->>'trigger',
    'card', card_json(card), 'celebrations', celebrations, 'message', case when ts.verdict = 'unverified' then copy->>'unverified' else null end);
end $$;

-- Public RPC: the signed-in user submits their own run.
create or replace function submit_run(p jsonb) returns jsonb language plpgsql volatile security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  return submit_run_for(auth.uid(), p);
end $$;

-- ---------- §7 weekly ----------
create or replace function issue_weekly_card_for(p_user uuid, p_week_start date) returns jsonb language plpgsql volatile as $$
declare
  d int; vol numeric; variety boolean; tiers int[]; v_tier int := 0; t int;
  key text := week_key(p_week_start);
  pool jsonb := '[]'::jsonb; rec record; rw jsonb := cfg('rarity_weights'); w numeric;
  animal uuid; a animals; bond jsonb; st stage_t; card cards; existing cards; celebrations jsonb := '[]'::jsonb;
  ctx jsonb;
begin
  select * into existing from cards where user_id = p_user and scope = 'weekly' and period_key = key;
  if existing.id is not null then return jsonb_build_object('card', card_json(existing), 'existing', true); end if;

  select count(distinct local_date), coalesce(sum(distance_m)/1000.0, 0),
         coalesce(bool_or(flags && array['new_route','untraced','zigzag','new_area','new_state']), false)
    into d, vol, variety
    from runs where user_id = p_user and eligible and local_date >= p_week_start and local_date < p_week_start + 7;
  if d < coalesce((cfg('weekly')->>'min_run_days')::int, 3) then
    return jsonb_build_object('card', null, 'run_days', d, 'message', cfg('copy')->>'no_weekly');
  end if;
  select array_agg(v::int order by v::int) into tiers from jsonb_array_elements_text(cfg('weekly')->'tiers') v;
  foreach t in array coalesce(tiers, array[3,5,7]) loop if d >= t then v_tier := t; end if; end loop;

  ctx := jsonb_build_object('run_days', d, 'volume_km', round(vol,1), 'variety', variety);
  for rec in select an.id, an.rarity, r.weight from animal_rules r join animals an on an.id = r.animal_id
              where r.is_active and an.is_active and r.scope = 'weekly' and r.tier = v_tier and rule_matches(r.predicates, ctx) loop
    pool := pool || jsonb_build_object('animal_id', rec.id, 'w', coalesce((rw->>rec.rarity::text)::numeric,1) * rec.weight);
  end loop;
  -- variety (new route / area / state during the week) is recorded as a stamp in stats; it never dilutes the bag
  animal := pick_weighted(pool);
  if animal is null then return jsonb_build_object('card', null, 'run_days', d, 'message', 'No weekly animals seeded for this tier.'); end if;
  select * into a from animals where id = animal;

  bond := update_bond(p_user, animal, key);
  st := case when stage_rank(stage_for('weekly', vol)) >= stage_rank((bond->>'stage')::stage_t) then stage_for('weekly', vol) else (bond->>'stage')::stage_t end;
  card := issue_card(p_user, animal, 'weekly', key, v_tier, st, finish_for('weekly', d), null,
            jsonb_build_object('run_days', d, 'volume_km', round(vol,1), 'week', key, 'variety', variety), 'verified', p_week_start + 6);
  if (bond->>'grew')::boolean then celebrations := celebrations || jsonb_build_object('kind','growth','stage',bond->>'stage','animal',a.name,
      'message', case bond->>'stage' when 'adult' then format('Your %s is all grown up!', lower(a.name)) else format('Your %s is growing!', lower(a.name)) end); end if;
  insert into events(user_id, kind, payload) values (p_user, 'weekly_card', jsonb_build_object('card_id', card.id, 'run_days', d, 'celebrations', celebrations));
  return jsonb_build_object('card', card_json(card), 'run_days', d, 'volume_km', round(vol,1), 'tier', v_tier, 'celebrations', celebrations);
end $$;

-- ---------- §8 monthly ----------
create or replace function issue_monthly_card_for(p_user uuid, p_month_start date) returns jsonb language plpgsql volatile as $$
declare
  key text := to_char(p_month_start, 'YYYY-MM');
  n int; vol numeric; days int; home text; home_name text;
  pool jsonb := '[]'::jsonb; rec record; rw jsonb := cfg('rarity_weights');
  animal uuid; a animals; bond jsonb; st stage_t; card cards; existing cards; ctx jsonb; celebrations jsonb := '[]'::jsonb;
begin
  select * into existing from cards where user_id = p_user and scope = 'monthly' and period_key = key;
  if existing.id is not null then return jsonb_build_object('card', card_json(existing), 'existing', true); end if;

  select count(*), coalesce(sum(distance_m)/1000.0, 0), count(distinct local_date) into n, vol, days
    from runs where user_id = p_user and eligible and local_date >= p_month_start and local_date < (p_month_start + interval '1 month')::date;
  if n < coalesce((cfg('monthly')->>'min_runs')::int, 4) then return jsonb_build_object('card', null, 'runs', n); end if;

  select state_code into home from runs where user_id = p_user and eligible and state_code is not null
     and local_date >= p_month_start and local_date < (p_month_start + interval '1 month')::date
   group by state_code order by count(*) desc, max(started_at) desc limit 1;
  select name into home_name from regions where code = home;

  ctx := jsonb_build_object('state_code', home, 'volume_km', round(vol,1), 'run_days', days);
  for rec in select an.id, an.rarity, r.weight, (r.predicates ? 'region_codes') as regional from animal_rules r join animals an on an.id = r.animal_id
              where r.is_active and an.is_active and r.scope = 'monthly' and rule_matches(r.predicates, ctx) loop
    pool := pool || jsonb_build_object('animal_id', rec.id, 'w', coalesce((rw->>rec.rarity::text)::numeric,1) * rec.weight * case when rec.regional then 3 else 1 end);
  end loop;
  animal := pick_weighted(pool);
  if animal is null then return jsonb_build_object('card', null, 'runs', n, 'message', 'No monthly animals seeded.'); end if;
  select * into a from animals where id = animal;

  bond := update_bond(p_user, animal, key);
  st := case when stage_rank(stage_for('monthly', vol)) >= stage_rank((bond->>'stage')::stage_t) then stage_for('monthly', vol) else (bond->>'stage')::stage_t end;
  card := issue_card(p_user, animal, 'monthly', key, 0, st, finish_for('monthly', days), null,
            jsonb_build_object('runs', n, 'run_days', days, 'volume_km', round(vol,1), 'month', key, 'region', home_name), 'verified',
            (p_month_start + interval '1 month' - interval '1 day')::date);
  if (bond->>'grew')::boolean then celebrations := celebrations || jsonb_build_object('kind','growth','stage',bond->>'stage','animal',a.name); end if;
  insert into events(user_id, kind, payload) values (p_user, 'monthly_card', jsonb_build_object('card_id', card.id, 'celebrations', celebrations));
  return jsonb_build_object('card', card_json(card), 'runs', n, 'volume_km', round(vol,1), 'region', home, 'celebrations', celebrations);
end $$;

-- Called by the app on open: issues any weekly/monthly cards for completed periods (idempotent, no cron needed).
create or replace function claim_pending_cards() returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := auth.uid(); tz text; today date; out jsonb := '[]'::jsonb; r jsonb; wk date; mo date; first_run date;
begin
  if u is null then raise exception 'not signed in' using errcode = '28000'; end if;
  select timezone into tz from profiles where id = u;
  today := (now() at time zone coalesce(tz,'Asia/Kolkata'))::date;
  select min(local_date) into first_run from runs where user_id = u and eligible;
  if first_run is null then return out; end if;
  -- weeks: from the user's first run week up to last completed week (cap at 8 weeks back to bound work)
  wk := greatest(week_start(first_run), week_start(today) - 56);
  while wk < week_start(today) loop
    r := issue_weekly_card_for(u, wk);
    if r->'card' is not null and r->>'card' <> 'null' and coalesce((r->>'existing')::boolean, false) = false then out := out || jsonb_build_object('scope','weekly') || r; end if;
    wk := wk + 7;
  end loop;
  mo := greatest(date_trunc('month', first_run)::date, (date_trunc('month', today) - interval '3 months')::date);
  while mo < date_trunc('month', today)::date loop
    r := issue_monthly_card_for(u, mo);
    if r->'card' is not null and r->>'card' <> 'null' and coalesce((r->>'existing')::boolean, false) = false then out := out || jsonb_build_object('scope','monthly') || r; end if;
    mo := (mo + interval '1 month')::date;
  end loop;
  return out;
end $$;

-- Server-side period close (pg_cron on Supabase; optional because claim_pending_cards covers it lazily)
create or replace function close_periods() returns int language plpgsql volatile security definer set search_path = public as $$
declare u record; n int := 0; today date := (now() at time zone 'Asia/Kolkata')::date; r jsonb;
begin
  for u in select distinct user_id from runs where eligible and local_date >= week_start(today) - 7 and local_date < week_start(today) loop
    r := issue_weekly_card_for(u.user_id, week_start(today) - 7); if r->>'card' is not null and r->>'card' <> 'null' then n := n + 1; end if;
  end loop;
  if extract(day from today) <= 3 then
    for u in select distinct user_id from runs where eligible and local_date >= (date_trunc('month', today) - interval '1 month')::date and local_date < date_trunc('month', today)::date loop
      r := issue_monthly_card_for(u.user_id, (date_trunc('month', today) - interval '1 month')::date); if r->>'card' is not null and r->>'card' <> 'null' then n := n + 1; end if;
    end loop;
  end if;
  return n;
end $$;

-- ---------- §11 public serial lookup (the only search) ----------
create or replace function lookup_serial(q text) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  s text := lower(trim(q)); m text[]; name_part text; num int; a animals; c cards; who text;
begin
  if s is null or s = '' then return jsonb_build_object('found', false, 'reason', 'empty'); end if;
  s := regexp_replace(s, '[#_/]+', ' ', 'g');
  m := regexp_match(s, '^\s*([a-z][a-z \-'']*?)\s*-?\s*0*(\d{1,7})\s*$');
  if m is null then return jsonb_build_object('found', false, 'reason', 'format', 'hint', 'Try "Tiger #0427"'); end if;
  name_part := trim(m[1]); num := m[2]::int;
  select * into a from animals where lower(name) = name_part or slug = replace(name_part, ' ', '-') or lower(code) = replace(name_part, ' ', '') limit 1;
  if a.id is null then return jsonb_build_object('found', false, 'reason', 'animal', 'hint', 'No animal called ' || initcap(name_part)); end if;
  select * into c from cards where animal_id = a.id and serial_no = num and is_public;
  if c.id is null then return jsonb_build_object('found', false, 'reason', 'serial', 'animal', a.name, 'serial_no', num,
      'issued_so_far', (select next_serial from animal_counters where animal_id = a.id)); end if;
  select display_name into who from profiles where id = c.user_id;
  return jsonb_build_object('found', true, 'card', card_json(c), 'earned_by', who,
    'stats', c.stats - 'time_window',  -- public-safe stats only; never location
    'issued_so_far', (select next_serial from animal_counters where animal_id = a.id));
end $$;

-- ---------- app helpers ----------
create or replace function mark_events_seen(p_ids bigint[]) returns int language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  update events set seen_at = now() where user_id = auth.uid() and id = any(p_ids) and seen_at is null;
  get diagnostics n = row_count; return n;
end $$;

-- ---------- admin: rule tester ----------
-- ctx example: {"speed_band":"swift","distance_km":5,"time_window":"night","flags":["explorer"],"state_code":"IN-KL","connected":[]}
create or replace function admin_simulate_pool(ctx jsonb, p_as_user uuid default null) returns jsonb language plpgsql volatile security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'admin only' using errcode = '42501'; end if;
  return build_run_pool(p_as_user, ctx, 'verified');
end $$;

create or replace function admin_perf_preview(p_v_kmh numeric, p_d_km numeric, p_sex sex_t, p_age int) returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('v_std', v_std_kmh(p_sex, p_d_km), 'age_factor', age_factor(p_sex, p_age),
                            'perf_index', perf_index(p_v_kmh, p_d_km, p_sex, p_age), 'band', speed_band(perf_index(p_v_kmh, p_d_km, p_sex, p_age)))
$$;
