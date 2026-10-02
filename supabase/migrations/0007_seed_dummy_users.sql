-- Pugmark · 0007 dummy users (pre-launch play)
-- Six personas from PRD §12. Run `select seed_dummy_users();` with the service role (SQL editor) to create them.
-- Password for every dummy account: pugmark-test-2026   (test accounts only; delete before public launch)

-- Synthetic GPS track generator: points every 5 s as [lat, lon, alt, t, accuracy]
create or replace function seed_track(p_lat double precision, p_lon double precision, p_km numeric, p_kmh numeric,
                                      p_shape text default 'loop', p_alt double precision default 900, p_gain double precision default 0)
returns jsonb language plpgsql immutable as $$
declare
  total_s int := ceil(p_km / p_kmh * 3600);
  n int := total_s / 5;
  pts jsonb := '[]'::jsonb;
  i int; d double precision; lat double precision; lon double precision; alt double precision;
  mps double precision := p_kmh / 3.6;
  r double precision := (p_km * 1000) / (2 * pi());       -- loop radius
  coslat double precision := cos(radians(p_lat));
  leg int;
begin
  for i in 0..n loop
    d := i * 5 * mps;                                        -- metres travelled
    alt := p_alt + p_gain * (i::double precision / n);
    if p_shape = 'line' then
      lat := p_lat + d / 111320.0; lon := p_lon;
    elsif p_shape = 'zigzag' then
      leg := floor(d / 60);                                  -- 60 m legs alternating east / north
      lat := p_lat + ((leg / 2) * 60 + case when leg % 2 = 1 then d - leg*60 else 0 end) / 111320.0;
      lon := p_lon + (((leg + 1) / 2) * 60 + case when leg % 2 = 0 then d - leg*60 else 0 end) / (111320.0 * coslat);
    else -- loop
      lat := p_lat + (r * sin(d / r)) / 111320.0;
      lon := p_lon + (r * (1 - cos(d / r))) / (111320.0 * coslat);
    end if;
    pts := pts || jsonb_build_array(jsonb_build_array(round(lat::numeric, 6), round(lon::numeric, 6), round(alt::numeric, 1), i * 5, 8));  -- wrap: jsonb || flattens arrays
  end loop;
  return pts;
end $$;

-- Build a realistic payload for a persona run
create or replace function seed_payload(p_client_id text, p_start timestamptz, p_lat double precision, p_lon double precision,
  p_km numeric, p_kmh numeric, p_shape text, p_state text, p_cadence int, p_hr_mean int, p_connected text[])
returns jsonb language plpgsql immutable as $$
declare
  moving int := ceil(p_km / p_kmh * 3600);
  splits jsonb := '[]'::jsonb; i int;
begin
  for i in 1..greatest(1, floor(p_km)::int) loop splits := splits || to_jsonb(round((p_kmh * (0.97 + 0.06 * ((i * 7) % 3) / 2.0))::numeric, 2)); end loop;
  return jsonb_build_object(
    'client_run_id', p_client_id, 'source', 'seed', 'started_at', p_start, 'elapsed_s', moving + 40, 'moving_s', moving,
    'timezone', 'Asia/Kolkata', 'state_code', p_state,
    'track', seed_track(p_lat, p_lon, p_km, p_kmh, p_shape),
    'steps', case when 'steps' = any(p_connected) then round(p_cadence * moving / 60.0) end,
    'splits_kmh', splits,
    'accel', case when 'motion' = any(p_connected) then jsonb_build_object('rhythm_ratio', 0.82, 'vertical_rms', 3.2) end,
    'activity', case when 'activity' = any(p_connected) then jsonb_build_object('running', 0.86, 'walking', 0.1, 'stationary', 0.04) end,
    'hr', case when 'heart_rate' = any(p_connected) and p_hr_mean is not null then jsonb_build_object('mean', p_hr_mean, 'max', p_hr_mean + 18) end);
end $$;

