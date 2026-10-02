# Flying Cobra — Algorithms & Math Specification

Working product name: **Flying Cobra** (named for Chrysopelea, the gliding snakes of India that launch from a branch, flatten their bodies into a wing and sail between trees). Renamable in one place (`app/lib/core/brand.dart`, `config.app`).

Everything below is **data-driven**: every threshold lives in the `config` table or in `animal_rules.predicates`, and is editable from the admin panel. The numbers here are the shipped defaults with the reasoning behind them. The authoritative implementation is in Postgres (`supabase/migrations/`), so a modified client can never forge a card.

---

## 0. Notation

| Symbol | Meaning | Unit |
|---|---|---|
| D | run distance (GPS, filtered) | km |
| D_eq | flat-equivalent distance after grade adjustment | km |
| T_m | moving time | s |
| v | average moving speed = D / T_m | km/h |
| v_eq | D_eq / T_m | km/h |
| F(a, s) | age factor for age a, sex s | 0..1 |
| P | age-graded performance index | 0..1+ |
| ν | route novelty ratio | 0..1 |
| τ | trust score (anti-cheat) | 0..1 |

Local time for all calendar logic uses the user's timezone (`profiles.timezone`, default `Asia/Kolkata`). Weeks are ISO weeks (Monday to Sunday).

---

## 1. Eligibility floor (applies to every card)

A run produces a card only if

```
D ≥ 1.0 km   OR   (T_m ≥ 600 s  AND  v ≥ 6.0 km/h)
```

The second clause is the PRD's "10 minutes at running pace" (6 km/h is a 10:00 min/km jog-walk). The same floor guards location, explorer and time-of-day animals, so nothing can be farmed from a train or car with a 200 m stroll at the station. Config keys: `floor.min_km`, `floor.min_moving_s`, `floor.min_speed_kmh`.

A maximum of `limits.max_run_cards_per_day` (default 2) run cards are issued per local day. Later runs that day are still recorded (they count for streaks and weekly volume) but do not draw a card. This is the anti-farming cap for "every run earns a card".

---

## 2. Age-grading: the fairness engine

### 2.1 Open standard speed as a function of distance

A fixed pace band would reward long runs less than short dashes. We compare the runner against a distance-appropriate standard using Riegel's endurance model:

```
T_std(D) = T_ref · (D / D_ref)^1.06
v_std(D) = D / T_std(D)
```

with `D_ref = 5 km` and open (age 20–30) reference times:

| Sex | T_ref (5 km) | Source of magnitude |
|---|---|---|
| male | 755 s (12:35) | world-class road 5 km |
| female | 840 s (14:00) | world-class road 5 km |
| unknown | 796 s | geometric mean of the two |

To stop very short runs being gamed by GPS noise we use `D_eff = max(D_eq, 1.5 km)` in `v_std`.

### 2.2 Age factor

Performance declines roughly 0.7 %/year after 35, accelerating after 60, and rises through adolescence. We store a piecewise-linear table `age_factors(sex, age, factor)` with knots every five years (approximating the WMA 2020 road factors; marked *approximate* in the admin panel so they can be replaced with licensed tables later) and linearly interpolate between knots:

| Age | male | female |
|---|---|---|
| 10 | 0.700 | 0.740 |
| 12 | 0.780 | 0.820 |
| 14 | 0.860 | 0.900 |
| 16 | 0.930 | 0.960 |
| 18 | 0.980 | 0.990 |
| 20–30 | 1.000 | 1.000 |
| 35 | 0.985 | 0.983 |
| 40 | 0.955 | 0.955 |
| 45 | 0.925 | 0.920 |
| 50 | 0.893 | 0.880 |
| 55 | 0.860 | 0.840 |
| 60 | 0.826 | 0.798 |
| 65 | 0.788 | 0.752 |
| 70 | 0.746 | 0.700 |
| 75 | 0.698 | 0.643 |
| 80 | 0.640 | 0.578 |
| 85 | 0.570 | 0.505 |
| 90 | 0.490 | 0.425 |

Unknown sex → mean of the two columns. Unknown age → age 30 (factor 1.0). Age is derived from `birth_year` only (we never store a birth date). Age and sex are optional, private, never shown on any card, and only ever used here.

### 2.3 Grade adjustment (effort context from elevation)

Hills cost energy. We convert each track segment to a flat-equivalent length using Minetti et al. (2002) cost of running on gradient *i* (fraction):

