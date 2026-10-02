/* Flying Cobra marketing: the 3D layer.
   One WebGLRenderer on one fixed canvas. Every element with [data-scene] is a "view": each frame its
   on-screen rectangle becomes a scissor + viewport and its scene renders there (the Three.js
   multiple-elements pattern). Models are procedural low-poly toys built from a handful of shared
   geometries and materials, so the page ships with no binary assets; GLB models can replace a
   builder later (see README). Honours prefers-reduced-motion: static mid-stride poses, render on demand.
   Three.js is pinned at 0.186.1 (web/vendor/three) through the page's import map. */
import * as THREE from 'three';

const TAU = Math.PI * 2;
const reduceMQ = matchMedia('(prefers-reduced-motion: reduce)');
const darkMQ = matchMedia('(prefers-color-scheme: dark)');
const finePointer = matchMedia('(pointer: fine)');
const reduce = reduceMQ.matches;

/* ---------- shared geometry + material caches (threejs rules 14 and 19) ---------- */
const MATS = new Map();
function mat(hex, opts = {}) {
  const key = hex + JSON.stringify(opts);
  if (!MATS.has(key)) MATS.set(key, new THREE.MeshStandardMaterial({ color: hex, roughness: 0.92, metalness: 0, flatShading: true, ...opts }));
  return MATS.get(key);
}
const G = {
  ico1: new THREE.IcosahedronGeometry(1, 1),
  ico2: new THREE.IcosahedronGeometry(1, 2),
  capsule: new THREE.CapsuleGeometry(0.5, 1, 3, 8),   // total height 2 before scaling
  box: new THREE.BoxGeometry(1, 1, 1),
  cone: new THREE.ConeGeometry(0.5, 1, 8),            // tip along +y
  cyl: new THREE.CylinderGeometry(0.5, 0.5, 1, 10),
  disc: new THREE.CircleGeometry(1, 48),
  plane: new THREE.PlaneGeometry(1, 1),
};
const UP = new THREE.Vector3(0, 1, 0);

function part(geo, material, pos = [0, 0, 0], scale = [1, 1, 1], rot = [0, 0, 0]) {
  const m = new THREE.Mesh(geo, material);
  m.position.set(...pos); m.scale.set(...scale); m.rotation.set(...rot);
  m.castShadow = true;
  return m;
}
/* A capsule from point a to point b with radius r. */
function limb(material, a, b, r) {
  const A = new THREE.Vector3(...a), d = new THREE.Vector3(...b).sub(A); const L = d.length();
  const m = new THREE.Mesh(G.capsule, material);
  m.scale.set(2 * r, L / 2, 2 * r);
  m.position.copy(A).addScaledVector(d, 0.5);
  m.quaternion.setFromUnitVectors(UP, d.normalize());
  m.castShadow = true;
  return m;
}
function rng(seed) { return () => { seed = (seed * 1664525 + 1013904223) % 4294967296; return seed / 4294967296; }; }
const lerp = (a, b, t) => a + (b - a) * t;
const clamp01 = (v) => Math.min(1, Math.max(0, v));

