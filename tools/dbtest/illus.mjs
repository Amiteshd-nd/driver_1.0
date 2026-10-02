import { loadDb, signIn, createUser } from './harness.mjs';
import assert from 'node:assert/strict';
const db = await loadDb(); const q = async (s,p=[]) => (await db.query(s,p)).rows; const one = async (s,p=[]) => (await q(s,p))[0];
let ok=0, bad=0; const t = async (n,f)=>{ try{ await f(); ok++; console.log(' ✓',n);}catch(e){bad++; console.log(' ✗',n,'\n   ',e.message.replace(/\s+/g,' ').slice(0,300));} };
await t('every active animal has exactly 3 queued rows (one per stage) for style v1', async()=>{
  const r = await one(`select count(*)::int animals, (select count(*)::int from animal_illustrations) rows, (select count(distinct animal_id)::int from animal_illustrations) covered from animals where is_active`);
  assert.equal(r.rows, r.animals*3); assert.equal(r.covered, r.animals);
});
await t('enqueue is idempotent: a second call creates nothing', async()=>{
  const a = await one(`select id from animals where slug='cheetah'`); const n = (await one(`select illustrations_enqueue($1) n`,[a.id])).n; assert.equal(n,0);
  const cnt = (await one(`select count(*)::int c from animal_illustrations where animal_id=$1`,[a.id])).c; assert.equal(cnt,3);
});
await t('a direct duplicate insert is rejected by the unique constraint', async()=>{
  const a = await one(`select id from animals where slug='cheetah'`);
  await assert.rejects(q(`insert into animal_illustrations(animal_id, growth_stage, variant, style_version) values ($1,'baby','base',1)`,[a.id]), /duplicate key|unique/);
});
await t('creating a new animal auto-enqueues its three stages', async()=>{
  await q(`insert into animals(slug,code,name,family,rarity,flavour_line) values ('test-lynx','TLX','Test Lynx','calm','rare','the tufted listener')`);
  const c = (await one(`select count(*)::int c from animal_illustrations i join animals a on a.id=i.animal_id where a.slug='test-lynx'`)).c; assert.equal(c,3);
});
let claimed;
await t('claim takes a batch atomically and marks it generating with attempts=1', async()=>{
  claimed = await q(`select * from illustrations_claim(2,'w1')`); assert.equal(claimed.length,2);
  assert.ok(claimed.every(r=>r.status==='generating' && r.attempts===1 && r.claimed_by==='w1'));
  const again = await q(`select * from illustrations_claim(2,'w2')`); assert.ok(!again.some(r=>claimed.some(c=>c.id===r.id)), 'second worker must not get the same rows');
});
await t('stale claims are re-queued on the next claim', async()=>{
  await q(`update animal_illustrations set claimed_at = now() - interval '30 minutes' where id=$1`,[claimed[0].id]);
  await q(`select * from illustrations_claim(0,'w3')`);
  const r = await one(`select status, last_error from animal_illustrations where id=$1`,[claimed[0].id]); assert.equal(r.status,'queued'); assert.match(r.last_error,/stale/);
});
await t('fail re-queues while attempts remain, then marks failed with the reason', async()=>{
  const row = (await q(`select * from illustrations_claim(1,'w4')`))[0];
  await q(`select illustrations_fail($1,'provider timeout','QA: two animals in frame', 4)`,[row.id]);
  let r = await one(`select status, attempts, qa_notes, cost_cents from animal_illustrations where id=$1`,[row.id]); assert.equal(r.status,'queued'); assert.equal(r.qa_notes,'QA: two animals in frame'); assert.equal(+r.cost_cents,4);
  await q(`update animal_illustrations set attempts = max_attempts - 1 where id=$1`,[row.id]);
  const again = (await q(`select * from illustrations_claim(1000,'w5')`)).find(x=>x.id===row.id); assert.ok(again,'should be claimable once more');
  await q(`select illustrations_fail($1,'still wrong','QA: photo-realistic')`,[row.id]);
  r = await one(`select status from animal_illustrations where id=$1`,[row.id]); assert.equal(r.status,'failed');
});
let cheetahBaby;
await t('complete → pending_review; approve → animals.art mirrors it and summary becomes partial', async()=>{
  await q(`update animal_illustrations set status='queued', attempts=0, claimed_at=null`);
  cheetahBaby = await one(`select i.id, a.slug from animal_illustrations i join animals a on a.id=i.animal_id where a.slug='cheetah' and growth_stage='baby'`);
  await q(`update animal_illustrations set status='generating', attempts=1, claimed_at=now() where id=$1`,[cheetahBaby.id]);
  const png = (await one(`select illustration_path('cheetah','baby','base',1,'png') p`)).p; assert.equal(png,'cheetah/baby/base/v1.png');
  await q(`select illustrations_complete($1,$2,$3,'abc123','prompt text','mock','mock-v1','42',0,'QA passed')`,[cheetahBaby.id,png,png.replace('.png','.svg')]);
  let r = await one(`select status from animal_illustrations where id=$1`,[cheetahBaby.id]); assert.equal(r.status,'pending_review');
  const admin = await createUser(db,'admin@test.local','Admin'); await q(`update profiles set is_admin=true where id=$1`,[admin]); await signIn(db, admin);
  await q(`select illustrations_review($1,'approve')`,[cheetahBaby.id]);
  const a = await one(`select art, illustration_status from animals where slug='cheetah'`);
  assert.equal(a.art.baby.png,'cheetah/baby/base/v1.png'); assert.equal(a.illustration_status,'partial');
  const u = (await one(`select illustration_urls((select id from animals where slug='cheetah'),'baby') u`)).u; assert.equal(u.status,'approved'); assert.equal(u.svg,'cheetah/baby/base/v1.svg');
  const none = (await one(`select illustration_urls((select id from animals where slug='cheetah'),'adult') u`)).u; assert.equal(none.status,'queued'); assert.equal(none.png,null);
});
await t('regenerate re-queues with attempts reset but keeps the approved file path until a new one completes', async()=>{
  await q(`select illustrations_review($1,'regenerate')`,[cheetahBaby.id]);
  const r = await one(`select status, attempts, png_path from animal_illustrations where id=$1`,[cheetahBaby.id]); assert.equal(r.status,'queued'); assert.equal(r.attempts,0); assert.equal(r.png_path,'cheetah/baby/base/v1.png');
  const a = await one(`select illustration_status from animals where slug='cheetah'`); assert.equal(a.illustration_status,'none');
});
await t('card_json exposes the approved illustration for the card stage', async()=>{
  await q(`update animal_illustrations set status='approved' where id=$1`,[cheetahBaby.id]); await q(`select illustrations_refresh_summary((select id from animals where slug='cheetah'))`);
  const u = await createUser(db,'p@test.local','P'); const c = await one(`select card_json(issue_card($1,(select id from animals where slug='cheetah'),'run','x',0,'baby','plain',null,'{}','verified',current_date)) j`,[u]);
  assert.equal(c.j.illustration.svg,'cheetah/baby/base/v1.svg'); assert.equal(c.j.illustration.status,'approved');
});
await t('players cannot read the ledger; admins and the library RPC can', async()=>{
  const p = await createUser(db,'pl@test.local','Pl'); await signIn(db,p); await q(`set role authenticated`);
  try { assert.equal((await q(`select * from animal_illustrations`)).length,0); const lib=(await one(`select admin_illustration_library() l`)).l; assert.equal(lib.length,0); } finally { await q(`reset role`); }
  const admin = await one(`select id from profiles where is_admin limit 1`); await signIn(db, admin.id); await q(`set role authenticated`);
  try { const lib=(await one(`select admin_illustration_library() l`)).l; assert.ok(lib.length>250); assert.ok(lib[0].stage && lib[0].status); } finally { await q(`reset role`); await signIn(db,null); }
});
console.log(`\n${ok} passed, ${bad} failed`); process.exit(bad?1:0);