```
C(i) = 155.4 i⁵ − 30.4 i⁴ − 43.3 i³ + 46.3 i² + 19.5 i + 3.6    [J·kg⁻¹·m⁻¹]
r(i) = clamp( C(i) / 3.6 , 0.75 , 2.5 )
D_eq = Σ_segments  len_seg · r(i_seg)
```

Elevation is smoothed over a 100 m window before computing *i*; if altitude accuracy is poor or elevation permission is absent, `r = 1` (graceful degradation). The downhill clamp at 0.75 stops "run down a hill" from becoming a cheat.

### 2.4 Performance index

```
P = v_eq / ( v_std(D_eff) · F(age, sex) )
```

This is exactly the WMA age-graded percentage expressed through speeds: dividing by `F` restores the speed the runner would have had in their open-age prime.

**Worked examples (5 km runs):**

| Runner | Pace | v (km/h) | F | P | Band |
|---|---|---|---|---|---|
| 30 M | 6:00 /km | 10.0 | 1.000 | 0.419 | calm |
| 30 M | 5:00 /km | 12.0 | 1.000 | 0.503 | steady |
| 30 M | 4:00 /km | 15.0 | 1.000 | 0.629 | swift |
| 60 M | 6:00 /km | 10.0 | 0.826 | 0.508 | steady |
| 30 F | 5:30 /km | 10.9 | 1.000 | 0.509 | steady |
| 30 M | 8:30 /km | 7.06 | 1.000 | 0.296 | gentle |

`v_std(5 km)` = 23.84 km/h (male), 21.43 km/h (female). The 60-year-old at 6:00/km lands in the same family as the 30-year-old at 5:00/km. That is the fairness promise.

---

## 3. Speed family bands

`config.speed_bands` (defaults):

| Band | P range | Flavour | Example animals |
|---|---|---|---|
| swift | P ≥ 0.60 | explosive, aerial | cheetah, peregrine falcon, blackbuck, horse |
| steady | 0.47 ≤ P < 0.60 | pack, rhythm | wolf, dhole, chital, nilgai |
| calm | 0.35 ≤ P < 0.47 | gentle, curious | rabbit, cat, langur, peacock |
| gentle | P < 0.35 | tireless, grounded | tortoise, hamster, sloth bear, pangolin, elephant |

Bands are different *kinds*, not tiers. Each band has its own commons, uncommons, rares and an epic, so the rarity ceiling is identical in every band. The gentle band's epic is the elephant ("the tireless traveller", requires D ≥ 8 km).

---

## 4. Scale (stage) and growth

### 4.1 Stage from the run (`config.stage_thresholds`)

| Scope | baby | young | adult |
|---|---|---|---|
| run | D < 3 km | 3 ≤ D < 7 | D ≥ 7 |
| weekly (volume) | V < 10 km | 10 ≤ V < 25 | V ≥ 25 |
| monthly (volume) | V < 30 km | 30 ≤ V < 80 | V ≥ 80 |

### 4.2 Growth from consistency (the bond)

Per (user, animal) we keep `bonds.earn_weeks` = number of **distinct ISO weeks** in which that animal was earned, monotonically increasing.

```
bond_stage = baby  if earn_weeks < 3
           = young if 3 ≤ earn_weeks < 6
           = adult if earn_weeks ≥ 6
card.stage = max(distance_stage, bond_stage)
```

- A bond stage increase is a **celebration event** ("Your cheetah is all grown up!").
- The bond never decreases on a break (no re-babying). A weak run after a break simply draws a *different* animal because it falls in a different band.
- **Reset:** if `now − profiles.last_run_at ≥ 60 days`, all bonds for that user reset to zero on their next run. Printed cards keep their stage forever.
- **Unlock the Wild:** an animal is *mastered* when `bond_stage = adult AND earn_count ≥ 10`. For a mastered animal the draw weight is multiplied by `wild.mastered_weight_mult` (0.25) and every rare-or-better animal in the pool gets `wild.rare_boost` (1.5×). Late-game runs roll varied rare species instead of the same cheetah.

---

## 5. Finish (consistency → special finish)

Let `d7` = number of distinct local days with a verified run in the trailing 7 days including today.

| Scope | plain | glow | radiant |
|---|---|---|---|
| run | d7 < 4 | 4 ≤ d7 < 7 | d7 = 7 |
| weekly | run_days = 3–4 | 5–6 | 7 |
| monthly | run_days < 12 | 12–19 | ≥ 20 |