/* ---------- animal specs (names and families match supabase/migrations/0005_seed_animals.sql) ---------- */
const ANIMALS = {
  cheetah: { name: 'Cheetah', family: 'swift', flavour: 'the comeback sprinter',
    body: { len: 1.9, h: 0.55, w: 0.5 }, legs: { len: 0.72, r: 0.07, sx: 0.62, sz: 0.18 },
    head: { size: 0.46 }, neck: { len: 0.3, angle: 0.42, r: 0.12 }, tail: { len: 0.95, r: 0.05, angle: -0.35 },
    ears: { size: 0.1 }, colors: { body: 0xD9A45B, dark: 0x3B2A1A, light: 0xF1DDB5 },
    spots: { count: 28, color: 0x3B2A1A, r: 0.045, seed: 7 }, gait: { freq: 1.65, swing: 0.95, bob: 0.09 } },
  chital: { name: 'Chital', family: 'steady', flavour: 'the dappled wanderer',
    body: { len: 1.25, h: 0.5, w: 0.42 }, legs: { len: 0.82, r: 0.05, sx: 0.42, sz: 0.16 },
    head: { size: 0.36 }, neck: { len: 0.58, angle: 1.05, r: 0.1 }, tail: { len: 0.28, r: 0.04, angle: -0.9 },
    ears: { size: 0.13 }, antlers: true, colors: { body: 0xB5783F, dark: 0x3A2A1A, light: 0xF3E7D3 },
    spots: { count: 34, color: 0xF8F1E4, r: 0.035, seed: 3 }, gait: { freq: 1.45, swing: 0.8, bob: 0.08 } },
  cat: { name: 'Cat', family: 'calm', flavour: 'curious and unbothered',
    body: { len: 0.78, h: 0.32, w: 0.3 }, legs: { len: 0.3, r: 0.045, sx: 0.26, sz: 0.1 },
    head: { size: 0.3 }, tail: { len: 0.5, r: 0.035, angle: 1.15 },
    ears: { size: 0.1, pointy: true }, colors: { body: 0x8E929B, dark: 0x2E2E33, light: 0xE9E6E0 },
    gait: { freq: 1.9, swing: 0.75, bob: 0.05 } },
  tortoise: { name: 'Star Tortoise', family: 'gentle', flavour: 'unstoppable',
    body: { len: 0.95, h: 0.28, w: 0.66 }, legs: { len: 0.21, r: 0.075, sx: 0.32, sz: 0.27 },
    head: { size: 0.24 }, neck: { len: 0.24, angle: 0.3, r: 0.07 }, tail: { len: 0.12, r: 0.03, angle: -0.4 },
    shell: { color: 0x5E5C33, stars: 0xE8C861, seed: 11 }, colors: { body: 0x8E8A58, dark: 0x2E2B1B, light: 0xB9B47E },
    gait: { freq: 0.95, swing: 0.55, bob: 0.015 } },
};
const BIRDS = {
  rooster: { name: 'Rooster', body: { r: 0.36, sx: 1.15, sy: 1, sz: 0.85 }, head: { r: 0.2, x: 0.3, y: 0.38 },
    beak: { len: 0.14, color: 0xE3B04B }, eye: { r: 0.035 }, comb: 0xD03B2E, plumes: [0x1D5B4A, 0x19323A, 0x2F7D62],
    legs: { len: 0.32, color: 0xE3B04B }, colors: { body: 0xB7461F, head: 0xD9772B, dark: 0x2A1F1A, wing: 0x7A2E16 } },
  owl: { name: 'Indian Eagle-Owl', body: { r: 0.4, sx: 1, sy: 1.1, sz: 0.9 }, head: { r: 0.3, x: 0.06, y: 0.5 },
    beak: { len: 0.1, color: 0x3A3A3A }, eye: { r: 0.085, iris: 0xE8A530, big: true }, tufts: true, belly: 0xD8C7A8,
    legs: { len: 0.18, color: 0x6A5A4A }, colors: { body: 0x8A7355, head: 0x9B8468, dark: 0x2C241C, wing: 0x5E4B38 } },
};

