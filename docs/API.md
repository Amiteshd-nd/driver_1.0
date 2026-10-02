# Flying Cobra — Client ↔ Supabase contract

All game logic runs in Postgres. Clients (Flutter app, admin panel, verify page) use the Supabase JS/Dart SDK: tables under row-level security, plus the RPC functions below. Nothing else is needed.

## RPC (authenticated unless noted)

### `submit_run(p jsonb) → jsonb`
Submits one run. Idempotent on `client_run_id`.

Payload:
```json
{
  "client_run_id": "uuid-from-device",
  "source": "phone | healthkit | health_connect",
  "started_at": "2026-10-02T06:20:00+05:30",
  "elapsed_s": 1210, "moving_s": 1176,
  "timezone": "Asia/Kolkata",
  "state_code": "IN-KA",                        // from on-device reverse geocoding; may be null
  "track": [[12.9761, 77.5932, 905.2, 0, 8], ...], // [lat, lon, alt|null, t_offset_s, accuracy_m|null], ≤ 2000 points, resampled by the client to ~1 pt / 5 s
  "distance_m": 5012,                            // client estimate; server recomputes from track when present
  "steps": 3550,                                 // null if steps permission absent
  "splits_kmh": [15.1, 15.4, 15.0, 15.6, 15.2],  // per-km average speed
  "accel": {"rhythm_ratio": 0.82, "vertical_rms": 3.2},   // footfall features (never raw samples); null if motion absent
  "activity": {"running": 0.86, "walking": 0.10, "stationary": 0.04, "automotive": 0, "cycling": 0, "unknown": 0},
  "hr": {"mean": 166, "max": 184}                // null without a watch
}
```

Response:
```json
{
  "run_id": "...", "verdict": "verified | unverified | rejected", "trust": 0.91,
  "perf_index": 0.64, "band": "swift", "time_window": "dawn", "flags": ["new_route","explorer"], "novelty": 0.72,
  "tier": 2, "trigger": "explorer",
  "card": { "id": "...", "slug": "indian-fox", "name": "Indian Fox", "code": "IFX", "family": "explorer", "rarity": "common",
            "flavour_line": "...", "palette": {"bg":"#..","fg":"#..","accent":"#.."}, "art": {"baby":"card-art/indian-fox/baby.png", ...},
            "serial_no": 42, "serial": "Indian Fox #0042", "scope": "run", "stage": "young", "finish": "glow",
            "season": "Festival of Lights 2026", "stats": {"distance_km": 5.01, "duration_s": 1176, "pace_s_per_km": 235, "date": "2026-10-02"},
            "verdict": "verified", "issued_at": "...", "verify_url": "https://flyingcobra.run/v/indian-fox/42" },
  "celebrations": [ {"kind": "growth", "stage": "adult", "animal": "Indian Fox", "message": "Your indian fox is all grown up!"},
                    {"kind": "discovery", "tier": 2, "trigger": "explorer"} ],
  "message": null
}
```
When no card is issued, `card` is `null` and one of `floor:false`, `capped:true`, `verdict:"rejected"` explains why, with a `message` for the UI. `duplicate:true` means the run was already submitted.

### `claim_pending_cards() → jsonb[]`
Call on app open / foreground. Issues any weekly and monthly cards for completed periods (idempotent) and returns the new ones: `[{"scope":"weekly","card":{...},"run_days":7,"celebrations":[...]}, ...]`. Show each as a pending reveal.

### `mark_events_seen(ids bigint[]) → int`
After showing celebrations from the `events` table.

### `lookup_serial(q text) → jsonb` *(anon allowed — the only public read)*
Accepts `"Tiger #0427"`, `"tiger 427"`, `"TGR-0427"`. Returns `{found:true, card:{...}, earned_by:"Priya", stats:{...}, issued_so_far:118}` or `{found:false, reason:"format|animal|serial", hint:"..."}`. Never includes location.

### Admin only (`profiles.is_admin = true`)
- `admin_simulate_pool(ctx jsonb, as_user uuid default null) → jsonb` — `{tier, trigger, pity_n, pool:[{slug,name,rarity,w,p}]}` for a sample run context `{speed_band, distance_km, time_window, flags[], state_code, connected[]}`.
- `admin_perf_preview(v_kmh, d_km, sex, age) → jsonb` — `{v_std, age_factor, perf_index, band}`.
- Direct table writes to `animals`, `animal_rules`, `config`, `seasons`, `regions`, `age_factors` (audited into `rule_history`).

## Tables the app reads directly (RLS: own rows)
`profiles` (update own display_name, birth_year, sex, home_region, timezone, connected), `cards`, `runs` (stats only; `run_tracks` holds the private route), `bonds`, `events` (unseen celebrations), `user_states`, `pity_state`.
Reference: `animals` (secret ones hidden until earned), `seasons`, `regions`, `config` (read for display thresholds such as the weekly minimum), `animal_counters` (issued counts).

## Storage
Bucket `card-art` (public read): `card-art/<slug>/<stage>.png` (1200 × 1200, transparent). Until art is uploaded the client renders the procedural placeholder (DESIGN.md §5).

## Auth
Supabase Auth email magic link + Apple + Google. `profiles` row is created by trigger on signup. Admin = `profiles.is_admin` set via SQL by the owner (see MANUAL_TASKS.md).

## Verify page (public web)
Edge Function `verify` at `/v/<slug>/<serial>` renders HTML with Open Graph tags (so WhatsApp/Instagram previews show the card) by calling `lookup_serial` with the anon key.
