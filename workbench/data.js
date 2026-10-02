/* Flying Cobra workbench — mock data mirroring the Phase 1 shapes (docs/API.md) and the seed
   (supabase/migrations/0005, 0007). Swapping to Supabase later replaces this file, not the screens.
   Exposed as window.DATA. */
(function () {
  'use strict';

  // name, slug, family, rarity, flavour, then rule fields: tier(0 speed/1 time/2 explorer/3 state/4 migratory)
  const A = (name, family, rarity, flavour, rule = {}) => Object.assign({ name, slug: name.toLowerCase().replace(/[^a-z]+/g, '-'), family, rarity, flavour, tier: 0, bands: [family] }, rule);
  const animals = [
    // speed families (tier 0)
    A('Chinkara','swift','common','the desert dancer'), A('Horse','swift','common','born to gallop'),
    A('Indian Hare','swift','uncommon','quick as a thought'), A('Blackbuck','swift','uncommon','the spiral-horned sprinter'),
    A('Peregrine Falcon','swift','rare','the fastest thing alive'), A('Cheetah','swift','epic','the comeback sprinter'),
    A('Chital','steady','common','the dappled wanderer'), A('Desi Dog','steady','common',"everyone's running partner"),
    A('Nilgai','steady','uncommon','the blue bull of the plains'), A('Dhole','steady','uncommon','the pack hunter'),
    A('Indian Wolf','steady','rare','the grassland ghost'), A('Leopard','steady','epic','the shadow that walks anywhere'),
    A('Rabbit','calm','common','soft paws, big heart'), A('Cat','calm','common','curious and unbothered'),
    A('Grey Langur','calm','uncommon','the temple acrobat'), A('Peacock','calm','uncommon','the monsoon dancer'),
    A('Smooth-coated Otter','calm','rare',"the river's playmate"), A('Mouse Deer','calm','epic','small, secret, sure-footed'),
    A('Star Tortoise','gentle','common','unstoppable'), A('Hamster','gentle','common','the midnight marathoner'),
    A('Porcupine','gentle','uncommon','the quilled knight'), A('Sloth Bear','gentle','uncommon','the shaggy wanderer'),
    A('Pangolin','gentle','rare','the armoured pilgrim'), A('Elephant','gentle','epic','the tireless traveller', { bands: ['gentle','calm'], minKm: 8 }),
    // time of day (tier 1)
    A('Indian Eagle-Owl','time','common','the one who sees in the dark', { tier: 1, timeWindows: ['night'] }),
    A('Nightjar','time','uncommon','the voice of the dusk road', { tier: 1, timeWindows: ['night'] }),
    A('Fruit Bat','time','uncommon','the orchard pilot', { tier: 1, timeWindows: ['night'] }),
    A('Palm Civet','time','rare','the rooftop wanderer', { tier: 1, timeWindows: ['night'] }),
    A('Rooster','time','common','first to call the day', { tier: 1, timeWindows: ['dawn'] }),
    A('Bulbul','time','common','the morning singer', { tier: 1, timeWindows: ['dawn'] }),
    A('Koel','time','uncommon','the summer caller', { tier: 1, timeWindows: ['dawn'] }),
    A('Indian Roller','time','rare','the sky in a bird', { tier: 1, timeWindows: ['dawn'] }),
    // explorer (tier 2)
    A('Indian Fox','explorer','common','the lane finder', { tier: 2 }), A('Bengal Monitor','explorer','common','the wall walker', { tier: 2 }),
    A('Golden Jackal','explorer','uncommon','the edge of town', { tier: 2 }), A('Honey Badger','explorer','rare','afraid of nothing', { tier: 2 }),
    // regional souvenirs (tier 3) — a sample of the 36
    A('Lion-tailed Macaque','regional','rare','the Western Ghats elder', { tier: 3, regionCodes: ['IN-KA'] }),
    A('Great Hornbill','regional','rare','the forest\'s drumbeat', { tier: 3, regionCodes: ['IN-KL'] }),
    A('Olive Ridley Turtle','regional','rare','the moonlit arrival', { tier: 3, regionCodes: ['IN-GA'] }),
    A('Nilgiri Tahr','regional','rare','the cliff walker', { tier: 3, regionCodes: ['IN-TN'] }),
    A('House Sparrow','regional','rare','the neighbour who stayed', { tier: 3, regionCodes: ['IN-DL'] }),
    A('Striped Hyena','regional','rare','the night patrol', { tier: 3, regionCodes: ['IN-TG'] }),
    A('Indian Giant Squirrel','regional','rare','the canopy acrobat', { tier: 3, regionCodes: ['IN-MH'] }),
    A('Camel','regional','rare','the ship of the desert', { tier: 3, regionCodes: ['IN-RJ'] }),
    A('Fishing Cat','regional','rare','the mangrove hunter', { tier: 3, regionCodes: ['IN-WB'] }),
    // migratory (tier 4)
    A('Bar-headed Goose','migratory','rare','over the Himalaya', { tier: 4, requiresFlags: ['migratory_2'] }),
    A('Greater Flamingo','migratory','rare','the pink horizon', { tier: 4, requiresFlags: ['migratory_2'] }),
    A('Amur Falcon','migratory','epic','ten thousand kilometres', { tier: 4, requiresFlags: ['migratory_3'] }),
    A('Demoiselle Crane','migratory','epic','the dancer of Khichan', { tier: 4, requiresFlags: ['migratory_3'] }),
    // weekly bags (not drawn by simulate; used for pending cards)
    A('Red Panda','weekly','rare','the bamboo dreamer', { tier: -3 }), A('Sambar','weekly','rare','the forest sentinel', { tier: -3 }), A('Gharial','weekly','rare','the river\'s long smile', { tier: -3 }),
    A('Snow Leopard','weekly','epic','the grey ghost', { tier: -5 }), A('Black Panther','weekly','epic','night with a heartbeat', { tier: -5 }), A('Markhor','weekly','epic','the mountain king', { tier: -5 }),
    A('Bengal Tiger','weekly','legendary','the one the forest listens for', { tier: -7 }), A('Great Indian Bustard','weekly','legendary','the last of the grasslands', { tier: -7 }),
    // secret
    A('Himalayan Monal','secret','epic','the fully connected one', { tier: 0, bands: [], secret: true })
  ];
  const byName = Object.fromEntries(animals.map(a => [a.name, a]));
  const counters = { 'Cheetah': 41, 'Horse': 318, 'Chital': 212, 'Rabbit': 507, 'Star Tortoise': 266, 'Bengal Tiger': 8, 'Rooster': 640, 'Indian Eagle-Owl': 133, 'Bar-headed Goose': 17, 'Great Hornbill': 44, 'Olive Ridley Turtle': 29, 'Lion-tailed Macaque': 37 };
  animals.forEach(a => a.issued = counters[a.name] || (20 + (FC.hash(a.name) % 180)));

  const today = new Date('2026-10-02T00:00:00+05:30');
  const dAgo = n => { const d = new Date(today); d.setDate(d.getDate() - n); return d.toISOString().slice(0, 10); };
  const card = (name, serial, tier, finish, scope, date, stats, extra = {}) => Object.assign({ animal: byName[name], serial, tier, finish, scope, season: 'Festival of Lights 2026', statsLine: stats, verdict: 'verified', date, issuedAt: date + 'T07:00:00+05:30' }, extra);
  const run = (date, km, paceSec, hour, extra = {}) => Object.assign({ id: 'r-' + date + '-' + hour, date, km, paceSec, hour, movingS: Math.round(km * paceSec), eligible: true, verdict: 'verified', band: Engine.band(Engine.perfIndex(3600 / paceSec, km, extra.age || 30, extra.sex)) }, extra);

  const personas = [
    { id: 'arjun', name: 'Arjun', age: 24, sex: 'male', city: 'Bengaluru', state: 'IN-KA', blurb: 'Fast young sprinter. 5 km at 3:55/km, evenings.', permissions: ['location','motion','steps','heart_rate','activity'],
      runs: [run(dAgo(5), 5.0, 235, 17.5, {age:24,sex:'male'}), run(dAgo(3), 5.0, 235, 17.5, {age:24,sex:'male'}), run(dAgo(1), 5.0, 235, 17.5, {age:24,sex:'male'})],
      cards: [card('Horse', 318, 'young', 'plain', 'run', dAgo(5), '5.0 km · 19:35 · 3:55/km'), card('Chinkara', 161, 'young', 'plain', 'run', dAgo(3), '5.0 km · 19:35 · 3:55/km'), card('Cheetah', 42, 'young', 'plain', 'run', dAgo(1), '5.0 km · 19:35 · 3:55/km')],
      bonds: { horse: { earnWeeks: 1, stage: 'baby', count: 1 } }, pity: 0, runDaysLast7: 3, tierHistory: {} },
    { id: 'meera', name: 'Meera', age: 62, sex: 'female', city: 'Chennai', state: 'IN-TN', blurb: 'Endurance at dawn on the Marina. 12 km at 7:10/km.', permissions: ['location','motion','steps','heart_rate','activity'],
      runs: [run(dAgo(4), 12.0, 430, 5.9, {age:62,sex:'female'}), run(dAgo(1), 12.0, 430, 5.95, {age:62,sex:'female'})],
      cards: [card('Rooster', 640, 'adult', 'plain', 'run', dAgo(4), '12.0 km · 1:26:00 · 7:10/km'), card('Pangolin', 88, 'adult', 'plain', 'run', dAgo(1), '12.0 km · 1:26:00 · 7:10/km')],
      bonds: {}, pity: 0, runDaysLast7: 2, tierHistory: { 'time:dawn': 1 } },
    { id: 'ravi', name: 'Ravi', age: 35, sex: 'male', city: 'Pune', state: 'IN-MH', blurb: 'Seven days in a row last week. Phone only: location + steps.', permissions: ['location','steps'],
      runs: [0,1,2,3,4,5,6].map(i => run(dAgo(13 - i), 5.0, 327, 6.7, {age:35,sex:'male'})),
      cards: [card('Chital', 212, 'young', 'glow', 'run', dAgo(13), '5.0 km · 27:16 · 5:27/km'), card('Desi Dog', 401, 'young', 'glow', 'run', dAgo(11), '5.0 km · 27:16 · 5:27/km'), card('Dhole', 73, 'young', 'radiant', 'run', dAgo(7), '5.0 km · 27:16 · 5:27/km'),
              card('Bengal Tiger', 9, 'adult', 'radiant', 'weekly', dAgo(6), '7 days · 35 km', { variety: true })],
      bonds: { chital: { earnWeeks: 2, stage: 'baby', count: 3 } }, pity: 6, runDaysLast7: 0, tierHistory: {}, pendingWeekly: null },
    { id: 'priya', name: 'Priya', age: 30, sex: 'female', city: 'Bengaluru → Kochi → Goa', state: 'IN-GA', blurb: 'Traveller. Three states in three weeks.', permissions: ['location','motion','steps','heart_rate','activity'],
      runs: [run(dAgo(14), 5.0, 343, 7.2, {age:30,sex:'female',state:'IN-KA'}), run(dAgo(7), 5.0, 343, 6.8, {age:30,sex:'female',state:'IN-KL'}), run(dAgo(2), 5.0, 343, 7.0, {age:30,sex:'female',state:'IN-GA'})],
      cards: [card('Rabbit', 507, 'young', 'plain', 'run', dAgo(14), '5.0 km · 28:35 · 5:43/km'), card('Great Hornbill', 44, 'young', 'plain', 'run', dAgo(7), '5.0 km · 28:35 · 5:43/km'), card('Bar-headed Goose', 17, 'young', 'plain', 'run', dAgo(2), '5.0 km · 28:35 · 5:43/km')],
      bonds: {}, pity: 1, runDaysLast7: 1, tierHistory: { 'state:IN-KL': 1, migratory: 1 }, homeRegion: 'IN-KA' },
    { id: 'kabir', name: 'Kabir', age: 38, sex: 'male', city: 'Delhi', state: 'IN-DL', blurb: 'Night owl. 22:15 starts, 4 km at 6:00/km.', permissions: ['location','motion','steps','heart_rate','activity'],
      runs: [run(dAgo(1), 4.0, 360, 22.25, {age:38,sex:'male'})],
      cards: [card('Indian Eagle-Owl', 133, 'young', 'plain', 'run', dAgo(1), '4.0 km · 24:00 · 6:00/km')],
      bonds: {}, pity: 0, runDaysLast7: 1, tierHistory: { 'time:night': 1 } },
    { id: 'sana', name: 'Sana', age: 26, sex: 'female', city: 'Hyderabad', state: 'IN-TG', blurb: 'Collector running slow on purpose, chasing a rabbit. Phone only.', permissions: ['location','steps'],
      runs: [run(dAgo(3), 3.0, 450, 17.0, {age:26,sex:'female'}), run(dAgo(1), 3.0, 450, 17.1, {age:26,sex:'female'})],
      cards: [card('Cat', 388, 'baby', 'plain', 'run', dAgo(3), '3.0 km · 22:30 · 7:30/km'), card('Grey Langur', 97, 'baby', 'plain', 'run', dAgo(1), '3.0 km · 22:30 · 7:30/km')],
      bonds: {}, pity: 2, runDaysLast7: 2, tierHistory: {} },
    { id: 'new', name: 'New runner', age: null, sex: null, city: '—', state: null, blurb: 'Brand-new account. Nothing granted, nothing earned.', permissions: [], runs: [], cards: [], bonds: {}, pity: 0, runDaysLast7: 0, tierHistory: {}, fresh: true }
  ];

  const states = [['IN-KA','Karnataka'],['IN-KL','Kerala'],['IN-GA','Goa'],['IN-TN','Tamil Nadu'],['IN-DL','Delhi'],['IN-TG','Telangana'],['IN-MH','Maharashtra'],['IN-RJ','Rajasthan'],['IN-WB','West Bengal']];

  const permissions = [
    { key: 'location', title: 'Location while running', why: 'to measure distance and notice when you explore somewhere new.', store: 'your route, visible only to you.', lose: 'Without it there is no distance, so no card.' , icon: '📍' },
    { key: 'motion', title: 'Motion & fitness', why: 'to hear your footfall rhythm, which is how we know a run is a run.', store: 'a rhythm score per run, never raw movement.', lose: 'Runs still count; some rare animals stay out of reach.', icon: '👟' },
    { key: 'activity', title: 'Activity recognition', why: 'to start recording when you start running, so you never have to press a button.', store: 'the share of each run spent running or walking.', lose: 'You start runs by hand.', icon: '⏱' },
    { key: 'heart_rate', title: 'Heart rate', why: 'to grade effort fairly and tell a run from a car ride.', store: 'an average and a peak per run.', lose: 'Effort is judged from pace alone.', icon: '♥' },
    { key: 'notifications', title: 'Notifications', why: 'to tell you when a weekly card is waiting.', store: 'nothing.', lose: 'You find cards when you open the app.', icon: '🔔' }
  ];

  window.DATA = { animals, byName, personas, states, permissions, today: today.toISOString().slice(0, 10), dAgo, mkCard: card };
})();