/* ---------- builders ---------- */
function makeQuadruped(s) {
  const g = new THREE.Group();
  const M = { body: mat(s.colors.body), dark: mat(s.colors.dark), light: mat(s.colors.light) };
  const hipY = s.legs.len;
  const bodyY = hipY + s.body.h * 0.38;
  g.add(part(G.ico2, M.body, [0, bodyY, 0], [s.body.len / 2, s.body.h / 2, s.body.w / 2]));

  if (s.shell) {
    const shell = part(G.ico2, mat(s.shell.color), [0, bodyY + s.body.h * 0.2, 0], [s.body.len * 0.52, s.body.h * 0.8, s.body.w * 0.52]);
    g.add(shell);
    const r = rng(s.shell.seed);
    for (let i = 0; i < 9; i++) {
      const a = r() * TAU, el = 0.35 + r() * 0.5;           // upper hemisphere only
      const dir = new THREE.Vector3(Math.cos(a) * Math.cos(el), Math.sin(el), Math.sin(a) * Math.cos(el));
      const p = dir.clone().multiply(new THREE.Vector3(s.body.len * 0.52, s.body.h * 0.8, s.body.w * 0.52)).multiplyScalar(0.98);
      const star = part(G.ico1, mat(s.shell.stars), [p.x, bodyY + s.body.h * 0.2 + p.y, p.z], [0.045, 0.045, 0.045]);
      g.add(star);
    }
  }
  if (s.spots) {
    const r = rng(s.spots.seed);
    for (let i = 0; i < s.spots.count; i++) {
      const a = r() * TAU, el = -0.1 + r() * 1.3;
      const dir = new THREE.Vector3(Math.cos(a) * Math.cos(el), Math.sin(el), Math.sin(a) * Math.cos(el));
      const p = dir.multiply(new THREE.Vector3(s.body.len / 2, s.body.h / 2, s.body.w / 2)).multiplyScalar(0.985);
      g.add(part(G.ico1, mat(s.spots.color), [p.x, bodyY + p.y, p.z], [s.spots.r, s.spots.r, s.spots.r]));
    }
  }

  // head (with optional neck) hangs off a pivot at the front of the body
  const headPivot = new THREE.Group();
  headPivot.position.set(s.body.len / 2 * 0.82, bodyY + s.body.h * 0.18, 0);
  const hs = s.head.size;
  let hc = [hs * 0.35, hs * 0.15];
  if (s.neck) {
    const end = [Math.cos(s.neck.angle) * s.neck.len, Math.sin(s.neck.angle) * s.neck.len, 0];
    headPivot.add(limb(M.body, [0, 0, 0], end, s.neck.r));
    hc = [end[0] + hs * 0.22, end[1] + hs * 0.08];
  }
  headPivot.add(part(G.ico2, M.body, [hc[0], hc[1], 0], [hs * 0.55, hs * 0.47, hs * 0.45]));
  headPivot.add(part(G.ico1, M.light, [hc[0] + hs * 0.45, hc[1] - hs * 0.08, 0], [hs * 0.28, hs * 0.2, hs * 0.26]));
  headPivot.add(part(G.ico1, M.dark, [hc[0] + hs * 0.7, hc[1] - hs * 0.04, 0], [hs * 0.07, hs * 0.06, hs * 0.08]));
  for (const side of [1, -1]) {
    headPivot.add(part(G.ico1, M.dark, [hc[0] + hs * 0.34, hc[1] + hs * 0.2, side * hs * 0.36], [hs * 0.075, hs * 0.075, hs * 0.075]));
    const e = s.ears;
    if (e && e.pointy) headPivot.add(part(G.cone, M.body, [hc[0] - hs * 0.08, hc[1] + hs * 0.46, side * hs * 0.26], [e.size * 1.6, e.size * 2.6, e.size], [0, 0, -side * 0.25]));
    else if (e) headPivot.add(part(G.ico1, M.body, [hc[0] - hs * 0.12, hc[1] + hs * 0.4, side * hs * 0.32], [e.size * 1.5, e.size * 1.8, e.size * 0.7]));
    if (s.antlers) {
      const base = [hc[0] - hs * 0.05, hc[1] + hs * 0.42, side * hs * 0.2];
      const tip = [base[0] - 0.2, base[1] + 0.52, base[2] + side * 0.14];
      headPivot.add(limb(M.light, base, tip, 0.025));
      const mid = [lerp(base[0], tip[0], 0.55), lerp(base[1], tip[1], 0.55), lerp(base[2], tip[2], 0.55)];
      headPivot.add(limb(M.light, mid, [mid[0] + 0.14, mid[1] + 0.22, mid[2] + side * 0.05], 0.02));
    }
  }
  g.add(headPivot);

  // tail
  const tailPivot = new THREE.Group();
  tailPivot.position.set(-s.body.len / 2 * 0.9, bodyY + s.body.h * 0.1, 0);
  tailPivot.add(limb(M.body, [0, 0, 0], [-Math.cos(s.tail.angle) * s.tail.len, Math.sin(s.tail.angle) * s.tail.len, 0], s.tail.r));
  g.add(tailPivot);

  // legs: FL, FR, BL, BR, each a pivot at the hip
  const legs = [];
  const L = s.legs.len, r = s.legs.r;
  for (const [sx, sz] of [[1, 1], [1, -1], [-1, 1], [-1, -1]]) {
    const pivot = new THREE.Group();
    pivot.position.set(sx * s.legs.sx, hipY, sz * s.legs.sz);
    pivot.add(part(G.capsule, M.body, [0, -L / 2, 0], [2 * r, L / 2, 2 * r]));
    pivot.add(part(G.ico1, M.dark, [0.01, -L + r * 0.3, 0], [r * 1.25, r * 0.9, r * 1.25]));
    g.add(pivot); legs.push(pivot);
  }
  return { group: g, legs, headPivot, tailPivot, spec: s, phase: 0 };
}

function animateQuadruped(q, t, speed = 1) {
  const s = q.spec.gait, ph = t * s.freq * speed * TAU + q.phase;
  q.legs.forEach((leg, i) => { leg.rotation.z = Math.sin(ph + ((i === 0 || i === 3) ? 0 : Math.PI)) * s.swing; });
  q.group.position.y = Math.abs(Math.sin(ph)) * s.bob;
  q.headPivot.rotation.z = Math.sin(ph) * 0.05;
  q.tailPivot.rotation.y = Math.sin(ph * 0.5) * 0.35;
}

