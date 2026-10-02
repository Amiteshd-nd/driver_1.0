-- Pugmark · 0004 config seed
-- Every number here is editable in the admin panel (Config tab). Defaults per docs/ALGORITHMS.md.

insert into config(key, value, description) values
('app', '{"name":"Pugmark","verify_base_url":"https://pugmark.run/v","serial_pad":4}', 'Branding and public verify URL base'),
('floor', '{"min_km":1.0,"min_moving_s":600,"min_speed_kmh":6.0}', '§1 eligibility floor for any card'),
('limits', '{"max_run_cards_per_day":2,"max_track_points":2000}', '§1 anti-farming caps'),
('age_grading', '{"d_ref_km":5,"riegel_exponent":1.06,"min_d_eff_km":1.5,"t_ref_s":{"male":755,"female":840,"unknown":796},"default_age":30}', '§2 Riegel open standards'),
('speed_bands', '{"swift":0.60,"steady":0.47,"calm":0.35}', '§3 lower P bound of each band; below calm = gentle'),
('stage_thresholds', '{"run":{"young":3,"adult":7},"weekly":{"young":10,"adult":25},"monthly":{"young":30,"adult":80}}', '§4.1 km thresholds for baby→young→adult'),
('bond', '{"young_weeks":3,"adult_weeks":6,"mastered_earns":10,"reset_after_days":60}', '§4.2 growth from consistency'),
('finish_thresholds', '{"run":{"glow":4,"radiant":7},"weekly":{"glow":5,"radiant":7},"monthly":{"glow":12,"radiant":20}}', '§5 run-days needed for glow/radiant'),
('rarity_weights', '{"common":60,"uncommon":25,"rare":10,"epic":4,"legendary":1}', '§6.2 base draw weights'),
('pity', '{"n0":4,"k":0.6,"cap":8,"hard_pity":15}', '§6.3 pity timer'),
('wild', '{"mastered_weight_mult":0.25,"rare_boost":1.5}', '§4.2 Unlock the Wild'),
('weekly', '{"min_run_days":3,"tiers":[3,5,7]}', '§7 weekly card'),
('monthly', '{"min_runs":4}', '§8 monthly card'),
('explore', '{"novelty_new_route":0.60,"novelty_untraced_min":0.30,"min_cells":6,"min_prior_runs":3,"familiar_area_runs":3,"zigzag_turns_per_km":8,"zigzag_min_km":1.5,"turn_deg":60,"history_days":180}', '§9.3 exploration'),
('migratory', '{"window_days":21,"states_for_2":2,"states_for_3":3}', '§9.5 migratory birds'),
('track', '{"max_accuracy_m":50,"max_jump_kmh":30,"resample_m":25}', '§9.1 track hygiene'),
('time_windows', '{"dawn_before_min":45,"dawn_after_min":30,"dusk_before_min":15,"dusk_after_min":45,"night_after_sunset_min":60}', '§9.6 solar windows'),
('anticheat', '{
  "hard":{"max_avg_kmh":20,"max_1min_kmh":24},
  "stride":{"w":2.0,"ok_min":0.6,"ok_max":2.4,"bad":3.0},
  "cadence":{"w":1.5,"ok_min":140,"ok_max":200,"walk_min":100,"bad":60},
  "rhythm":{"w":2.0,"ok":0.6,"mid":0.3,"min_rms":0.8,"rms_speed_kmh":8},
  "activity":{"w":1.5,"ok":0.7,"bad":0.3},
  "consistency":{"w":1.0,"cv_ok":0.25,"spike_ratio":1.8,"spike_kmh":18},
  "hr":{"w":2.5,"mean_ok":110,"max_ok":130,"mean_bad":85,"bad_speed_kmh":9},
  "verified":0.60,"unverified":0.40
}', '§10 trust score evidence weights'),
('copy', '{"rejected":"We couldn''t confirm this one was a run — no card this time.","unverified":"We couldn''t fully verify this run, so it drew from the everyday pool.","no_weekly":"No weekly card this week — three run-days opens the weekly bag."}', 'User-facing microcopy for engine outcomes')
on conflict (key) do update set value = excluded.value, description = excluded.description;

-- §2.2 age factors (approximate WMA-2020 road shape; replace knots from the admin panel if licensed tables are adopted)
insert into age_factors(sex, age, factor) values
('male',10,0.700),('male',12,0.780),('male',14,0.860),('male',16,0.930),('male',18,0.980),('male',20,1.000),('male',30,1.000),
('male',35,0.985),('male',40,0.955),('male',45,0.925),('male',50,0.893),('male',55,0.860),('male',60,0.826),('male',65,0.788),
('male',70,0.746),('male',75,0.698),('male',80,0.640),('male',85,0.570),('male',90,0.490),
('female',10,0.740),('female',12,0.820),('female',14,0.900),('female',16,0.960),('female',18,0.990),('female',20,1.000),('female',30,1.000),
('female',35,0.983),('female',40,0.955),('female',45,0.920),('female',50,0.880),('female',55,0.840),('female',60,0.798),('female',65,0.752),
('female',70,0.700),('female',75,0.643),('female',80,0.578),('female',85,0.505),('female',90,0.425)
on conflict (sex, age) do update set factor = excluded.factor;

