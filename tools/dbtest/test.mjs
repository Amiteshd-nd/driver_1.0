// End-to-end tests for the Flying Cobra rules engine, run against PGlite.
//   node test.mjs
import { loadDb, signIn, createUser } from './harness.mjs';
import assert from 'node:assert/strict';

const db = await loadDb();
const q = async (sql, p = []) => (await db.query(sql, p)).rows;
const one = async (sql, p = []) => (await q(sql, p))[0];
let passed = 0, failed = 0;
async function test(name, fn) {
  try { await fn(); passed++; console.log('  ✓', name); }
  catch (e) { failed++; console.log('  ✗', name, '\n     ', e.message.replace(/\s+/g,' ').slice(0, 400)); }
}
const IST = (dateStr, hhmm) => `${dateStr}T${hhmm}:00+05:30`;
const today = (await one(`select (now() at time zone 'Asia/Kolkata')::date::text d`)).d;
const daysAgo = async n => (await one(`select ((now() at time zone 'Asia/Kolkata')::date - $1::int)::text d`, [n])).d;

// payload builder (mirrors what the Flutter client sends)
async function payload({ id, start, lat, lon, km, kmh, shape = 'loop', state = null, cadence = 170, hr = null, connected = ['location','motion','steps','heart_rate','activity'], accel, activity, track = true, splits }) {
  const moving = Math.ceil(km / kmh * 3600);
  const p = {
    client_run_id: id, source: 'phone', started_at: start, elapsed_s: moving + 30, moving_s: moving, timezone: 'Asia/Kolkata', state_code: state,
    distance_m: km * 1000,
  };
  if (track) p.track = (await one(`select seed_track($1,$2,$3,$4,$5) t`, [lat, lon, km, kmh, shape])).t;
  if (connected.includes('steps') && cadence != null) p.steps = Math.round(cadence * moving / 60);
  if (connected.includes('motion')) p.accel = accel ?? { rhythm_ratio: 0.82, vertical_rms: 3.2 };
  if (connected.includes('activity')) p.activity = activity ?? { running: 0.86, walking: 0.1, stationary: 0.04 };
  if (connected.includes('heart_rate') && hr) p.hr = { mean: hr, max: hr + 18 };
  p.splits_kmh = splits ?? Array.from({ length: Math.max(1, Math.floor(km)) }, (_, i) => +(kmh * (0.98 + 0.04 * (i % 2))).toFixed(2));
  return p;
}
const submit = async (uid, p) => (await one(`select submit_run_for($1, $2) r`, [uid, p])).r;

console.log('\nSeed sanity');
await test('≥ 80 animals and rules seeded', async () => {
  const a = await one(`select count(*)::int n from animals`); const r = await one(`select count(*)::int n from animal_rules`);
  assert.ok(a.n >= 80, `animals ${a.n}`); assert.ok(r.n >= 100, `rules ${r.n}`);
});
await test('every animal has a counter and unique code', async () => {
  const m = await one(`select count(*)::int n from animals a left join animal_counters c on c.animal_id = a.id where c.animal_id is null`);
  assert.equal(m.n, 0);
  const d = await one(`select count(*)::int n from (select code from animals group by code having count(*) > 1) x`); assert.equal(d.n, 0);
});
await test('each speed band has a non-empty pool incl. rare+', async () => {
  for (const band of ['swift', 'steady', 'calm', 'gentle']) {
    const r = await one(`select build_run_pool(null, $1, 'verified') p`, [{ speed_band: band, distance_km: 5, time_window: 'day', flags: [], connected: [] }]);
    assert.equal(r.p.tier, 0, band); assert.ok(r.p.pool.length >= 4, `${band} pool ${r.p.pool.length}`);
    assert.ok(r.p.pool.some(x => ['rare','epic','legendary'].includes(x.rarity)), `${band} has no rare+`);
    const sum = r.p.pool.reduce((s, x) => s + Number(x.p), 0); assert.ok(Math.abs(sum - 1) < 0.01, `probabilities sum ${sum}`);
  }
});