function makeRunner(c = {}) {
  const skin = mat(c.skin ?? 0x8D5A3B), hair = mat(c.hair ?? 0x1F1A17), vest = mat(c.vest ?? 0x2F5D50);
  const shorts = mat(c.shorts ?? 0x26292B), shoe = mat(c.shoe ?? 0xF2EFE8);
  const g = new THREE.Group();
  const hipY = 0.98, thigh = 0.47, shin = 0.46;
  g.add(part(G.ico1, shorts, [0, hipY + 0.02, 0], [0.19, 0.15, 0.16]));

  const torso = new THREE.Group(); torso.position.set(0, hipY + 0.05, 0); torso.rotation.z = -0.16;
  torso.add(part(G.capsule, vest, [0, 0.33, 0], [0.19, 0.3, 0.14]));
  torso.add(part(G.ico2, skin, [0, 0.78, 0], [0.165, 0.175, 0.16]));                       // head
  torso.add(part(G.ico2, hair, [-0.03, 0.84, 0], [0.165, 0.14, 0.165]));                   // hair cap
  torso.add(part(G.ico1, skin, [0.0, 0.6, 0], [0.06, 0.06, 0.06]));                        // neck
  const arms = [];
  for (const side of [1, -1]) {
    const sh = new THREE.Group(); sh.position.set(0, 0.58, side * 0.23);
    sh.add(part(G.capsule, skin, [0, -0.15, 0], [0.09, 0.15, 0.09]));
    const el = new THREE.Group(); el.position.set(0, -0.3, 0); el.rotation.z = 1.55;
    el.add(part(G.capsule, skin, [0, -0.14, 0], [0.08, 0.14, 0.08]));
    el.add(part(G.ico1, skin, [0, -0.3, 0], [0.055, 0.055, 0.055]));
    sh.add(el); torso.add(sh); arms.push(sh);
  }
  g.add(torso);

  const legs = [];
  for (const side of [1, -1]) {
    const hip = new THREE.Group(); hip.position.set(0, hipY, side * 0.1);
    hip.add(part(G.capsule, skin, [0, -thigh / 2, 0], [0.12, thigh / 2, 0.12]));
    const knee = new THREE.Group(); knee.position.set(0, -thigh, 0);
    knee.add(part(G.capsule, skin, [0, -shin / 2, 0], [0.1, shin / 2, 0.1]));
    knee.add(part(G.box, shoe, [0.05, -shin - 0.03, 0], [0.26, 0.09, 0.12]));
    hip.add(knee); g.add(hip); legs.push({ hip, knee });
  }
  return { group: g, torso, arms, legs, phase: 0 };
}

function animateRunner(r, t, speed = 1) {
  const ph = t * 1.45 * speed * TAU + r.phase;
  r.legs.forEach((leg, i) => {
    const p = ph + (i ? Math.PI : 0);
    leg.hip.rotation.z = Math.sin(p) * 0.72;
    leg.knee.rotation.z = -(0.25 + 0.75 * Math.max(0, Math.sin(p + 1.3))) * 1.25;
  });
  r.arms.forEach((arm, i) => { arm.rotation.z = -Math.sin(ph + (i ? 0 : Math.PI)) * 0.55; });
  r.group.position.y = Math.abs(Math.sin(ph)) * 0.055;
  r.torso.rotation.y = Math.sin(ph) * 0.07;
}

function makeBird(s) {
  const g = new THREE.Group();
  const M = { body: mat(s.colors.body), head: mat(s.colors.head), dark: mat(s.colors.dark), wing: mat(s.colors.wing) };
  const br = s.body.r, bodyY = s.legs.len + br * s.body.sy * 0.85;
  g.add(part(G.ico2, M.body, [0, bodyY, 0], [br * s.body.sx, br * s.body.sy, br * s.body.sz]));
  if (s.belly) g.add(part(G.ico2, mat(s.belly), [br * 0.35, bodyY - br * 0.1, 0], [br * 0.7, br * 0.75, br * 0.6]));
  const legMat = mat(s.legs.color);
  for (const side of [1, -1]) {
    g.add(part(G.cyl, legMat, [0, s.legs.len / 2, side * br * 0.3], [0.05, s.legs.len, 0.05]));
    g.add(part(G.box, legMat, [0.06, 0.015, side * br * 0.3], [0.16, 0.03, 0.05]));
    const wing = part(G.ico2, M.wing, [-br * 0.15, bodyY + br * 0.1, side * br * s.body.sz * 0.9], [br * 0.9, br * 0.55, br * 0.18], [side * 0.15, 0, 0.15]);
    g.add(wing);
  }
  g.add(part(G.box, M.wing, [-br * 1.15, bodyY + br * 0.2, 0], [br * 0.9, br * 0.12, br * 0.55], [0, 0, -0.5]));
  if (s.plumes) s.plumes.forEach((c, i) => {
    for (const side of [1, -1]) g.add(limb(mat(c), [-br * 1.1, bodyY + br * 0.25, side * 0.03], [-br * 1.6 - i * 0.12, bodyY + br * 1.0 + i * 0.22, side * (0.05 + i * 0.06)], 0.035));
  });

  const head = new THREE.Group(); head.position.set(s.head.x, bodyY + s.head.y, 0);
  const hr = s.head.r;
  head.add(part(G.ico2, M.head, [0, 0, 0], [hr, hr, hr]));
  head.add(part(G.cone, mat(s.beak.color), [hr * 0.85 + s.beak.len * 0.4, -hr * 0.05, 0], [s.beak.len * 0.8, s.beak.len, s.beak.len * 0.8], [0, 0, -Math.PI / 2]));
  const eyes = [];
  for (const side of [1, -1]) {
    if (s.eye.big) {
      head.add(part(G.ico2, mat(0xF6F1E4), [hr * 0.72, hr * 0.18, side * hr * 0.5], [s.eye.r, s.eye.r, s.eye.r]));
      head.add(part(G.ico1, mat(s.eye.iris), [hr * 0.82, hr * 0.18, side * hr * 0.56], [s.eye.r * 0.62, s.eye.r * 0.62, s.eye.r * 0.62]));
      const pupil = part(G.ico1, M.dark, [hr * 0.9, hr * 0.18, side * hr * 0.6], [s.eye.r * 0.3, s.eye.r * 0.3, s.eye.r * 0.3]);
      head.add(pupil); eyes.push(pupil);
    } else {
      const e = part(G.ico1, M.dark, [hr * 0.7, hr * 0.26, side * hr * 0.68], [s.eye.r, s.eye.r, s.eye.r]);
      head.add(e); eyes.push(e);
    }
    if (s.tufts) head.add(part(G.cone, M.wing, [-hr * 0.1, hr * 0.95, side * hr * 0.55], [0.12, 0.22, 0.09], [0, 0, -side * 0.35]));
  }
  if (s.comb) {
    const cm = mat(s.comb);
    [-0.1, 0, 0.1].forEach((x, i) => head.add(part(G.ico1, cm, [x * hr * 1.4, hr * 0.95 - Math.abs(x) * 0.3, 0], [0.065, 0.09 - Math.abs(x) * 0.1, 0.03])));
    head.add(part(G.ico1, cm, [hr * 0.7, -hr * 0.55, 0], [0.04, 0.08, 0.03]));
  }
  g.add(head);
  return { group: g, head, eyes, look: new THREE.Vector2(), blinkAt: 2 + Math.random() * 3 };
}

