-- Pugmark · 0002 math helpers
-- Pure functions. All formulas are documented in docs/ALGORITHMS.md.

-- ---------- config access ----------
create or replace function cfg(p_key text) returns jsonb language sql stable as $$
  select value from config where key = p_key
$$;

create or replace function cfg_num(p_key text, p_path text, p_default numeric) returns numeric language sql stable as $$
  select coalesce((cfg(p_key) #>> string_to_array(p_path, '.'))::numeric, p_default)
$$;

-- ---------- §2.2 age factor (piecewise-linear interpolation) ----------
create or replace function age_factor(p_sex sex_t, p_age int) returns numeric language plpgsql stable as $$
declare
  a int := coalesce(p_age, 30);
  lo record; hi record; f numeric;
begin
  if p_sex is null then
    return round((age_factor('male', a) + age_factor('female', a)) / 2, 4);
  end if;
  a := greatest(5, least(100, a));
  select age, factor into lo from age_factors where sex = p_sex and age <= a order by age desc limit 1;
  select age, factor into hi from age_factors where sex = p_sex and age >= a order by age asc limit 1;
  if lo is null and hi is null then return 1.0; end if;
  if lo is null then return hi.factor; end if;
  if hi is null then return lo.factor; end if;
  if hi.age = lo.age then return lo.factor; end if;
  f := lo.factor + (hi.factor - lo.factor) * (a - lo.age)::numeric / (hi.age - lo.age);
  return round(f, 4);
end $$;

-- ---------- §2.1 Riegel open-standard speed ----------
create or replace function v_std_kmh(p_sex sex_t, p_d_km numeric) returns numeric language plpgsql stable as $$
declare
  t_ref numeric;
  d_ref numeric := cfg_num('age_grading', 'd_ref_km', 5);
  expo  numeric := cfg_num('age_grading', 'riegel_exponent', 1.06);
  d_eff numeric := greatest(p_d_km, cfg_num('age_grading', 'min_d_eff_km', 1.5));
  t_std numeric;
begin
  t_ref := case p_sex
    when 'male'   then cfg_num('age_grading', 't_ref_s.male', 755)
    when 'female' then cfg_num('age_grading', 't_ref_s.female', 840)
    else               cfg_num('age_grading', 't_ref_s.unknown', 796) end;
  t_std := t_ref * power(d_eff / d_ref, expo);
  return round(d_eff / (t_std / 3600.0), 3);
end $$;

-- ---------- §2.4 performance index ----------
create or replace function perf_index(p_v_eq_kmh numeric, p_d_km numeric, p_sex sex_t, p_age int) returns numeric
language sql stable as $$
  select round(p_v_eq_kmh / (v_std_kmh(p_sex, p_d_km) * age_factor(p_sex, p_age)), 3)
$$;

-- ---------- §3 speed band ----------
create or replace function speed_band(p numeric) returns text language plpgsql stable as $$
declare b jsonb := cfg('speed_bands');
begin
  if p >= coalesce((b->>'swift')::numeric, 0.60)  then return 'swift';  end if;
  if p >= coalesce((b->>'steady')::numeric, 0.47) then return 'steady'; end if;
  if p >= coalesce((b->>'calm')::numeric, 0.35)   then return 'calm';   end if;
  return 'gentle';
end $$;

-- ---------- §4.1 stage, §5 finish ----------
create or replace function stage_for(p_scope text, p_value numeric) returns stage_t language plpgsql stable as $$
declare t jsonb := cfg('stage_thresholds') -> p_scope;
begin
  if p_value >= coalesce((t->>'adult')::numeric, case p_scope when 'run' then 7 when 'weekly' then 25 else 80 end) then return 'adult'; end if;
  if p_value >= coalesce((t->>'young')::numeric, case p_scope when 'run' then 3 when 'weekly' then 10 else 30 end) then return 'young'; end if;
  return 'baby';
end $$;

create or replace function finish_for(p_scope text, p_days int) returns finish_t language plpgsql stable as $$
declare t jsonb := cfg('finish_thresholds') -> p_scope;
begin
  if p_days >= coalesce((t->>'radiant')::int, case p_scope when 'run' then 7 when 'weekly' then 7 else 20 end) then return 'radiant'; end if;
  if p_days >= coalesce((t->>'glow')::int,    case p_scope when 'run' then 4 when 'weekly' then 5 else 12 end) then return 'glow'; end if;
  return 'plain';
end $$;

create or replace function stage_rank(s stage_t) returns int language sql immutable as $$
  select case s when 'baby' then 0 when 'young' then 1 else 2 end
$$;
create or replace function rarity_rank(r rarity_t) returns int language sql immutable as $$
  select case r when 'common' then 0 when 'uncommon' then 1 when 'rare' then 2 when 'epic' then 3 else 4 end
$$;

-- ---------- geometry ----------
create or replace function haversine_m(lat1 double precision, lon1 double precision, lat2 double precision, lon2 double precision)
returns double precision language sql immutable as $$
  select 2 * 6371008.8 * asin( least(1.0, sqrt(
      power(sin(radians(lat2 - lat1) / 2), 2) +
      cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lon2 - lon1) / 2), 2)
  )))