If an active **season** (`seasons` table, e.g. "Monsoon 2026", 1 Jun–30 Sep) covers the card date, the card carries that set name and the glow/radiant finish uses the season's palette (the "seasonal colour"). Same animal + same stage + same finish + same season = identical template for everyone; only the serial differs.

---

## 6. The surprise layer: pool, luck, pity

### 6.1 "The run decides the pool"

Every active `animal_rules` row has a `scope` (run / weekly / monthly), a `tier`, a JSON `predicates` object, a `weight` multiplier, `first_time_guaranteed` and `repeat_probability`. A rule *matches* a run when all its predicates hold:

```
speed_bands ⊇ {band}        min_km ≤ D ≤ max_km
time_windows ∋ time_window  requires_flags ⊆ run.flags      (new_route, zigzag, new_area, new_state, migratory_2, migratory_3)
region_codes ∋ state_code   min_run_days ≤ d (weekly)        min_earn_weeks ≤ bond … etc.
requires_connected ⊆ granted permissions                      (the "fully connected" animals)
```

Tiers resolve which bag opens, from most special to least:

| Tier | Trigger | Examples |
|---|---|---|
| 4 | migratory (≥ 2 or 3 states in 21 days) | bar-headed goose, Amur falcon |
| 3 | new state for this user (travel souvenir) | the state's animal |
| 2 | explorer (new route / zigzag / untraced path in familiar area / new area) | Indian fox, jackal, mongoose |
| 1 | time of day (dawn / night) | owl, rooster, bulbul |
| 0 | speed band (always available) | the four families |

For each tier from 4 down to 1 with at least one matching rule: if the user has **never** earned any animal from that tier's trigger, the tier fires (**guaranteed discovery** — the first night run always gives an owl; the first run in Kerala always gives a Kerala animal). Otherwise it fires with probability `repeat_probability` (owl 0.35, explorer 0.5, state 0.2 after the first time). The first tier that fires becomes the pool. If none fires, the tier-0 speed pool is used. Tier 3 fires at most once per state per user unless `repeat_probability` allows; tier 4 at most once per 21-day window.

### 6.2 "Luck decides the animal" — weighted draw

Base weights by rarity (`config.rarity_weights`):

| common | uncommon | rare | epic | legendary |
|---|---|---|---|---|
| 60 | 25 | 10 | 4 | 1 |

Effective weight for animal *a* in the pool:

```
w_a = W_rarity(a) · rule.weight · pity(a) · wild(a)
pick a with probability w_a / Σ w
```

The draw uses `random()` server-side; the client never influences it.

### 6.3 Pity timer

`pity_state.cards_since_rare` = n, counting run cards since the last card of rarity ≥ rare.

```
pity(a) = 1                                   if rarity(a) < rare
        = min( cap, 1 + k · max(0, n − n0) )  otherwise
with n0 = 4, k = 0.6, cap = 8
hard pity: if n ≥ 15 and the pool contains any rare+ animal, drop the commons/uncommons.
```

For a typical speed pool (3 commons, 2 uncommons, 1 rare, 1 epic → Σ = 244, base p_rare+ = 5.7 %), simulation gives mean cards-to-rare ≈ 8.5 and P(no rare within 15) = 0 by construction. Pity resets to 0 on any rare+ card. Weekly cards have their own guaranteed rarity by day-count and do not touch the pity counter.

---

## 7. Weekly card

At week close (Monday 03:00 local, via `pg_cron`, or lazily when the app opens, idempotent on `(user_id, 'weekly', iso_week_key)`):

```
d = distinct run-days in the week (verified, floor-passing)
V = Σ distance
variety = any run in the week with new_route OR new_area OR new_state
d < 3 → no card at all (never an insulting card)
pool tier = highest of {3, 5, 7} with min_run_days ≤ d  →  3-day bag, 5-day bag, 7-day bag
stage from V (table in §4.1); finish from d (§5); variety is stamped on the card (stats.variety) and never dilutes the bag — a 7-day week always draws from the 7-day bag
```

Weekly bags are where the rares live: 3 days → red panda / hornbill / gaur; 5 days → snow leopard / Asiatic lion (epic); 7 days → Bengal tiger (legendary).

---

## 8. Monthly card (where you are)