function animateBird(b, t, lookX, lookY) {
  b.group.scale.y = 1 + Math.sin(t * 1.2 * TAU) * 0.012;
  const target = new THREE.Vector2(lookX * 0.55, lookY * 0.3);
  b.look.lerp(target, 0.06);
  b.head.rotation.y = b.look.x; b.head.rotation.z = b.look.y;
  const blink = t > b.blinkAt && t < b.blinkAt + 0.12;
  b.eyes.forEach((e) => { e.scale.y = blink ? e.scale.x * 0.1 : e.scale.x; });
  if (t > b.blinkAt + 0.12) b.blinkAt = t + 2.5 + Math.random() * 3;
}

/* ---------- stages (ground, road, lights) ---------- */
function cssColor(name, fallback) {
  const v = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  return new THREE.Color(v || fallback);
}
function addLights(scene, o) {
  const hemi = new THREE.HemisphereLight(o.sky, o.ground, o.hemi);
  const sun = new THREE.DirectionalLight(o.sunColor, o.sun);
  sun.position.set(4, 7, 3); sun.castShadow = true;
  sun.shadow.mapSize.set(1024, 1024);
  Object.assign(sun.shadow.camera, { left: -6, right: 6, top: 6, bottom: -6, near: 1, far: 20 });
  sun.shadow.bias = -0.0008; sun.shadow.normalBias = 0.02;
  scene.add(hemi, sun, sun.target);
  return { hemi, sun };
}
function makeRoadStage(scene) {
  const groundMat = new THREE.MeshStandardMaterial({ roughness: 1, metalness: 0, flatShading: true });
  const roadMat = new THREE.MeshStandardMaterial({ roughness: 1, metalness: 0 });
  const ground = new THREE.Mesh(G.disc, groundMat); ground.rotation.x = -Math.PI / 2; ground.scale.setScalar(7); ground.receiveShadow = true;
  const road = new THREE.Mesh(G.box, roadMat); road.position.set(0, 0.005, 0.15); road.scale.set(16, 0.01, 3.1); road.receiveShadow = true;
  scene.add(ground, road);
  const dashMat = new THREE.MeshStandardMaterial({ roughness: 1 });
  const movers = [];
  for (let i = 0; i < 9; i++) {
    const d = new THREE.Mesh(G.box, dashMat); d.position.set(-7 + i * 1.75, 0.012, 0.15); d.scale.set(0.7, 0.01, 0.08); scene.add(d); movers.push({ m: d, speed: 1 });
  }
  const bushMat = mat(0x7FA076), stoneMat = mat(0xB9B0A0);
  const r = rng(5);
  for (let i = 0; i < 10; i++) {
    const side = i % 2 ? 1 : -1, z = side > 0 ? 2.5 + r() * 0.9 : -1.9 - r() * 2.0;
    const big = side < 0 && r() > 0.35;
    const b = part(big ? G.ico1 : G.ico2, big ? bushMat : stoneMat, [-7 + r() * 14, 0, z], big ? [0.28 + r() * 0.2, 0.22 + r() * 0.16, 0.28 + r() * 0.2] : [0.1, 0.06, 0.1]);
    b.position.y = b.scale.y * 0.6; scene.add(b); movers.push({ m: b, speed: 1 });
  }
  const lights = addLights(scene, { sky: 0xFFE9D2, ground: 0xC9B89A, hemi: 1.05, sunColor: 0xFFE6C8, sun: 1.7 });
  function recolour() {
    const dark = darkMQ.matches;
    groundMat.color.copy(cssColor('--color-surface-alt', dark ? '#262925' : '#EFE9DE'));
    roadMat.color.copy(groundMat.color).lerp(cssColor('--color-ink', dark ? '#F2EFE8' : '#1B1B18'), dark ? 0.08 : 0.07);
    dashMat.color.copy(cssColor('--color-bg', dark ? '#121311' : '#F7F3EC'));
    lights.hemi.intensity = dark ? 0.7 : 1.05; lights.sun.intensity = dark ? 1.2 : 1.7;
  }
  recolour();
  function flow(dt, speed) {
    for (const o of movers) {
      o.m.position.x -= dt * 2.3 * speed;
      if (o.m.position.x < -8) o.m.position.x += 16;
    }
  }
  return { recolour, flow };
}

