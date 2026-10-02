import { loadDb } from './harness.mjs';
const db = await loadDb();
const q = async (sql, p=[]) => (await db.query(sql, p)).rows;
console.log('geohash canonical (57.64911,10.40744) →', (await q(`select geohash_encode(57.64911,10.40744,11) g`))[0].g, 'expected u4pruydqqvj');
for (const [name,lat,lon] of [['Bengaluru',12.9716,77.5946],['Kohima',25.67,94.11],['Dwarka',22.24,68.97],['Delhi',28.61,77.21]]) {
  const r=(await q(`select to_char((solar_events($1,$2,'2026-10-02')).sunrise at time zone 'Asia/Kolkata','HH24:MI') rise, to_char((solar_events($1,$2,'2026-10-02')).sunset at time zone 'Asia/Kolkata','HH24:MI') sett`,[lat,lon]))[0];
  console.log(name.padEnd(10),'sunrise',r.rise,'sunset',r.sett,'IST');
}
for (const t of ['2026-10-02T05:45:00+05:30','2026-10-02T06:30:00+05:30','2026-10-02T09:00:00+05:30','2026-10-02T18:00:00+05:30','2026-10-02T19:30:00+05:30','2026-10-02T22:15:00+05:30','2026-10-02T03:00:00+05:30'])
  console.log('window BLR', t.slice(11,16), (await q(`select (time_window_of($1::timestamptz,12.9716,77.5946,'Asia/Kolkata')).win w`,[t]))[0].w);