-- seasons (set names)
insert into seasons(name, slug, starts_on, ends_on, palette) values
('Monsoon 2026',            'monsoon-2026',   '2026-06-01', '2026-09-30', '{"primary":"#1F6F5F","accent":"#8FD3C7","foil":"teal"}'),
('Festival of Lights 2026', 'lights-2026',    '2026-10-01', '2027-01-31', '{"primary":"#7A2E0E","accent":"#F2B544","foil":"amber"}'),
('Spring Bloom 2027',       'bloom-2027',     '2027-02-01', '2027-05-31', '{"primary":"#5B3A8C","accent":"#F08BB0","foil":"rose"}'),
('Monsoon 2027',            'monsoon-2027',   '2027-06-01', '2027-09-30', '{"primary":"#1F6F5F","accent":"#8FD3C7","foil":"teal"}')
on conflict (slug) do nothing;

-- regions: ISO 3166-2:IN with coarse bounding boxes (sanity check for the on-device geocoder result)
insert into regions(code, name, kind, min_lat, max_lat, min_lon, max_lon, centroid_lat, centroid_lon) values
('IN-AP','Andhra Pradesh','state',12.60,19.10,76.80,84.80,15.91,79.74),
('IN-AR','Arunachal Pradesh','state',26.60,29.50,91.60,97.40,28.22,94.73),
('IN-AS','Assam','state',24.10,28.00,89.70,96.00,26.20,92.94),
('IN-BR','Bihar','state',24.30,27.50,83.30,88.30,25.10,85.31),
('IN-CT','Chhattisgarh','state',17.80,24.10,80.20,84.40,21.28,81.87),
('IN-GA','Goa','state',14.90,15.80,73.70,74.30,15.30,74.12),
('IN-GJ','Gujarat','state',20.10,24.70,68.20,74.50,22.26,71.19),
('IN-HR','Haryana','state',27.70,30.90,74.50,77.60,29.06,76.09),
('IN-HP','Himachal Pradesh','state',30.40,33.20,75.60,79.00,31.10,77.17),
('IN-JH','Jharkhand','state',21.90,25.30,83.30,87.90,23.61,85.28),
('IN-KA','Karnataka','state',11.60,18.50,74.00,78.60,15.32,75.71),
('IN-KL','Kerala','state',8.30,12.80,74.90,77.40,10.85,76.27),
('IN-MP','Madhya Pradesh','state',21.10,26.90,74.00,82.80,22.97,78.66),
('IN-MH','Maharashtra','state',15.60,22.00,72.60,80.90,19.75,75.71),
('IN-MN','Manipur','state',23.80,25.70,93.00,94.80,24.66,93.91),
('IN-ML','Meghalaya','state',25.00,26.10,89.80,92.80,25.47,91.37),
('IN-MZ','Mizoram','state',21.90,24.50,92.20,93.50,23.16,92.94),
('IN-NL','Nagaland','state',25.20,27.00,93.30,95.30,26.16,94.56),
('IN-OR','Odisha','state',17.80,22.60,81.40,87.50,20.95,85.10),
('IN-PB','Punjab','state',29.50,32.50,73.90,76.90,31.15,75.34),
('IN-RJ','Rajasthan','state',23.10,30.20,69.50,78.30,27.02,74.22),
('IN-SK','Sikkim','state',27.10,28.10,88.00,88.90,27.53,88.51),
('IN-TN','Tamil Nadu','state',8.10,13.60,76.20,80.40,11.13,78.66),
('IN-TG','Telangana','state',15.80,19.90,77.20,81.30,18.11,79.02),
('IN-TR','Tripura','state',22.90,24.50,91.10,92.40,23.94,91.99),
('IN-UP','Uttar Pradesh','state',23.90,30.40,77.10,84.60,26.85,80.95),
('IN-UT','Uttarakhand','state',28.70,31.50,77.60,81.10,30.07,79.02),
('IN-WB','West Bengal','state',21.50,27.20,85.80,89.90,22.99,87.85),
('IN-AN','Andaman and Nicobar Islands','ut',6.70,13.70,92.20,94.30,11.74,92.66),
('IN-CH','Chandigarh','ut',30.65,30.80,76.70,76.85,30.73,76.78),
('IN-DH','Dadra and Nagar Haveli and Daman and Diu','ut',20.00,20.80,72.70,73.30,20.27,73.02),
('IN-DL','Delhi','ut',28.40,28.90,76.80,77.35,28.61,77.21),
('IN-JK','Jammu and Kashmir','ut',32.30,35.00,73.80,76.90,33.78,76.58),
('IN-LA','Ladakh','ut',32.30,36.00,75.80,79.50,34.15,77.58),
('IN-LD','Lakshadweep','ut',8.20,12.40,71.60,74.10,10.57,72.64),
('IN-PY','Puducherry','ut',11.70,12.10,79.60,79.90,11.94,79.81),
('IN','India','country',6.50,37.10,68.00,97.50,22.00,79.00)
on conflict (code) do update set name = excluded.name, min_lat = excluded.min_lat, max_lat = excluded.max_lat,
  min_lon = excluded.min_lon, max_lon = excluded.max_lon, centroid_lat = excluded.centroid_lat, centroid_lon = excluded.centroid_lon;