/* ---------- the three views ---------- */
function heroView(el) {
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(38, 16 / 9, 0.1, 60);
  const base = new THREE.Vector3(3.9, 1.9, 6.6), look = new THREE.Vector3(0.4, 0.85, 0.2);
  camera.position.copy(base); camera.lookAt(look);
  const stage = makeRoadStage(scene);
  const runner = makeRunner(); runner.group.position.set(-0.35, 0, -0.5); scene.add(runner.group);
  const cheetah = makeQuadruped(ANIMALS.cheetah); cheetah.group.position.set(0.95, 0, 0.85); cheetah.phase = 1.2; scene.add(cheetah.group);
  let speed = 1.15;
  return { el, scene, camera, recolour: stage.recolour,
    update(t, dt, px, py) {
      animateRunner(runner, t, speed); animateQuadruped(cheetah, t, speed * 0.95); stage.flow(reduce ? 0 : dt, speed);
      camera.position.x = lerp(camera.position.x, base.x + px * 0.45, 0.06);
      camera.position.y = lerp(camera.position.y, base.y + py * 0.25, 0.06);
      camera.lookAt(look);
    } };
}

function paceView(el) {
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(34, 16 / 9, 0.1, 60);
  const base = new THREE.Vector3(3.1, 1.85, 5.6), look = new THREE.Vector3(0.3, 0.8, 0.2);
  camera.position.copy(base); camera.lookAt(look);
  const stage = makeRoadStage(scene);
  const runner = makeRunner({ vest: 0x8B3A2F, hair: 0x241B16 }); runner.group.position.set(-0.4, 0, -0.5); scene.add(runner.group);
  const SPEED = { gentle: 0.72, calm: 0.88, steady: 1.02, swift: 1.32 };
  const PICK = { gentle: 'tortoise', calm: 'cat', steady: 'chital', swift: 'cheetah' };
  const animals = {};
  for (const [fam, key] of Object.entries(PICK)) {
    const a = makeQuadruped(ANIMALS[key]); a.group.position.set(0.9, 0, 0.85); a.group.visible = false; a.phase = 0.8; scene.add(a.group); animals[fam] = a;
  }
  let family = el.dataset.family || 'gentle', speed = SPEED[family], pop = 1;
  animals[family].group.visible = true;
  window.addEventListener('fc:pace', (e) => {
    const next = e.detail && e.detail.family;
    if (!PICK[next] || next === family) return;
    animals[family].group.visible = false;
    family = next; animals[family].group.visible = true; pop = 0; needsRender = true;
  });
  return { el, scene, camera, recolour: stage.recolour,
    update(t, dt, px, py) {
      speed = lerp(speed, SPEED[family], 0.08);
      pop = reduce ? 1 : Math.min(1, pop + dt / 0.3);
      const e = 1 - Math.pow(1 - pop, 3);                     // decelerate
      animals[family].group.scale.setScalar(0.9 + 0.1 * e);
      animateRunner(runner, t, speed); animateQuadruped(animals[family], t, speed); stage.flow(reduce ? 0 : dt, speed);
      camera.position.x = lerp(camera.position.x, base.x + px * 0.35, 0.06);
      camera.position.y = lerp(camera.position.y, base.y + py * 0.2, 0.06);
      camera.lookAt(look);
    } };
}