$$;

create or replace function bearing_deg(lat1 double precision, lon1 double precision, lat2 double precision, lon2 double precision)
returns double precision language sql immutable as $$
  select mod( (degrees(atan2(
      sin(radians(lon2 - lon1)) * cos(radians(lat2)),
      cos(radians(lat1)) * sin(radians(lat2)) - sin(radians(lat1)) * cos(radians(lat2)) * cos(radians(lon2 - lon1))
  )) + 360)::numeric, 360)::double precision
$$;

create or replace function geohash_encode(p_lat double precision, p_lon double precision, p_precision int)
returns text language plpgsql immutable as $$
declare
  base32 constant text := '0123456789bcdefghjkmnpqrstuvwxyz';
  lat_lo double precision := -90;  lat_hi double precision := 90;
  lon_lo double precision := -180; lon_hi double precision := 180;
  mid double precision;
  is_lon boolean := true;
  bit int := 0; ch int := 0;
  out_hash text := '';
begin
  if p_lat is null or p_lon is null then return null; end if;
  while length(out_hash) < p_precision loop
    if is_lon then
      mid := (lon_lo + lon_hi) / 2;
      if p_lon >= mid then ch := ch * 2 + 1; lon_lo := mid; else ch := ch * 2; lon_hi := mid; end if;
    else
      mid := (lat_lo + lat_hi) / 2;
      if p_lat >= mid then ch := ch * 2 + 1; lat_lo := mid; else ch := ch * 2; lat_hi := mid; end if;
    end if;
    is_lon := not is_lon;
    bit := bit + 1;
    if bit = 5 then
      out_hash := out_hash || substr(base32, ch + 1, 1);
      bit := 0; ch := 0;
    end if;
  end loop;
  return out_hash;
end $$;

-- ---------- §2.3 Minetti grade cost ratio ----------
create or replace function minetti_ratio(i double precision) returns double precision language sql immutable as $$
  select greatest(0.75, least(2.5,
    (155.4*i^5 - 30.4*i^4 - 43.3*i^3 + 46.3*i^2 + 19.5*i + 3.6) / 3.6))
$$;

-- ---------- §9.6 solar events (NOAA / Meeus simplified) ----------
create or replace function solar_events(p_lat double precision, p_lon double precision, p_date date,
                                        out sunrise timestamptz, out sunset timestamptz)
language plpgsql immutable as $$
declare
  jd double precision := extract(epoch from p_date::timestamp)/86400.0 + 2440587.5;
  n  double precision := ceil(jd - 2451545.0 + 0.0008);  -- integer day number since J2000 (noon-based)
  jstar double precision := n - p_lon/360.0;
  m  double precision := mod((357.5291 + 0.98560028*jstar)::numeric, 360)::double precision;
  c  double precision;
  lam double precision;
  jtr double precision;
  sin_dec double precision; cos_dec double precision;
  cos_w0 double precision; w0 double precision;
begin
  c := 1.9148*sin(radians(m)) + 0.0200*sin(radians(2*m)) + 0.0003*sin(radians(3*m));
  lam := mod((m + c + 180 + 102.9372)::numeric, 360)::double precision;
  jtr := 2451545.0 + jstar + 0.0053*sin(radians(m)) - 0.0069*sin(radians(2*lam));
  sin_dec := sin(radians(lam)) * sin(radians(23.44));
  cos_dec := sqrt(1 - sin_dec*sin_dec);
  cos_w0 := (sin(radians(-0.833)) - sin(radians(p_lat))*sin_dec) / (cos(radians(p_lat))*cos_dec);
  if cos_w0 >= 1 then  -- polar night (not in India, guarded anyway)
    sunrise := to_timestamp((jtr - 2440587.5)*86400); sunset := sunrise; return;
  elsif cos_w0 <= -1 then -- midnight sun
    sunrise := to_timestamp((jtr - 0.5 - 2440587.5)*86400); sunset := to_timestamp((jtr + 0.5 - 2440587.5)*86400); return;
  end if;
  w0 := degrees(acos(cos_w0));
  sunrise := to_timestamp((jtr - w0/360.0 - 2440587.5)*86400);
  sunset  := to_timestamp((jtr + w0/360.0 - 2440587.5)*86400);