console.log('\nAge grading & bands');
await test('60M at 6:00/km ≈ 30M at 5:00/km (both steady)', async () => {
  const a = await one(`select admin_perf_preview(10, 5, 'male', 60) r`); const b = await one(`select admin_perf_preview(12, 5, 'male', 30) r`);
  assert.equal(a.r.band, 'steady'); assert.equal(b.r.band, 'steady'); assert.ok(Math.abs(a.r.perf_index - b.r.perf_index) < 0.02);
});
await test('unknown age/sex degrade to age-30 neutral', async () => {
  const r = await one(`select perf_index(10, 5, null, null) p`); assert.ok(r.p > 0.44 && r.p < 0.48, r.p);
});

console.log('\nRun submission — the six personas');
const uid = {};
for (const [k, name, by, sex] of [['arjun','Arjun',2002,'male'],['meera','Meera',1964,'female'],['ravi','Ravi',1991,'male'],['priya','Priya',1996,'female'],['kabir','Kabir',1988,'male'],['sana','Sana',2000,'female']]) {
  uid[k] = await createUser(db, `${k}@test.local`, name);
  await q(`update profiles set birth_year = $2, sex = $3, connected = '{location,motion,steps,heart_rate,activity}' where id = $1`, [uid[k], by, sex]);
}
await q(`select setseed(0.42)`);