function dayNightView(el) {
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(38, 16 / 9, 0.1, 80);
  camera.position.set(0.6, 1.85, 4.6); camera.lookAt(0, 1.4, 0);
  const DAWN = { top: 0xE8A77A, bottom: 0xFBE6CF, hemiSky: 0xFFE2C4, hemiGround: 0xC9B89A, hemi: 1.0, sun: 0xFFD9A8, sunI: 1.8, grass: 0xB9C9A0, branch: 0x6B4A33 };
  const NIGHT = { top: 0x0F1430, bottom: 0x2B3366, hemiSky: 0x5A6BB8, hemiGround: 0x1C2238, hemi: 0.55, sun: 0xB9C6FF, sunI: 0.9, grass: 0x27372E, branch: 0x3A2E2A };
  // sky: a vertex-coloured plane far behind the stage
  const skyGeo = G.plane.clone();
  skyGeo.setAttribute('color', new THREE.Float32BufferAttribute(new Float32Array(12), 3));
  const sky = new THREE.Mesh(skyGeo, new THREE.MeshBasicMaterial({ vertexColors: true }));
  sky.position.set(0, 5, -9); sky.scale.set(60, 30, 1); scene.add(sky);
  const grassMat = new THREE.MeshStandardMaterial({ roughness: 1, flatShading: true });
  const ground = new THREE.Mesh(G.disc, grassMat); ground.rotation.x = -Math.PI / 2; ground.scale.setScalar(14); ground.receiveShadow = true; scene.add(ground);
  const branchMat = new THREE.MeshStandardMaterial({ roughness: 1, flatShading: true });
  const branch = part(G.cyl, branchMat, [0, 1.05, 0], [0.14, 3.6, 0.14], [0, 0, Math.PI / 2]); branch.receiveShadow = true; scene.add(branch);
  scene.add(limb(branchMat, [-1.5, 1.05, 0], [-2.1, 1.75, 0.2], 0.05));
  scene.add(limb(branchMat, [1.6, 1.05, 0], [2.0, 1.55, -0.2], 0.04));
  const sun = new THREE.Mesh(G.ico2, new THREE.MeshBasicMaterial({ color: 0xFFD9A8 })); sun.scale.setScalar(0.9); scene.add(sun);
  const moon = new THREE.Mesh(G.ico2, new THREE.MeshBasicMaterial({ color: 0xEDF1FB })); moon.scale.setScalar(0.55); scene.add(moon);
  const starPos = new Float32Array(240 * 3); const r = rng(21);
  for (let i = 0; i < 240; i++) { starPos[i * 3] = -16 + r() * 32; starPos[i * 3 + 1] = 1.5 + r() * 12; starPos[i * 3 + 2] = -8.4 + r() * 1.2; }
  const starGeo = new THREE.BufferGeometry(); starGeo.setAttribute('position', new THREE.BufferAttribute(starPos, 3));
  const starMat = new THREE.PointsMaterial({ color: 0xFFFFFF, size: 0.07, transparent: true, opacity: 0, depthWrite: false });
  scene.add(new THREE.Points(starGeo, starMat));
  const lights = addLights(scene, { sky: DAWN.hemiSky, ground: DAWN.hemiGround, hemi: DAWN.hemi, sunColor: DAWN.sun, sun: DAWN.sunI });
  lights.sun.position.set(-4, 6, 4);

  const rooster = makeBird(BIRDS.rooster); rooster.group.position.set(0.1, 1.12, 0.05); rooster.group.rotation.y = -0.85; scene.add(rooster.group);
  const owl = makeBird(BIRDS.owl); owl.group.position.set(0.05, 1.12, 0.05); owl.group.rotation.y = -0.85; owl.group.visible = false; scene.add(owl.group);
  let p = 0, shown = 'rooster', pop = 1;
  const c = { a: new THREE.Color(), b: new THREE.Color() };
  function paint(q) {
    const col = skyGeo.attributes.color;
    c.a.setHex(DAWN.top).lerp(c.b.setHex(NIGHT.top), q); col.setXYZ(0, c.a.r, c.a.g, c.a.b); col.setXYZ(1, c.a.r, c.a.g, c.a.b);
    c.a.setHex(DAWN.bottom).lerp(c.b.setHex(NIGHT.bottom), q); col.setXYZ(2, c.a.r, c.a.g, c.a.b); col.setXYZ(3, c.a.r, c.a.g, c.a.b);
    col.needsUpdate = true;
    grassMat.color.setHex(DAWN.grass).lerp(c.b.setHex(NIGHT.grass), q);
    branchMat.color.setHex(DAWN.branch).lerp(c.b.setHex(NIGHT.branch), q);
    lights.hemi.color.setHex(DAWN.hemiSky).lerp(c.b.setHex(NIGHT.hemiSky), q);
    lights.hemi.groundColor.setHex(DAWN.hemiGround).lerp(c.b.setHex(NIGHT.hemiGround), q);
    lights.hemi.intensity = lerp(DAWN.hemi, NIGHT.hemi, q);
    lights.sun.color.setHex(DAWN.sun).lerp(c.b.setHex(NIGHT.sun), q); lights.sun.intensity = lerp(DAWN.sunI, NIGHT.sunI, q);
    sun.position.set(-4.6 + q * 1.2, 4.0 - q * 7.5, -7); moon.position.set(4.2, -3.5 + q * 9.5, -7);
    starMat.opacity = clamp01((q - 0.45) * 2.2);
    const want = q < 0.5 ? 'rooster' : 'owl';
    if (want !== shown) { shown = want; rooster.group.visible = want === 'rooster'; owl.group.visible = want === 'owl'; pop = 0; }
  }
  paint(0);
  return { el, scene, camera, recolour() {},
    update(t, dt, px, py, rect, H) {
      // 0 when the view's top reaches the viewport bottom, 1 when its bottom reaches the top; sampled, never a scroll listener
      const raw = clamp01((H - rect.top) / (H + rect.height));
      const target = clamp01((raw - 0.35) / 0.3);   // dawn while the stage enters, full night once its top meets the viewport top
      p = reduce ? (target > 0.5 ? 1 : 0) : lerp(p, target, 0.12);
      paint(p);
      pop = reduce ? 1 : Math.min(1, pop + dt / 0.35);
      const e = 1 - Math.pow(1 - pop, 3);
      (shown === 'owl' ? owl : rooster).group.scale.setScalar(0.88 + 0.12 * e);
      animateBird(shown === 'owl' ? owl : rooster, reduce ? 0.3 : t, px, py);
    } };
}

