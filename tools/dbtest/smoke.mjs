import { loadDb } from './harness.mjs';
const db = await loadDb({ log: m => console.log('  ', m) });
const q = async (sql, p=[]) => (await db.query(sql, p)).rows;
console.log('age_factor 60M', (await q(`select age_factor('male',60) f`))[0].f, '| 62F', (await q(`select age_factor('female',62) f`))[0].f, '| 57 unknown', (await q(`select age_factor(null,57) f`))[0].f, '| 25M', (await q(`select age_factor('male',25) f`))[0].f);
console.log('v_std 5k M/F', (await q(`select v_std_kmh('male',5) m, v_std_kmh('female',5) f, v_std_kmh(null,10) u`))[0]);
console.log('P 30M 6:00/km 5k', (await q(`select perf_index(10,5,'male',30) p, speed_band(perf_index(10,5,'male',30)) b`))[0]);
console.log('P 60M 6:00/km 5k', (await q(`select perf_index(10,5,'male',60) p, speed_band(perf_index(10,5,'male',60)) b`))[0]);
console.log('P 30M 4:00/km', (await q(`select perf_index(15,5,'male',30) p, speed_band(perf_index(15,5,'male',30)) b`))[0]);
console.log('P 30M 8:30/km', (await q(`select perf_index(7.06,5,'male',30) p, speed_band(perf_index(7.06,5,'male',30)) b`))[0]);
console.log('geohash Bengaluru 12.9716,77.5946 →', (await q(`select geohash_encode(12.9716,77.5946,7) g7, geohash_encode(12.9716,77.5946,5) g5, geohash_encode(12.9716,77.5946,4) g4`))[0], '(expected tdr1y8...)');
console.log('haversine BLR→Chennai km', (await q(`select round((haversine_m(12.9716,77.5946,13.0827,80.2707)/1000)::numeric,1) d`))[0].d, '(≈290)');
console.log('minetti ratios', (await q(`select round(minetti_ratio(0)::numeric,3) flat, round(minetti_ratio(0.05)::numeric,3) up5, round(minetti_ratio(0.10)::numeric,3) up10, round(minetti_ratio(-0.05)::numeric,3) dn5, round(minetti_ratio(-0.2)::numeric,3) dn20`))[0]);
const se = (await q(`select (solar_events(12.9716,77.5946,'2026-10-02')).sunrise at time zone 'Asia/Kolkata' rise, (solar_events(12.9716,77.5946,'2026-10-02')).sunset at time zone 'Asia/Kolkata' sett`))[0];
console.log('BLR sunrise/sunset IST 2026-10-02', se, '(expect ≈06:10 / 18:10)');
const sk = (await q(`select (solar_events(25.67,94.11,'2026-10-02')).sunrise at time zone 'Asia/Kolkata' rise, (solar_events(25.67,94.11,'2026-10-02')).sunset at time zone 'Asia/Kolkata' sett`))[0];
console.log('Kohima sunrise/sunset IST', sk, '(expect ≈05:10 / 17:10)');
for (const t of ['2026-10-02T05:45:00+05:30','2026-10-02T09:00:00+05:30','2026-10-02T18:00:00+05:30','2026-10-02T22:15:00+05:30','2026-10-02T03:00:00+05:30'])
  console.log('window', t, (await q(`select (time_window_of($1::timestamptz,12.9716,77.5946,'Asia/Kolkata')).win w`,[t]))[0].w);
// synthetic track: 5 km straight-ish north at 12 km/h (3.33 m/s), 1 pt / 5 s, alt rising 50 m over the run
const pts=[]; for(let i=0;i<=300;i++){ const d=i*5*3.333; pts.push([12.9716+d/111320,77.5946,900+50*i/300,i*5,8]); }
const tr=(await q(`select * from analyze_track($1::jsonb)`,[JSON.stringify(pts)]))[0];
console.log('track straight 5k', {dist:Math.round(tr.distance_m), flat_eq:Math.round(tr.flat_eq_m), gain:Math.round(tr.elev_gain_m), cells:tr.cells.length, turns:tr.turns_per_km, max1:Math.round(tr.max_1min_kmh*10)/10, kept:tr.kept_points});
// zigzag: alternate east/north every 60 m
const zz=[]; let lat=12.97,lon=77.59,t=0; for(let i=0;i<60;i++){ for(let k=0;k<4;k++){ if(i%2) lat+=15/111320; else lon+=15/(111320*Math.cos(12.97*Math.PI/180)); t+=4.5; zz.push([lat,lon,null,t,10]); } }
const z=(await q(`select * from analyze_track($1::jsonb)`,[JSON.stringify(zz)]))[0];
console.log('track zigzag', {dist:Math.round(z.distance_m), turns_per_km:Math.round(z.turns_per_km*10)/10, cells:z.cells.length});
