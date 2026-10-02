/* Flying Cobra workbench — the selection engine, mirrored from docs/ALGORITHMS.md and
   supabase/migrations/0002_math.sql + 0003_engine.sql. Pure functions. Used by the
   "simulate run" control so card reveals can be previewed on the web with real logic.
   Exposed as window.Engine. */
(function () {
  'use strict';

  const AGE_M = { 10:.700, 12:.780, 14:.860, 16:.930, 18:.980, 20:1, 30:1, 35:.985, 40:.955, 45:.925, 50:.893, 55:.860, 60:.826, 65:.788, 70:.746, 75:.698, 80:.640, 85:.570, 90:.490 };
  const AGE_F = { 10:.740, 12:.820, 14:.900, 16:.960, 18:.990, 20:1, 30:1, 35:.983, 40:.955, 45:.920, 50:.880, 55:.840, 60:.798, 65:.752, 70:.700, 75:.643, 80:.578, 85:.505, 90:.425 };
  const T_REF = { male: 755, female: 840, unknown: 796 };
  const CFG = {
    dRef: 5, riegel: 1.06, minDEff: 1.5,
    bands: { swift: .60, steady: .47, calm: .35 },
    stage: { young: 3, adult: 7 },
    finish: { glow: 4, radiant: 7 },
    floor: { minKm: 1.0, minMovingS: 600, minSpeedKmh: 6.0 },
    hard: { maxAvgKmh: 20, max1minKmh: 24 },
    weights: { common: 60, uncommon: 25, rare: 10, epic: 4, legendary: 1 },
    pity: { n0: 4, k: .6, cap: 8, hard: 15 },
    capPerDay: 2
  };

  function interp(t, age) {
    const keys = Object.keys(t).map(Number).sort((a, b) => a - b);
    const a = Math.max(keys[0], Math.min(keys[keys.length - 1], age));
    let lo = keys[0], hi = keys[keys.length - 1];
    for (const k of keys) { if (k <= a) lo = k; if (k >= a) { hi = k; break; } }
    return hi === lo ? t[lo] : t[lo] + (t[hi] - t[lo]) * (a - lo) / (hi - lo);
  }
  function ageFactor(age, sex) {
    if (age == null) age = 30;
    if (sex === 'male') return interp(AGE_M, age);
    if (sex === 'female') return interp(AGE_F, age);
    return (interp(AGE_M, age) + interp(AGE_F, age)) / 2;
  }
  function vStd(km, sex) {
    const d = Math.max(km, CFG.minDEff);
    const tStd = (T_REF[sex] || T_REF.unknown) * Math.pow(d / CFG.dRef, CFG.riegel);
    return d / (tStd / 3600);
  }
  const perfIndex = (vKmh, km, age, sex) => vKmh / (vStd(km, sex) * ageFactor(age, sex));
  const band = p => p >= CFG.bands.swift ? 'swift' : p >= CFG.bands.steady ? 'steady' : p >= CFG.bands.calm ? 'calm' : 'gentle';
  const stage = km => km >= CFG.stage.adult ? 'adult' : km >= CFG.stage.young ? 'young' : 'baby';
  const finish = d7 => d7 >= CFG.finish.radiant ? 'radiant' : d7 >= CFG.finish.glow ? 'glow' : 'plain';
  const floorOk = (km, movingS, vKmh) => km >= CFG.floor.minKm || (movingS >= CFG.floor.minMovingS && vKmh >= CFG.floor.minSpeedKmh);

  /** §9.6 time window from a local hour (the real engine uses NOAA sunrise; the workbench uses IST clock windows). */
  function timeWindow(hour) {
    if (hour >= 21 || hour < 4.5) return 'night';
    if (hour < 6.75) return 'dawn';
    if (hour >= 17.75 && hour < 19) return 'dusk';
    return 'day';
  }

  /** Build the pool for a run context against a roster (DATA.animals). Tiers: 4 migratory › 3 souvenir › 2 explorer › 1 time › 0 speed. */
  function buildPool(ctx, roster, user) {
    const seen = user?.tierHistory || {};
    const tiers = [
      { t: 4, trig: 'migratory', ok: a => a.tier === 4 && (ctx.flags || []).some(f => a.requiresFlags?.includes(f)), rep: .5 },
      { t: 3, trig: 'state:' + ctx.stateCode, ok: a => a.tier === 3 && (ctx.flags || []).includes('new_state') && a.regionCodes?.includes(ctx.stateCode), rep: .2 },
      { t: 2, trig: 'explorer', ok: a => a.tier === 2 && (ctx.flags || []).includes('explorer'), rep: .5 },
      { t: 1, trig: 'time:' + ctx.timeWindow, ok: a => a.tier === 1 && a.timeWindows?.includes(ctx.timeWindow), rep: .35 }
    ];
    let chosen = { t: 0, trig: 'speed:' + ctx.band };
    if (ctx.verdict !== 'unverified') {
      for (const tier of tiers) {
        const cands = roster.filter(tier.ok);
        if (!cands.length) continue;
        const fire = !seen[tier.trig] || (ctx.rng || Math.random)() < tier.rep;
        if (fire) { chosen = tier; break; }
      }
    }
    let pool = roster.filter(a => chosen.t === 0 ? (a.tier === 0 && a.bands.includes(ctx.band) && (!a.minKm || ctx.km >= a.minKm)) : chosen.ok(a));
    const n = user?.pity ?? 0;
    const mult = Math.min(CFG.pity.cap, 1 + CFG.pity.k * Math.max(0, n - CFG.pity.n0));
    let entries = pool.map(a => ({ animal: a, w: CFG.weights[a.rarity] * (isRarePlus(a) ? mult : 1) }));
    if (n >= CFG.pity.hard && entries.some(e => isRarePlus(e.animal))) entries = entries.filter(e => isRarePlus(e.animal));
    const total = entries.reduce((s, e) => s + e.w, 0);
    entries.forEach(e => e.p = e.w / total);
    return { tier: chosen.t, trigger: chosen.trig, pool: entries, pityN: n };
  }
  const isRarePlus = a => ['rare', 'epic', 'legendary'].includes(a.rarity);

  function draw(pool, rng = Math.random) {
    const total = pool.reduce((s, e) => s + e.w, 0);
    let r = rng() * total;
    for (const e of pool) { r -= e.w; if (r < 0) return e.animal; }
    return pool[pool.length - 1].animal;
  }

  /** Simulate a whole run → the same shape as API.md submit_run. sim = {paceSec, km, hour, stateCode, flags[], cadenceOk, hr} */
  function simulate(sim, user, roster, rng = Math.random) {
    const vKmh = 3600 / sim.paceSec, movingS = Math.round(sim.km * sim.paceSec);
    if (vKmh > CFG.hard.maxAvgKmh) return { verdict: 'rejected', card: null, message: 'We couldn\'t confirm this one was a run — no card this time.', trust: 0, vKmh };
    let verdict = 'verified', trust = 0.9;
    if (sim.cadenceOk === false) { verdict = 'unverified'; trust = 0.5; }
    if (!floorOk(sim.km, movingS, vKmh)) return { verdict, card: null, floor: false, message: 'Recorded. A run of 1 km or 10 minutes earns a card.', trust, vKmh };
    const todayCards = (user.cards || []).filter(c => c.scope === 'run' && c.date === sim.date).length;
    if (todayCards >= CFG.capPerDay) return { verdict, card: null, capped: true, message: 'Recorded and counted. Your card bag refills tomorrow.', trust, vKmh };

    const p = perfIndex(vKmh, sim.km, user.age, user.sex);
    const ctx = { band: band(p), km: sim.km, timeWindow: timeWindow(sim.hour), stateCode: sim.stateCode, flags: sim.flags || [], verdict, rng };
    const poolInfo = buildPool(ctx, roster, user);
    const animal = draw(poolInfo.pool, rng);
    const bond = (user.bonds || {})[animal.slug] || { earnWeeks: 0, stage: 'baby', count: 0 };
    const bondStage = bond.earnWeeks + 1 >= 6 ? 'adult' : bond.earnWeeks + 1 >= 3 ? 'young' : 'baby';
    const st = ['baby', 'young', 'adult'];
    const cardStage = st[Math.max(st.indexOf(stage(sim.km)), st.indexOf(bondStage))];
    const grew = st.indexOf(bondStage) > st.indexOf(bond.stage);
    const serial = (roster.counters?.[animal.slug] ?? (animal.issued || 0)) + 1;
    const celebrations = [];
    if (grew) celebrations.push({ kind: 'growth', stage: bondStage, animal: animal.name, message: bondStage === 'adult' ? `Your ${animal.name.toLowerCase()} is all grown up!` : `Your ${animal.name.toLowerCase()} is growing!` });
    if (poolInfo.tier >= 1) celebrations.push({ kind: 'discovery', tier: poolInfo.tier, trigger: poolInfo.trigger });
    return {
      verdict, trust, perfIndex: +p.toFixed(3), band: ctx.band, timeWindow: ctx.timeWindow, tier: poolInfo.tier, trigger: poolInfo.trigger, pool: poolInfo.pool, flags: ctx.flags,
      card: { animal, serial, tier: cardStage, finish: finish((user.runDaysLast7 || 0) + 1), scope: 'run', season: 'Festival of Lights 2026',
              statsLine: `${sim.km.toFixed(1)} km · ${FC.fmtDur(movingS)} · ${FC.fmtPace(sim.paceSec)}/km`, verdict, date: sim.date, issuedAt: new Date().toISOString() },
      celebrations, message: verdict === 'unverified' ? 'We couldn\'t fully verify this run, so it drew from the everyday bag.' : null
    };
  }

  window.Engine = { CFG, ageFactor, vStd, perfIndex, band, stage, finish, floorOk, timeWindow, buildPool, draw, simulate };
})();