/* ---------- renderer + loop ---------- */
let needsRender = true;
const canvas = document.getElementById('scene-canvas');
if (canvas) {
  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: 'low-power' });
  } catch (e) { renderer = null; }
  if (!renderer) { document.documentElement.classList.add('no-3d'); }
  else {
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.NoToneMapping;
    renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFShadowMap;
    renderer.setScissorTest(true);
    renderer.setClearColor(0x000000, 0);
    canvas.setAttribute('role', 'img');
    canvas.setAttribute('aria-label', 'Animated scenes: a runner jogging with an animal beside them, and a bird on a branch as dawn turns to night.');

    const BUILD = { hero: heroView, pace: paceView, daynight: dayNightView };
    const views = [];
    document.querySelectorAll('[data-scene]').forEach((el) => {
      const b = BUILD[el.dataset.scene]; if (!b) return;
      const v = b(el); v.visible = false; views.push(v);
    });
    const io = new IntersectionObserver((entries) => {
      for (const en of entries) { const v = views.find((x) => x.el === en.target); if (v) v.visible = en.isIntersecting; }
      needsRender = true;
    }, { rootMargin: '10% 0px' });
    views.forEach((v) => io.observe(v.el));

    function resize() { renderer.setSize(canvas.clientWidth, canvas.clientHeight, false); needsRender = true; }
    new ResizeObserver(resize).observe(canvas);
    window.addEventListener('resize', resize, { passive: true });
    resize();

    let px = 0, py = 0;
    if (finePointer.matches && !reduce) {
      window.addEventListener('pointermove', (e) => { px = (e.clientX / window.innerWidth) * 2 - 1; py = (e.clientY / window.innerHeight) * 2 - 1; }, { passive: true });
    }
    if (reduce) window.addEventListener('scroll', () => { needsRender = true; }, { passive: true });
    darkMQ.addEventListener('change', () => { views.forEach((v) => v.recolour()); needsRender = true; });
    window.addEventListener('fc:typeface', () => { needsRender = true; });

    let t = 0.3, last = performance.now();
    function frame(now) {
      const dt = Math.min(0.05, (now - last) / 1000); last = now;
      if (!reduce) t += dt;
      if (reduce && !needsRender) return;
      needsRender = false;
      const W = canvas.clientWidth, H = canvas.clientHeight;
      renderer.setScissorTest(false); renderer.clear(); renderer.setScissorTest(true);   // always clear: stage rects move with scroll
      if (!views.some((v) => v.visible)) return;
      for (const v of views) {
        if (!v.visible) continue;
        const r = v.el.getBoundingClientRect();
        if (r.bottom < 0 || r.top > H || r.right < 0 || r.left > W) continue;
        const left = Math.round(r.left), bottom = Math.round(H - r.bottom), w = Math.round(r.width), h = Math.round(r.height);
        if (w <= 0 || h <= 0) continue;
        v.update(t, dt, px, py, r, H);
        v.camera.aspect = w / h; v.camera.updateProjectionMatrix();
        renderer.setViewport(left, bottom, w, h); renderer.setScissor(left, bottom, w, h);
        renderer.render(v.scene, v.camera);
      }
    }
    renderer.setAnimationLoop(frame);
    document.addEventListener('visibilitychange', () => { renderer.setAnimationLoop(document.hidden ? null : frame); last = performance.now(); });
    document.documentElement.classList.add('has-3d');
    window.__fcViews = views;   // debug hooks: visibility flags per stage, and a forced frame (the preview pane throttles rAF)
    window.__fcRender = () => { needsRender = true; frame(performance.now()); };
  }
}

export { ANIMALS, BIRDS };