end $$;

create or replace function time_window_of(p_start timestamptz, p_lat double precision, p_lon double precision, p_tz text,
                                          out win text, out sunrise timestamptz, out sunset timestamptz)
language plpgsql stable as $$
declare
  d date := (p_start at time zone coalesce(p_tz, 'Asia/Kolkata'))::date;
  tw jsonb := cfg('time_windows');
  dawn_before int := coalesce((tw->>'dawn_before_min')::int, 45);
  dawn_after  int := coalesce((tw->>'dawn_after_min')::int, 30);
  dusk_before int := coalesce((tw->>'dusk_before_min')::int, 15);
  dusk_after  int := coalesce((tw->>'dusk_after_min')::int, 45);
  night_after int := coalesce((tw->>'night_after_sunset_min')::int, 60);
  se record;
begin
  if p_lat is null or p_lon is null then
    -- no location: fall back to clock windows in the user's timezone
    declare h numeric := extract(hour from (p_start at time zone coalesce(p_tz,'Asia/Kolkata'))) + extract(minute from (p_start at time zone coalesce(p_tz,'Asia/Kolkata')))/60.0;
    begin
      win := case when h >= 21 or h < 4.5 then 'night' when h < 6.75 then 'dawn' when h >= 17.75 and h < 19 then 'dusk' else 'day' end;
      return;
    end;
  end if;
  select * into se from solar_events(p_lat, p_lon, d);
  sunrise := se.sunrise; sunset := se.sunset;
  -- the run may start after midnight local; sunrise of "today" is the right reference either way
  if p_start >= sunrise - make_interval(mins => dawn_before) and p_start < sunrise + make_interval(mins => dawn_after) then
    win := 'dawn';
  elsif p_start >= sunset - make_interval(mins => dusk_before) and p_start < sunset + make_interval(mins => dusk_after) then
    win := 'dusk';
  elsif p_start >= sunset + make_interval(mins => night_after) or p_start < sunrise - make_interval(mins => dawn_before) then
    win := 'night';
  else
    win := 'day';
  end if;
end $$;

-- ---------- §9 track analysis ----------
-- points: [[lat, lon, alt|null, t_offset_s, accuracy_m|null], ...]
create or replace function analyze_track(p_points jsonb,
  out distance_m double precision, out flat_eq_m double precision, out elev_gain_m double precision,
  out centroid_lat double precision, out centroid_lon double precision,
  out cells text[], out turns_per_km double precision, out max_1min_kmh double precision, out kept_points int)
language plpgsql stable as $$
declare
  n int := coalesce(jsonb_array_length(p_points), 0);
  max_acc double precision := cfg_num('track', 'max_accuracy_m', 50);
  jump_kmh double precision := cfg_num('track', 'max_jump_kmh', 30);
  step_m double precision := cfg_num('track', 'resample_m', 25);
  turn_deg double precision := cfg_num('explore', 'turn_deg', 60);
  lat double precision; lon double precision; alt double precision; t double precision; acc double precision;
  plat double precision; plon double precision; palt double precision; pt double precision;
  seg double precision; dt double precision;
  sum_lat double precision := 0; sum_lon double precision := 0;
  rs_lat double precision[] := '{}'; rs_lon double precision[] := '{}'; rs_alt double precision[] := '{}';
  carry double precision := 0; frac double precision; k int;
  alt_count int := 0;
  cell_set text[] := '{}';
  turns int := 0; prev_bearing double precision; b double precision; dB double precision;
  i int; m int;
  win_lat double precision[] := '{}'; win_lon double precision[] := '{}'; win_t double precision[] := '{}'; win_d double precision[] := '{}';
  cum_d double precision := 0; j int;
  sm_alt double precision; grade double precision; sl double precision;