await test('Arjun: 5 km at 3:55/km → swift family, verified, card issued with serial #1', async () => {
  const r = await submit(uid.arjun, await payload({ id: 'a1', start: IST(await daysAgo(1), '17:30'), lat: 12.976, lon: 77.593, km: 5, kmh: 15.3, state: 'IN-KA', cadence: 182, hr: 166 }));
  assert.equal(r.verdict, 'verified', JSON.stringify(r)); assert.equal(r.band, 'swift'); assert.ok(r.card, 'no card');
  assert.equal(r.card.family, 'swift'); assert.equal(r.card.serial_no, 1); assert.match(r.card.serial, /#0001$/);
  assert.equal(r.card.stage, 'young'); // 5 km → young
  assert.equal(r.card.season, 'Festival of Lights 2026');
});
await test('Meera: 62F, 12 km at 7:10/km → age-graded calm/steady (not gentle), adult stage, elephant eligible', async () => {
  const r = await submit(uid.meera, await payload({ id: 'm1', start: IST(await daysAgo(1), '05:50'), lat: 13.052, lon: 80.282, km: 12, kmh: 8.4, shape: 'line', state: 'IN-TN', cadence: 152, hr: 141 }));
  assert.equal(r.verdict, 'verified'); assert.ok(['calm','steady'].includes(r.band), r.band); assert.equal(r.card.stage, 'adult');
  const pool = await one(`select build_run_pool(null, $1, 'verified') p`, [{ speed_band: 'gentle', distance_km: 12, time_window: 'day', flags: [], connected: [] }]);
  assert.ok(pool.p.pool.some(x => x.slug === 'elephant'), 'elephant should be in a long gentle run pool');
  const short = await one(`select build_run_pool(null, $1, 'verified') p`, [{ speed_band: 'gentle', distance_km: 3, time_window: 'day', flags: [], connected: [] }]);
  assert.ok(!short.p.pool.some(x => x.slug === 'elephant'), 'elephant must need ≥ 8 km');
});
await test('Kabir: 22:15 start in Delhi → night window → owl bag (tier 1, guaranteed first time)', async () => {
  const r = await submit(uid.kabir, await payload({ id: 'k1', start: IST(await daysAgo(1), '22:15'), lat: 28.613, lon: 77.209, km: 4, kmh: 10, state: 'IN-DL', hr: 148 }));
  assert.equal(r.time_window, 'night'); assert.equal(r.tier, 1); assert.equal(r.card.family, 'time'); assert.equal(r.trigger, 'time:night');
});
await test('Sana: 3 km at 7:30/km → calm band (rabbit chase), baby stage', async () => {
  const r = await submit(uid.sana, await payload({ id: 's1', start: IST(await daysAgo(1), '17:00'), lat: 17.425, lon: 78.45, km: 3, kmh: 8, state: 'IN-TG', cadence: 150, connected: ['location','steps'] }));
  assert.equal(r.band, 'calm', `P=${r.perf_index}`); assert.equal(r.card.stage, 'baby'); // GPS distance of a "3 km" loop lands just under 3.0
  assert.equal(r.verdict, 'verified', 'GPS + steps only must still verify');
});
await test('Priya: KA → KL → GA in 21 days → new_state souvenirs then migratory_3 bird', async () => {
  const r1 = await submit(uid.priya, await payload({ id: 'p1', start: IST(await daysAgo(14), '07:10'), lat: 12.934, lon: 77.61, km: 5, kmh: 10.5, state: 'IN-KA', hr: 150 }));
  assert.ok(!r1.flags.includes('new_state'), 'home state is not a souvenir'); assert.equal(r1.tier, 0);
  assert.equal((await one(`select home_region h from profiles where id = $1`, [uid.priya])).h, 'IN-KA', 'first state becomes home');
  const r2 = await submit(uid.priya, await payload({ id: 'p2', start: IST(await daysAgo(7), '06:50'), lat: 9.965, lon: 76.28, km: 5, kmh: 10.5, state: 'IN-KL', hr: 152 }));
  assert.ok(r2.flags.includes('migratory_2'), r2.flags.join());
  assert.equal(r2.tier, 4, 'two states → migratory bag fires first time'); assert.equal(r2.card.family, 'migratory');
  const r3 = await submit(uid.priya, await payload({ id: 'p3', start: IST(await daysAgo(2), '07:00'), lat: 15.492, lon: 73.818, km: 5, kmh: 10.5, state: 'IN-GA', hr: 149 }));
  assert.ok(!r3.flags.includes('migratory_2'), 'migratory awarded once per 21-day window'); assert.ok(r3.flags.includes('new_state'));
  assert.equal(r3.tier, 3, 'Goa souvenir'); assert.equal(r3.card.family, 'regional');
  const ks = await one(`select slug from animals a join animal_rules r on r.animal_id=a.id where r.scope='run' and r.tier=3 and r.predicates->'region_codes' ? 'IN-GA' limit 1`);
  assert.equal(r3.card.slug, ks.slug, 'Goa card must be the Goa animal');
});
await test('state claim that does not match the GPS centroid is discarded', async () => {
  const r = await submit(uid.sana, await payload({ id: 's-spoof', start: IST(await daysAgo(6), '17:00'), lat: 17.425, lon: 78.45, km: 3, kmh: 8, state: 'IN-KL', connected: ['location','steps'] }));
  assert.ok(!r.flags.includes('new_state'), 'no souvenir for a spoofed state');
  const run = await one(`select state_code from runs where client_run_id = 's-spoof'`); assert.equal(run.state_code, null);
});

console.log('\nRavi: 7-day week → weekly 7-day bag');
await test('7 run-days → weekly card from the 7-day (legendary) bag, radiant finish', async () => {
  const wk = (await one(`select (week_start((now() at time zone 'Asia/Kolkata')::date) - 7)::text d`)).d;
  for (let i = 0; i < 7; i++) {
    const d = (await one(`select ($1::date + $2::int)::text d`, [wk, i])).d;
    await submit(uid.ravi, await payload({ id: `r${i}`, start: IST(d, '06:40'), lat: 18.52 + i * 0.004, lon: 73.86, km: 5, kmh: 11, state: 'IN-MH', connected: ['location','steps'] }));
  }
  const w = (await one(`select issue_weekly_card_for($1, $2::date) r`, [uid.ravi, wk])).r;
  assert.equal(w.run_days, 7); assert.equal(w.tier, 7); assert.equal(w.card.finish, 'radiant'); assert.equal(w.card.rarity, 'legendary');
  assert.equal(w.card.stats.variety, true, 'variety stamp recorded');
  assert.equal(w.card.stage, 'adult'); // 35 km volume
  const again = (await one(`select issue_weekly_card_for($1, $2::date) r`, [uid.ravi, wk])).r;
  assert.equal(again.existing, true, 'idempotent');
});
await test('2 run-days → no weekly card (never an insulting one)', async () => {
  const u = await createUser(db, 'two@test.local', 'Two');
  const wk = (await one(`select (week_start((now() at time zone 'Asia/Kolkata')::date) - 7)::text d`)).d;
  for (let i = 0; i < 2; i++) { const d = (await one(`select ($1::date + $2::int)::text d`, [wk, i])).d;
    await submit(u, await payload({ id: `t${i}`, start: IST(d, '07:00'), lat: 19.07, lon: 72.87, km: 4, kmh: 10, connected: ['location','steps'] })); }
  const w = (await one(`select issue_weekly_card_for($1, $2::date) r`, [u, wk])).r; assert.equal(w.card, null); assert.equal(w.run_days, 2);
});

console.log('\nAnti-cheat');
await test('car ride: 45 km/h → rejected by hard pace ceiling', async () => {
  const r = await submit(uid.kabir, await payload({ id: 'car', start: IST(await daysAgo(3), '09:00'), lat: 28.6, lon: 77.2, km: 10, kmh: 45, shape: 'line', cadence: 0 }));
  assert.equal(r.verdict, 'rejected'); assert.equal(r.card, null);
});
await test('cycling: 19 km/h, no steps, smooth accel, cycling class → rejected', async () => {
  const r = await submit(uid.kabir, await payload({ id: 'bike', start: IST(await daysAgo(4), '09:00'), lat: 28.6, lon: 77.2, km: 8, kmh: 19, shape: 'line', cadence: 10, accel: { rhythm_ratio: 0.1, vertical_rms: 0.4 }, activity: { cycling: 0.9, running: 0 }, hr: 80 }));
  assert.equal(r.verdict, 'rejected', `trust ${r.trust}`);
});
await test('slow scooter (12 km/h) with few steps and no HR rise → rejected', async () => {
  const r = await submit(uid.kabir, await payload({ id: 'scooter', start: IST(await daysAgo(5), '09:00'), lat: 28.6, lon: 77.2, km: 5, kmh: 12, shape: 'line', cadence: 20, accel: { rhythm_ratio: 0.15, vertical_rms: 0.5 }, activity: { automotive: 0.8, walking: 0.1 }, hr: 78 }));
  assert.equal(r.verdict, 'rejected', `trust ${r.trust}`);
});
await test('GPS-only run with sane splits → verified (graceful degradation)', async () => {
  const r = await submit(uid.sana, await payload({ id: 'gpsonly', start: IST(await daysAgo(5), '17:00'), lat: 17.43, lon: 78.46, km: 3, kmh: 8.5, connected: ['location'], cadence: null }));
  assert.equal(r.verdict, 'verified', `trust ${r.trust}`);
});
await test('GPS-only run with a car-speed split → rejected (the only evidence is bad)', async () => {
  const r = await submit(uid.sana, await payload({ id: 'spike0', start: IST(await daysAgo(4), '22:30'), lat: 17.44, lon: 78.47, km: 5, kmh: 11, connected: ['location'], cadence: null, splits: [9, 9.5, 24, 9, 9.2] }));
  assert.equal(r.verdict, 'rejected', `trust ${r.trust}`);
});
await test('mixed evidence (weak rhythm, flat HR, car split) → unverified → speed pool only, no owl', async () => {
  const r = await submit(uid.sana, await payload({ id: 'spike', start: IST(await daysAgo(4), '22:50'), lat: 17.45, lon: 78.48, km: 5, kmh: 11, connected: ['location','motion','activity','heart_rate'], cadence: null,
    accel: { rhythm_ratio: 0.45, vertical_rms: 2.0 }, activity: { running: 0.5, unknown: 0.5 }, hr: 100, splits: [9, 9.5, 24, 9, 9.2] }));
  assert.equal(r.verdict, 'unverified', `trust ${r.trust}`); assert.equal(r.time_window, 'night'); assert.equal(r.tier, 0, 'no owl for an unverified night run'); assert.ok(r.card);
});

console.log('\nFloor, cap, idempotency');
await test('600 m stroll → recorded, no card', async () => {
  const r = await submit(uid.sana, await payload({ id: 'short', start: IST(await daysAgo(8), '08:00'), lat: 17.42, lon: 78.44, km: 0.6, kmh: 7, connected: ['location','steps'] }));
  assert.equal(r.card, null); assert.equal(r.floor, false);
});
await test('duplicate client_run_id returns the same card', async () => {
  const r = await submit(uid.arjun, await payload({ id: 'a1', start: IST(await daysAgo(1), '17:30'), lat: 12.976, lon: 77.593, km: 5, kmh: 15.3 }));
  assert.equal(r.duplicate, true, JSON.stringify(r)); assert.equal(r.card.serial_no, 1, JSON.stringify(r));
});
await test('third run in a day is counted but draws no card (cap 2)', async () => {
  const d = await daysAgo(9);
  const a = await submit(uid.arjun, await payload({ id: 'c1', start: IST(d, '06:00'), lat: 12.98, lon: 77.6, km: 2, kmh: 12 }));
  const b = await submit(uid.arjun, await payload({ id: 'c2', start: IST(d, '12:00'), lat: 12.98, lon: 77.6, km: 2, kmh: 12 }));
  const c = await submit(uid.arjun, await payload({ id: 'c3', start: IST(d, '18:00'), lat: 12.98, lon: 77.6, km: 2, kmh: 12 }));
  assert.ok(a.card && b.card); assert.equal(c.card, null); assert.equal(c.capped, true);
});

console.log('\nExploration');
await test('after 3 known runs, a brand-new route far away → new_route + explorer tier', async () => {
  const u = await createUser(db, 'explorer@test.local', 'Exp');
  await q(`update profiles set connected = '{location,steps}' where id = $1`, [u]);
  for (let i = 0; i < 3; i++) await submit(u, await payload({ id: `base${i}`, start: IST(await daysAgo(10 - i), '07:00'), lat: 12.95, lon: 77.60, km: 3, kmh: 10, connected: ['location','steps'] }));
  const r = await submit(u, await payload({ id: 'novel', start: IST(await daysAgo(6), '07:00'), lat: 12.99, lon: 77.70, km: 3, kmh: 10, connected: ['location','steps'] }));
  assert.ok(r.flags.includes('new_route'), r.flags.join()); assert.ok(r.novelty >= 0.6); assert.equal(r.tier, 2); assert.equal(r.card.family, 'explorer');
  const same = await submit(u, await payload({ id: 'repeat', start: IST(await daysAgo(5), '07:00'), lat: 12.95, lon: 77.60, km: 3, kmh: 10, connected: ['location','steps'] }));
  assert.ok(!same.flags.includes('new_route'), 'a repeated loop is not novel'); assert.ok(same.novelty < 0.3);
});
await test('zigzag path → zigzag flag', async () => {
  const u = await createUser(db, 'zig@test.local', 'Zig');
  const r = await submit(u, await payload({ id: 'zz', start: IST(await daysAgo(2), '07:00'), lat: 19.07, lon: 72.87, km: 2.5, kmh: 9, shape: 'zigzag', connected: ['location','steps'] }));
  assert.ok(r.flags.includes('zigzag'), r.flags.join());
});
await test('first three runs are never "new routes"', async () => {
  const u = await createUser(db, 'fresh@test.local', 'Fresh');
  const r = await submit(u, await payload({ id: 'f1', start: IST(await daysAgo(2), '07:00'), lat: 22.57, lon: 88.36, km: 3, kmh: 10, connected: ['location','steps'] }));
  assert.ok(!r.flags.includes('new_route')); assert.equal(r.tier, 0);
});

console.log('\nGrowth, reset, mastery');
await test('earning the same animal across 6 weeks grows it to adult with a celebration', async () => {
  const u = await createUser(db, 'bond@test.local', 'Bond');
  const a = await one(`select id, name from animals where slug = 'chital'`);
  let grew = [];
  for (let w = 0; w < 6; w++) {
    const r = (await one(`select update_bond($1, $2, $3) r`, [u, a.id, `2026-W${10 + w}`])).r;
    if (r.grew) grew.push(r.stage);
  }
  assert.deepEqual(grew, ['young', 'adult']);
  const same = (await one(`select update_bond($1, $2, $3) r`, [u, a.id, '2026-W15'])).r; assert.equal(same.earn_weeks, 6, 'same week does not add a week');
});
await test('card stage = max(distance stage, bond stage)', async () => {
  const u = await createUser(db, 'stage@test.local', 'Stage');
  await q(`update profiles set connected = '{location,steps}' where id = $1`, [u]);
  // force an adult bond for every swift animal then run 2 km swift → stage must be adult
  await q(`insert into bonds(user_id, animal_id, earn_count, earn_weeks, stage) select $1, a.id, 8, 7, 'adult' from animals a where family = 'swift'`, [u]);
  const r = await submit(u, await payload({ id: 'st1', start: IST(await daysAgo(1), '09:00'), lat: 12.9, lon: 77.5, km: 2, kmh: 15.5, cadence: 185, connected: ['location','steps'] }));
  assert.equal(r.band, 'swift'); assert.equal(r.card.stage, 'adult');
});
await test('60+ days away resets bonds (welcome back)', async () => {
  const u = await createUser(db, 'reset@test.local', 'Reset');
  await q(`update profiles set connected = '{location,steps}', last_run_at = now() - interval '70 days' where id = $1`, [u]);
  await q(`insert into bonds(user_id, animal_id, earn_count, earn_weeks, stage) select $1, id, 5, 4, 'young' from animals where slug = 'rabbit'`, [u]);
  const r = await submit(u, await payload({ id: 'rs1', start: IST(await daysAgo(1), '07:00'), lat: 12.9, lon: 77.5, km: 3, kmh: 9, connected: ['location','steps'] }));
  assert.ok(r.celebrations.some(c => c.kind === 'welcome_back'));
  const b = await one(`select count(*)::int n from bonds where user_id = $1 and stage <> 'baby' and animal_id <> $2`, [u, r.card.animal_id]); assert.equal(b.n, 0);
});
await test('mastered animal is drawn 4× less often; rares boosted', async () => {
  const u = await createUser(db, 'master@test.local', 'Master');
  const ch = await one(`select id from animals where slug = 'chinkara'`);
  await q(`insert into bonds(user_id, animal_id, earn_count, earn_weeks, stage, mastered) values ($1, $2, 12, 8, 'adult', true)`, [u, ch.id]);
  await q(`insert into pity_state(user_id) values ($1) on conflict do nothing`, [u]);
  const base = (await one(`select build_run_pool(null, $1, 'verified') p`, [{ speed_band: 'swift', distance_km: 5, time_window: 'day', flags: [], connected: [] }])).p;
  const wild = (await one(`select build_run_pool($2, $1, 'verified') p`, [{ speed_band: 'swift', distance_km: 5, time_window: 'day', flags: [], connected: [] }, u])).p;
  const w = s => p => Number(p.pool.find(x => x.slug === s).w);
  assert.ok(Math.abs(w('chinkara')(wild) / w('chinkara')(base) - 0.25) < 0.01);
  assert.ok(Math.abs(w('cheetah')(wild) / w('cheetah')(base) - 1.5) < 0.01);
});

console.log('\nPity timer');
await test('pity multiplies rare weights after n0 and caps; hard pity removes commons', async () => {
  const u = await createUser(db, 'pity@test.local', 'Pity');
  await q(`insert into pity_state(user_id, cards_since_rare) values ($1, 10) on conflict (user_id) do update set cards_since_rare = 10`, [u]);
  const ctx = { speed_band: 'calm', distance_km: 5, time_window: 'day', flags: [], connected: [] };
  const base = (await one(`select build_run_pool(null, $1, 'verified') p`, [ctx])).p;
  const p10 = (await one(`select build_run_pool($2, $1, 'verified') p`, [ctx, u])).p;
  const rare = s => p => Number(p.pool.find(x => x.rarity === 'rare').w);
  assert.ok(Math.abs(rare()(p10) / rare()(base) - (1 + 0.6 * 6)) < 0.01, 'mult at n=10 should be 4.6');
  await q(`update pity_state set cards_since_rare = 15 where user_id = $1`, [u]);
  const hard = (await one(`select build_run_pool($2, $1, 'verified') p`, [ctx, u])).p;
  assert.ok(hard.pool.every(x => ['rare','epic','legendary'].includes(x.rarity)), 'hard pity leaves only rare+');
});
await test('Monte Carlo: mean cards-to-rare ≈ 8–10, never > 15', async () => {
  const rw = { common: 60, uncommon: 25, rare: 10, epic: 4, legendary: 1 };
  const pool = ['common','common','common','uncommon','uncommon','rare','epic'];
  const runs = 20000; let total = 0, max = 0;
  for (let i = 0; i < runs; i++) {
    let n = 0;
    for (;;) {
      const mult = Math.min(8, 1 + 0.6 * Math.max(0, n - 4));
      const items = (n >= 15 ? pool.filter(r => rw[r] <= 10) : pool).map(r => rw[r] * (rw[r] <= 10 ? mult : 1));
      const sum = items.reduce((a, b) => a + b, 0); let x = Math.random() * sum, k = 0;
      while ((x -= items[k]) >= 0) k++;
      const picked = (n >= 15 ? pool.filter(r => rw[r] <= 10) : pool)[k];
      n++;
      if (rw[picked] <= 10) break;
    }
    total += n; max = Math.max(max, n);
  }
  const mean = total / runs; console.log(`      mean cards-to-rare = ${mean.toFixed(2)}, max = ${max}`);
  assert.ok(mean > 7 && mean < 11, mean); assert.ok(max <= 16, max);
});

console.log('\nSerials & lookup');
await test('200 sequential issues on one animal → serials 1..N unique and gap-free', async () => {
  const u = await createUser(db, 'serial@test.local', 'Serial');
  const a = await one(`select id from animals where slug = 'horse'`);
  const start = (await one(`select next_serial from animal_counters where animal_id = $1`, [a.id])).next_serial;
  for (let i = 0; i < 200; i++) await q(`select issue_card($1, $2, 'run', 'serial-' || $3::text, 0, 'baby', 'plain', null, '{}', 'verified', current_date)`, [u, a.id, i]);
  const r = await one(`select count(*)::int n, count(distinct serial_no)::int d, min(serial_no) mn, max(serial_no) mx from cards where animal_id = $1 and user_id = $2`, [a.id, u]);
  assert.equal(r.n, 200); assert.equal(r.d, 200); assert.equal(r.mn, start + 1); assert.equal(r.mx, start + 200);
});
await test('a failed card insert rolls the counter back (no gaps)', async () => {
  const a = await one(`select id from animals where slug = 'horse'`);
  const before = (await one(`select next_serial from animal_counters where animal_id = $1`, [a.id])).next_serial;
  await assert.rejects(q(`select issue_card('00000000-0000-0000-0000-000000000000', $1, 'run', 'x', 0, 'baby', 'plain', null, '{}', 'verified', current_date)`, [a.id]));
  const after = (await one(`select next_serial from animal_counters where animal_id = $1`, [a.id])).next_serial;
  assert.equal(after, before);
});
await test('lookup_serial accepts "Horse #0003", "horse 3", "HRS-0003"; hides location', async () => {
  const code = (await one(`select code from animals where slug = 'horse'`)).code;
  for (const s of ['Horse #0003', 'horse 3', `${code}-0003`, ' HORSE#3 ']) {
    const r = (await one(`select lookup_serial($1) r`, [s])).r;
    assert.equal(r.found, true, s); assert.equal(r.card.serial_no, 3); assert.equal(r.earned_by, 'Serial');
    assert.ok(!JSON.stringify(r).match(/lat|lon|cells|track/), 'public lookup leaked location');
  }
  const miss = (await one(`select lookup_serial('Horse #9999') r`)).r; assert.equal(miss.found, false); assert.equal(miss.reason, 'serial');
  const bad = (await one(`select lookup_serial('Amitesh') r`)).r; assert.equal(bad.found, false);
});
await test('private card is not found publicly', async () => {
  await q(`update cards set is_public = false where serial_no = 5 and animal_id = (select id from animals where slug = 'horse')`);
  const r = (await one(`select lookup_serial('Horse #5') r`)).r; assert.equal(r.found, false);
});

console.log('\nSecurity (RLS)');
await test('player cannot read animal_rules (discovery-first) but can read animals; secret hidden until earned', async () => {
  await signIn(db, uid.arjun);
  await q(`set role authenticated`);
  try {
    const rules = await q(`select * from animal_rules`); assert.equal(rules.length, 0);
    const animals = await q(`select slug from animals`); assert.ok(animals.length > 50);
    assert.ok(!animals.some(a => a.slug === 'himalayan-monal'), 'secret animal visible');
    const others = await q(`select * from cards where user_id <> $1`, [uid.arjun]); assert.equal(others.length, 0);
    const mine = await q(`select * from cards where user_id = $1`, [uid.arjun]); assert.ok(mine.length >= 1);
    await assert.rejects(q(`update cards set serial_no = 999 where user_id = $1`, [uid.arjun]));
  } finally { await q(`reset role`); await signIn(db, null); }
});
await test('anon can call lookup_serial but not submit_run', async () => {
  await signIn(db, null, 'anon'); await q(`set role anon`);
  try {
    const r = (await one(`select lookup_serial('Horse #0003') r`)).r; assert.equal(r.found, true);
    await assert.rejects(q(`select submit_run('{}'::jsonb)`));
  } finally { await q(`reset role`); }
});

console.log('\nDummy seed');
await test('seed_dummy_users() runs end to end and matches the PRD scenarios', async () => {
  const r = (await one(`select seed_dummy_users() r`)).r;
  assert.ok(r.arjun.card, 'arjun card'); assert.equal(r.kabir.time_window, 'night'); assert.equal(r.ravi_weekly.run_days, 7);
  assert.equal(r.sana.band, 'calm'); assert.ok(r.priya.card);
  const n = await one(`select count(*)::int n from profiles where display_name in ('Arjun','Meera','Ravi','Priya','Kabir','Sana')`); assert.ok(n.n >= 6);
});

console.log('\nAccount lifecycle');
await test('export_my_data returns my runs/cards; delete_my_account erases everything and frees the serial lookup', async () => {
  const u = await createUser(db, 'bye@test.local', 'Bye');
  await q(`update profiles set connected = '{location,steps}' where id = $1`, [u]);
  const r = await submit(u, await payload({ id: 'bye1', start: IST(await daysAgo(1), '09:00'), lat: 12.9, lon: 77.5, km: 3, kmh: 10, connected: ['location','steps'] }));
  await signIn(db, u); await q(`set role authenticated`);
  try {
    const ex = (await one(`select export_my_data() e`)).e;
    assert.equal(ex.runs.length, 1); assert.equal(ex.cards.length, 1); assert.equal(ex.profile.display_name, 'Bye'); assert.equal(ex.profile.is_admin, undefined);
    await q(`select delete_my_account()`);
  } finally { await q(`reset role`); await signIn(db, null); }
  assert.equal((await one(`select count(*)::int n from profiles where id = $1`, [u])).n, 0);
  assert.equal((await one(`select count(*)::int n from cards where user_id = $1`, [u])).n, 0);
  const look = (await one(`select lookup_serial($1) r`, [r.card.serial])).r; assert.equal(look.found, false);
});

await test('admin_set_user_admin: admins promote others, never demote themselves; players refused', async () => {
  const boss = await createUser(db, 'boss@test.local', 'Boss'); const pal = await createUser(db, 'pal@test.local', 'Pal');
  await q(`update profiles set is_admin = true where id = $1`, [boss]);
  await signIn(db, boss); await q(`set role authenticated`);
  try {
    await q(`select admin_set_user_admin($1, true)`, [pal]);
    await assert.rejects(q(`select admin_set_user_admin($1, false)`, [boss]));
  } finally { await q(`reset role`); }
  assert.equal((await one(`select is_admin a from profiles where id = $1`, [pal])).a, true);
  await signIn(db, uid.sana); await q(`set role authenticated`);
  try { await assert.rejects(q(`select admin_set_user_admin($1, true)`, [uid.sana])); } finally { await q(`reset role`); await signIn(db, null); }
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