At month close: `n_m` = verified runs in the month. If `n_m ≥ 4`: `home_state` = mode of `state_code` across those runs → pool = regional animals for that state (rules with `region_codes`). If the state has no regional animals yet → national pool (peacock, tiger, Ganges dolphin). Stage from monthly volume; finish from run-days. Idempotent on `(user_id, 'monthly', 'YYYY-MM')`.

---

## 9. Geography and exploration

### 9.1 Track hygiene (client, then re-validated server-side)

1. Drop points with horizontal accuracy > 50 m.
2. Drop a point if the implied speed from the previous kept point exceeds 30 km/h (GPS jump).
3. Moving time excludes gaps where speed < 1 km/h for ≥ 10 s (auto-pause).
4. Resample along the path every 25 m by linear interpolation for heading/turn math.
5. Upload at most 2 000 points (polyline, private; never leaves the owner's row-level-security scope).

### 9.2 Cells (geohash, implemented in plpgsql)

- **Route cells:** geohash precision 7 (≈ 153 m × 153 m) for every resampled point → set `C_run`.
- **Area cell:** geohash precision 5 (≈ 4.9 km × 4.9 km) of the run centroid.
- **Region cell:** geohash precision 4 (≈ 39 km × 19.5 km) of the centroid.

### 9.3 Novelty and the explorer flags

```
H = union of C_run over the user's verified runs in the last 180 days
ν = |C_run \ H| / |C_run|

new_route  := ν ≥ 0.60 AND |C_run| ≥ 6 AND prior_verified_runs ≥ 3
untraced   := 0.30 ≤ ν < 0.60 AND area cell seen in ≥ 3 prior runs       ("untraced path in a familiar area")
zigzag     := turns_per_km ≥ 8 AND D ≥ 1.5 km
new_area   := region cell (gh4) never seen before AND same state
explorer   := new_route OR untraced OR zigzag OR new_area
```

`turns_per_km`: on the 25 m resampled path, a *turn* is a heading change > 60° between consecutive segments; count / D. A rectangular 5 km park loop has ≈ 1–2 turns/km; weaving through lanes gives 8+. Thresholds in `config.explore`.

The `prior_verified_runs ≥ 3` guard stops the first three runs from all being "new routes".

### 9.4 State detection and souvenirs

The phone reverse-geocodes the centroid on-device (platform geocoder, no third-party API) and sends `state_code` (ISO 3166-2:IN). The server sanity-checks it against the `regions` bounding box table; a mismatch sets `state_code = null` and the run earns no regional animal. `new_state := state_code ∉ user_states AND state_code is not home`, where home = the user's chosen `home_region`, or, if unset, the first state they ever ran in (recorded as home automatically). Where you live is not a souvenir. → tier-3 souvenir, guaranteed once per state.

### 9.5 Migratory birds

```
S21 = distinct state codes of verified, floor-passing runs in the trailing 21 days (including today)
migratory_2 := |S21| ≥ 2      migratory_3 := |S21| ≥ 3
awarded at most once per 21 days per user (profiles.last_migratory_at)
```

### 9.6 Time of day — solar geometry, not a fixed clock

India spans 68°E–97°E under one clock; sunrise in Kohima is about two hours earlier than in Dwarka. We compute real sunrise/sunset (NOAA/Meeus simplified algorithm) from the run's start latitude, longitude and date:

```
n       = JD − 2451545.0 + 0.0008
J*      = n − lon/360
M       = (357.5291 + 0.98560028 · J*) mod 360
C       = 1.9148 sin M + 0.0200 sin 2M + 0.0003 sin 3M
λ       = (M + C + 180 + 102.9372) mod 360
J_tr    = 2451545.0 + J* + 0.0053 sin M − 0.0069 sin 2λ
sin δ   = sin λ · sin 23.44°
cos ω₀  = ( sin(−0.833°) − sin φ sin δ ) / ( cos φ cos δ )
J_rise  = J_tr − ω₀/360         J_set = J_tr + ω₀/360
```

Windows (minutes, `config.time_windows`):

| Window | Definition |
|---|---|
| dawn | sunrise − 45 min ≤ start < sunrise + 30 min |
| dusk | sunset − 15 min ≤ start < sunset + 45 min |
| night | start ≥ sunset + 60 min OR start < sunrise − 45 min |
| day | otherwise |

Dawn → rooster / bulbul / peacock-call bag; night → owl / nightjar / civet bag. Dusk is recorded but has no animals in v1 (room for a later season).

---

## 10. Anti-cheat: evidence-weighted trust score

The client uploads **features, never raw sensor streams** (data minimisation). The server scores each available piece of evidence `e_i ∈ [−1, +1]` with weight `w_i`; missing evidence is excluded, which is how the app degrades gracefully with only GPS + steps.

**Hard rules (reject before scoring):** `v > 20 km/h` or `max_1min_speed > 24 km/h` (no human sustains more; both exceed world-record paces with GPS slack).

| Evidence | Input | e = +1 | e = 0 | e = −1 | w |
|---|---|---|---|---|---|
| Stride | `stride = D / steps` | 0.6–2.4 m | 2.4–3.0 | > 3.0 m, or steps = 0 with D > 1 km | 2.0 |
| Cadence | steps / moving min | 140–200 | 100–140 (jog-walk, +0.3) | < 60 | 1.5 |
| Footfall rhythm | fraction of 10 s windows whose dominant vertical-accel frequency is 2.2–3.4 Hz (132–204 spm) | ≥ 0.6 | 0.3–0.6 | < 0.3, or vertical RMS < 0.8 m/s² while > 8 km/h | 2.0 |
| Activity class | platform classification fractions | run+walk ≥ 0.7 | — | automotive+cycling ≥ 0.3 | 1.5 |
| Consistency | km splits | CV ≤ 0.25 (+0.5) | — | any split > 1.8 × median AND > 18 km/h | 1.0 |
| Heart rate | mean / max bpm | mean ≥ 110 and max ≥ 130 | — | mean < 85 while v > 9 km/h | 2.5 |

```
τ = 0.5 + 0.5 · ( Σ w_i e_i / Σ w_i )       over available evidence only
verdict = verified   if τ ≥ 0.60
        = unverified if 0.40 ≤ τ < 0.60   → card issued from the speed pool only; no tier 1–4 animals; counts for streaks
        = rejected   if τ < 0.40          → no card; message: "We couldn't confirm this one was a run."
```

Why this catches the classic cheats: a car ride has stride > 3 m (or zero steps), smooth accelerometer, automotive class, and no heart-rate rise → τ ≈ 0. Cycling shows 18–25 km/h with near-zero cadence and smooth rhythm → rejected. A watch-less phone-only runner with just GPS and steps has stride, cadence and consistency evidence → τ ≈ 0.85 → verified.

Weights and thresholds live in `config.anticheat`.

---

## 11. Serial numbers (the proof mechanic)

- One counter row per animal in `animal_counters`. Issuing a card does `UPDATE … SET next_serial = next_serial + 1 … RETURNING next_serial` inside the same transaction as the card insert. Postgres row locking serialises concurrent issuance; the `UNIQUE (animal_id, serial_no)` constraint is the backstop. Counts are exact and gap-free in practice (a failed insert rolls the counter back).
- Display: `Tiger #0427` (zero-padded to 4, grows naturally past 9 999).
- Verify path: `/v/tiger/427`. Lookup accepts `Tiger #0427`, `tiger 427`, `TGR-0427`.
- The public lookup returns only: animal, serial, stage, finish, set name, earner's display name, issue date, distance, duration, pace. **Never** location, route, start point or any health field.

---

## 12. Re-earning and duplicates (open question, v1 decision)

Every earn mints a new card with a new serial (collectors like volume). The collection view groups by animal and shows the count and the **best (lowest) serial**. Nothing else happens on a re-earn in v1; the bond system (§4.2) already turns repetition into growth.

---

## 13. Dummy users (seeded scenarios)

| Persona | What the seed produces |
|---|---|
| Arjun, 24, sprinter | 5 km at 3:55/km → P 0.64 swift → cheetah-family cards |
| Meera, 62, endurance | 12 km at 7:10/km, F 0.77 → P 0.44 calm... with D ≥ 8 → elephant eligible |
| Ravi, 7-day streak | 7 runs Mon–Sun → weekly 7-day bag (tiger), radiant finish |
| Priya, traveller | Runs in KA then KL then GA inside 21 days → souvenir + migratory_3 |
| Kabir, night owl | Starts 22:15 IST → night window → owl |
| Sana, rabbit collector | 3 km at 8:00/km → calm/gentle → rabbit chase |

Expected outcomes are asserted in `tools/dbtest/test.mjs`.