create or replace function seed_user(p_id uuid, p_email text, p_name text, p_birth int, p_sex sex_t, p_home text, p_connected text[]) returns void
language plpgsql volatile security definer set search_path = public as $$
declare has_pw boolean;
begin
  select exists(select 1 from information_schema.columns where table_schema='auth' and table_name='users' and column_name='encrypted_password') into has_pw;
  if has_pw then
    execute $sql$
      insert into auth.users(id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
      values ($1, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', $2, crypt('pugmark-test-2026', gen_salt('bf')), now(),
              '{"provider":"email","providers":["email"]}', jsonb_build_object('display_name', $3), now(), now(), '', '', '', '')
      on conflict (id) do nothing $sql$ using p_id, p_email, p_name;
    execute $sql$ insert into auth.identities(id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      values (gen_random_uuid(), $1, $1::text, jsonb_build_object('sub', $1::text, 'email', $2), 'email', now(), now(), now()) on conflict do nothing $sql$ using p_id, p_email;
  else
    insert into auth.users(id, email, raw_user_meta_data) values (p_id, p_email, jsonb_build_object('display_name', p_name)) on conflict (id) do nothing;
  end if;
  insert into profiles(id, display_name) values (p_id, p_name) on conflict (id) do nothing;
  update profiles set display_name = p_name, birth_year = p_birth, sex = p_sex, home_region = p_home, connected = p_connected where id = p_id;
  insert into pity_state(user_id) values (p_id) on conflict do nothing;
end $$;

create or replace function seed_dummy_users() returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  today date := (now() at time zone 'Asia/Kolkata')::date;
  ist constant text := 'Asia/Kolkata';
  arjun uuid := '11111111-1111-4111-8111-000000000001';
  meera uuid := '11111111-1111-4111-8111-000000000002';
  ravi  uuid := '11111111-1111-4111-8111-000000000003';
  priya uuid := '11111111-1111-4111-8111-000000000004';
  kabir uuid := '11111111-1111-4111-8111-000000000005';
  sana  uuid := '11111111-1111-4111-8111-000000000006';
  allc text[] := array['location','motion','steps','heart_rate','activity','elevation'];
  basic text[] := array['location','steps'];
  out jsonb := '{}'::jsonb; r jsonb; i int; wk date := week_start(today) - 7;
  function_result jsonb;
begin
  -- 1. Arjun, 24, fast young sprinter (cheetah family): 5 km at 3:55/km, three evening runs this week (daytime window, so the swift bag shows)
  perform seed_user(arjun, 'arjun@pugmark.test', 'Arjun', extract(year from today)::int - 24, 'male', 'IN-KA', allc);
  for i in 1..3 loop
    r := submit_run_for(arjun, seed_payload('arjun-'||i, ((today - (i*2 - 1)) + time '17:30') at time zone ist, 12.976, 77.593, 5.0, 15.3, 'loop', 'IN-KA', 182, 166, allc));
  end loop;
  out := out || jsonb_build_object('arjun', r - 'card' || jsonb_build_object('card', r->'card'->>'name'));

  -- 2. Meera, 62, older endurance runner (elephant): 12 km at 7:10/km on the Marina, twice
  perform seed_user(meera, 'meera@pugmark.test', 'Meera', extract(year from today)::int - 62, 'female', 'IN-TN', allc);
  r := submit_run_for(meera, seed_payload('meera-1', ((today - 4) + time '05:50') at time zone ist, 13.052, 80.282, 12.0, 8.4, 'line', 'IN-TN', 152, 141, allc));
  r := submit_run_for(meera, seed_payload('meera-2', ((today - 1) + time '05:55') at time zone ist, 13.052, 80.282, 12.0, 8.4, 'line', 'IN-TN', 152, 139, allc));
  out := out || jsonb_build_object('meera', r - 'card' || jsonb_build_object('card', r->'card'->>'name'));

  -- 3. Ravi, 7-day streak: ran every day of last ISO week in Pune, 5 km at 5:27/km
  perform seed_user(ravi, 'ravi@pugmark.test', 'Ravi', extract(year from today)::int - 35, 'male', 'IN-MH', basic);
  for i in 0..6 loop
    r := submit_run_for(ravi, seed_payload('ravi-'||i, ((wk + i) + time '06:40') at time zone ist, 18.52 + i*0.004, 73.86, 5.0, 11.0, 'loop', 'IN-MH', 168, null, basic));
  end loop;
  r := issue_weekly_card_for(ravi, wk);
  out := out || jsonb_build_object('ravi_weekly', jsonb_build_object('run_days', r->'run_days', 'card', r->'card'->>'name', 'finish', r->'card'->>'finish'));

  -- 4. Priya, traveller: Bengaluru → Kochi → Goa inside 21 days (souvenirs + migratory bird)
  perform seed_user(priya, 'priya@pugmark.test', 'Priya', extract(year from today)::int - 30, 'female', 'IN-KA', allc);
  r := submit_run_for(priya, seed_payload('priya-1', ((today - 14) + time '07:10') at time zone ist, 12.934, 77.610, 5.0, 10.5, 'loop', 'IN-KA', 170, 150, allc));
  r := submit_run_for(priya, seed_payload('priya-2', ((today - 7)  + time '06:50') at time zone ist,  9.965, 76.280, 5.0, 10.5, 'loop', 'IN-KL', 170, 152, allc));
  r := submit_run_for(priya, seed_payload('priya-3', ((today - 2)  + time '07:00') at time zone ist, 15.492, 73.818, 5.0, 10.5, 'loop', 'IN-GA', 170, 149, allc));
  out := out || jsonb_build_object('priya', jsonb_build_object('flags', r->'flags', 'tier', r->'tier', 'card', r->'card'->>'name'));

  -- 5. Kabir, night owl: 22:15 start in Delhi, 4 km at 6:00/km
  perform seed_user(kabir, 'kabir@pugmark.test', 'Kabir', extract(year from today)::int - 38, 'male', 'IN-DL', allc);
  r := submit_run_for(kabir, seed_payload('kabir-1', ((today - 1) + time '22:15') at time zone ist, 28.613, 77.209, 4.0, 10.0, 'loop', 'IN-DL', 165, 148, allc));
  out := out || jsonb_build_object('kabir', jsonb_build_object('time_window', r->'time_window', 'tier', r->'tier', 'card', r->'card'->>'name'));

  -- 6. Sana, collector deliberately running slow for a rabbit: 3 km at 7:30/km
  perform seed_user(sana, 'sana@pugmark.test', 'Sana', extract(year from today)::int - 26, 'female', 'IN-TG', basic);
  r := submit_run_for(sana, seed_payload('sana-1', ((today - 3) + time '17:00') at time zone ist, 17.425, 78.450, 3.0, 8.0, 'loop', 'IN-TG', 150, null, basic));
  r := submit_run_for(sana, seed_payload('sana-2', ((today - 1) + time '17:05') at time zone ist, 17.425, 78.450, 3.0, 8.0, 'loop', 'IN-TG', 150, null, basic));
  out := out || jsonb_build_object('sana', jsonb_build_object('band', r->'band', 'perf_index', r->'perf_index', 'card', r->'card'->>'name'));

  return out;
end $$;

-- not callable by clients
revoke execute on function seed_dummy_users() from public, anon, authenticated;
revoke execute on function seed_user(uuid, text, text, int, sex_t, text, text[]) from public, anon, authenticated;