begin
  distance_m := 0; flat_eq_m := 0; elev_gain_m := 0; turns_per_km := 0; max_1min_kmh := 0; kept_points := 0; cells := '{}';
  if n < 2 then centroid_lat := null; centroid_lon := null; return; end if;

  for i in 0..n-1 loop
    lat := (p_points->i->>0)::double precision; lon := (p_points->i->>1)::double precision;
    alt := nullif(p_points->i->>2, 'null')::double precision; t := coalesce((p_points->i->>3)::double precision, i);
    acc := nullif(p_points->i->>4, 'null')::double precision;
    continue when lat is null or lon is null;
    continue when acc is not null and acc > max_acc;
    if plat is not null then
      seg := haversine_m(plat, plon, lat, lon);
      dt := greatest(t - pt, 0.5);
      continue when (seg / dt) * 3.6 > jump_kmh;          -- GPS jump
      distance_m := distance_m + seg;
      cum_d := cum_d + seg;
      -- resample every step_m along the segment
      carry := carry + seg;
      while carry >= step_m loop
        frac := 1 - (carry - step_m) / seg;              -- position along this segment
        rs_lat := rs_lat || (plat + (lat - plat) * frac);
        rs_lon := rs_lon || (plon + (lon - plon) * frac);
        rs_alt := rs_alt || (case when alt is not null and palt is not null then palt + (alt - palt) * frac else null end);
        carry := carry - step_m;
      end loop;
      -- sliding 60 s window for max 1-minute speed
      win_t := win_t || t; win_d := win_d || cum_d;
      j := 1;
      while j < array_length(win_t, 1) and win_t[array_length(win_t,1)] - win_t[j] > 60 loop j := j + 1; end loop;
      if j > 1 then win_t := win_t[j:]; win_d := win_d[j:]; end if;
      if array_length(win_t,1) > 1 and (win_t[array_length(win_t,1)] - win_t[1]) >= 45 then
        max_1min_kmh := greatest(max_1min_kmh, (win_d[array_length(win_d,1)] - win_d[1]) / (win_t[array_length(win_t,1)] - win_t[1]) * 3.6);
      end if;
    else
      win_t := array[t]; win_d := array[0::double precision];
    end if;
    kept_points := kept_points + 1;
    sum_lat := sum_lat + lat; sum_lon := sum_lon + lon;
    if alt is not null then alt_count := alt_count + 1; end if;
    plat := lat; plon := lon; palt := alt; pt := t;
  end loop;

  if kept_points < 2 then centroid_lat := null; centroid_lon := null; distance_m := 0; return; end if;
  centroid_lat := sum_lat / kept_points; centroid_lon := sum_lon / kept_points;

  m := coalesce(array_length(rs_lat, 1), 0);
  -- cells
  for i in 1..m loop
    cell_set := cell_set || geohash_encode(rs_lat[i], rs_lon[i], 7);
  end loop;
  select coalesce(array_agg(distinct c), '{}') into cells from unnest(cell_set) c;
  -- turns
  for i in 2..m loop
    b := bearing_deg(rs_lat[i-1], rs_lon[i-1], rs_lat[i], rs_lon[i]);
    if prev_bearing is not null then
      dB := abs(b - prev_bearing); if dB > 180 then dB := 360 - dB; end if;
      if dB > turn_deg then turns := turns + 1; end if;
    end if;
    prev_bearing := b;
  end loop;
  turns_per_km := case when distance_m > 0 then turns / (distance_m / 1000.0) else 0 end;
  -- grade adjustment (only if most kept points had altitude)
  flat_eq_m := distance_m;
  if m >= 3 and alt_count >= kept_points * 0.5 then
    flat_eq_m := 0;
    for i in 2..m loop
      -- smoothed altitude: mean over window i-2..i+2 (≈100 m) ignoring nulls
      select avg(a) into sm_alt from unnest(rs_alt[greatest(1,i-2):least(m,i+2)]) a where a is not null;
      select avg(a) into palt   from unnest(rs_alt[greatest(1,i-3):least(m,i+1)]) a where a is not null;
      grade := case when sm_alt is null or palt is null then 0 else greatest(-0.45, least(0.45, (sm_alt - palt) / step_m)) end;
      if grade > 0 then elev_gain_m := elev_gain_m + grade * step_m; end if;
      flat_eq_m := flat_eq_m + step_m * minetti_ratio(grade);
    end loop;
    -- scale residual (distance beyond the last resampled point) at ratio 1
    flat_eq_m := flat_eq_m + greatest(0, distance_m - m * step_m);
  end if;
end $$;
