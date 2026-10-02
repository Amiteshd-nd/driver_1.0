-- Flying Cobra · 0010 animal illustration pipeline
-- Spec: docs/source/Running-App-Illustration-Pipeline-PRD.md · design note: docs/illustration-pipeline.md
-- One illustration per (animal, growth stage, variant, style version). The UNIQUE constraint is what makes
-- duplicates impossible; everything else (claiming, retries, review) is bookkeeping around it.

do $$ begin
  create type illustration_status_t as enum ('queued','generating','ready','failed','pending_review','approved','rejected');
exception when duplicate_object then null; end $$;

-- ---------- versioned style template ----------
create table if not exists style_templates (
  version      int primary key,
  name         text not null,
  template     text not null,            -- "{animal_name}", "{stage_cues}", "{features}" placeholders
  stage_cues   jsonb not null,           -- {"baby":"...","young":"...","adult":"..."}
  negative     text not null default '',
  qa_criteria  jsonb not null default '[]',
  retry_adjustments jsonb not null default '[]',
  output       jsonb not null default '{"size":"1024x1024","format":"png"}',
  is_active    boolean not null default true,
  created_by   uuid,
  created_at   timestamptz not null default now()
);

-- ---------- the ledger ----------
create table if not exists animal_illustrations (
  id             uuid primary key default gen_random_uuid(),
  animal_id      uuid not null references animals(id) on delete cascade,
  growth_stage   stage_t not null,
  variant        text not null default 'base',
  style_version  int not null references style_templates(version),
  status         illustration_status_t not null default 'queued',
  png_path       text,
  svg_path       text,
  content_hash   text,
  prompt_used    text,
  provider       text,
  model          text,
  seed           text,
  cost_cents     numeric(8,2) not null default 0,
  attempts       int not null default 0,
  max_attempts   int not null default 3,
  last_error     text,
  qa_notes       text,                   -- plain-language reason from the Illustrator Agent when it rejects
  claimed_at     timestamptz,
  claimed_by     text,
  reviewed_by    uuid,
  reviewed_at    timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (animal_id, growth_stage, variant, style_version)   -- THE dedup guarantee
);
create index if not exists animal_illustrations_status_idx on animal_illustrations(status, created_at);
create index if not exists animal_illustrations_animal_idx on animal_illustrations(animal_id, style_version);
drop trigger if exists animal_illustrations_updated_at on animal_illustrations;
create trigger animal_illustrations_updated_at before update on animal_illustrations for each row execute function set_updated_at();

-- animals gain a pointer to the style version they should be rendered with, and a summary for the admin list
alter table animals add column if not exists current_style_version int references style_templates(version);
alter table animals add column if not exists illustration_status text not null default 'none';  -- none | partial | ready

-- ---------- deterministic storage paths ----------
-- bucket animal-art: {slug}/{stage}/{variant}/v{style_version}.png|svg  (immutable per path)
create or replace function illustration_path(p_slug text, p_stage stage_t, p_variant text, p_version int, p_ext text) returns text
language sql immutable as $$
  select format('%s/%s/%s/v%s.%s', p_slug, p_stage, p_variant, p_version, p_ext)
$$;

-- ---------- enqueue (idempotent) ----------
-- For one animal: upsert a queued row per required stage for the active style version. A second call is a no-op
-- on rows that already exist in any state (the unique constraint + ON CONFLICT DO NOTHING).
create or replace function illustrations_enqueue(p_animal uuid, p_variant text default 'base', p_version int default null) returns int
language plpgsql volatile security definer set search_path = public as $$
declare v int; n int := 0; s stage_t;
begin
  v := coalesce(p_version, (select version from style_templates where is_active order by version desc limit 1));
  if v is null then raise exception 'no active style template'; end if;
  foreach s in array array['baby','young','adult']::stage_t[] loop
    insert into animal_illustrations(animal_id, growth_stage, variant, style_version)
    values (p_animal, s, p_variant, v) on conflict (animal_id, growth_stage, variant, style_version) do nothing;
    if found then n := n + 1; end if;
  end loop;
  update animals set current_style_version = coalesce(current_style_version, v) where id = p_animal;
  return n;  -- number of NEW rows created (0 means everything already existed)
end $$;

-- "Generate all missing": enqueue every active animal. Returns how many new rows were created.
create or replace function illustrations_enqueue_missing(p_variant text default 'base') returns int
language plpgsql volatile security definer set search_path = public as $$
declare a record; n int := 0;
begin
  if not is_admin() and auth.role() <> 'service_role' then raise exception 'admin only' using errcode = '42501'; end if;
  for a in select id from animals where is_active loop n := n + illustrations_enqueue(a.id, p_variant); end loop;
  return n;
end $$;

-- Creating an animal enqueues its illustrations automatically (PRD §5 step 1)
create or replace function animals_enqueue_illustrations() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from style_templates where is_active) then perform illustrations_enqueue(new.id); end if;
  return new;
end $$;
drop trigger if exists animals_enqueue_illustrations on animals;
create trigger animals_enqueue_illustrations after insert on animals for each row execute function animals_enqueue_illustrations();

-- ---------- claim / complete / fail (the worker protocol) ----------
-- Atomic claim: SKIP LOCKED means two workers never take the same row. Stale claims are re-queued first.
create or replace function illustrations_claim(p_batch int default 3, p_worker text default 'worker', p_stale_minutes int default 10)
returns setof animal_illustrations language plpgsql volatile security definer set search_path = public as $$
begin
  update animal_illustrations set status = 'queued', claimed_at = null, claimed_by = null,
         last_error = coalesce(last_error, '') || ' [stale claim re-queued]'
   where status = 'generating' and claimed_at < now() - make_interval(mins => p_stale_minutes);
  return query
    with picked as (
      select id from animal_illustrations
       where status = 'queued' and attempts < max_attempts
       order by created_at
       limit p_batch
       for update skip locked)
    update animal_illustrations i set status = 'generating', claimed_at = now(), claimed_by = p_worker, attempts = i.attempts + 1
      from picked where i.id = picked.id
    returning i.*;
end $$;

create or replace function illustrations_complete(p_id uuid, p_png text, p_svg text, p_hash text, p_prompt text, p_provider text, p_model text, p_seed text, p_cost_cents numeric, p_qa_notes text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  update animal_illustrations set status = 'pending_review', png_path = p_png, svg_path = p_svg, content_hash = p_hash, prompt_used = p_prompt,
         provider = p_provider, model = p_model, seed = p_seed, cost_cents = cost_cents + coalesce(p_cost_cents, 0), qa_notes = p_qa_notes,
         last_error = null, claimed_at = null, claimed_by = null
   where id = p_id and status = 'generating';
  perform illustrations_refresh_summary((select animal_id from animal_illustrations where id = p_id));
end $$;

-- A failed attempt: back to the queue while attempts remain, else failed with the plain-language reason.
create or replace function illustrations_fail(p_id uuid, p_error text, p_qa_notes text default null, p_cost_cents numeric default 0)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  update animal_illustrations set
      status = case when attempts >= max_attempts then 'failed'::illustration_status_t else 'queued'::illustration_status_t end,
      last_error = p_error, qa_notes = coalesce(p_qa_notes, qa_notes), cost_cents = cost_cents + coalesce(p_cost_cents, 0),
      claimed_at = null, claimed_by = null
   where id = p_id and status = 'generating';
end $$;

-- ---------- review ----------
create or replace function illustrations_review(p_id uuid, p_decision text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare r animal_illustrations;
begin
  if not is_admin() and auth.role() <> 'service_role' then raise exception 'admin only' using errcode = '42501'; end if;
  select * into r from animal_illustrations where id = p_id;
  if r.id is null then raise exception 'not found'; end if;
  if p_decision = 'approve' then
    update animal_illustrations set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now() where id = p_id;
  elsif p_decision = 'reject' then
    update animal_illustrations set status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now() where id = p_id;
  elsif p_decision = 'regenerate' then
    -- keep the old files (immutable paths); the new attempt only replaces the row's paths on completion
    update animal_illustrations set status = 'queued', attempts = 0, last_error = null, qa_notes = null, reviewed_by = auth.uid(), reviewed_at = now() where id = p_id;
  else raise exception 'decision must be approve, reject or regenerate'; end if;
  perform illustrations_refresh_summary(r.animal_id);
end $$;

-- animals.art mirrors the APPROVED illustration per stage (so existing readers keep working), and the summary
create or replace function illustrations_refresh_summary(p_animal uuid) returns void language plpgsql volatile security definer set search_path = public as $$
declare approved int; artj jsonb := '{}'::jsonb; r record; v int;
begin
  select current_style_version into v from animals where id = p_animal;
  for r in select i.growth_stage, i.png_path, i.svg_path from animal_illustrations i
            where i.animal_id = p_animal and i.variant = 'base' and i.status = 'approved' and i.style_version = coalesce(v, i.style_version) loop
    artj := artj || jsonb_build_object(r.growth_stage::text, jsonb_build_object('png', r.png_path, 'svg', r.svg_path));
  end loop;
  approved := (select count(*) from jsonb_object_keys(artj));
  update animals set art = artj, illustration_status = case when approved = 0 then 'none' when approved < 3 then 'partial' else 'ready' end where id = p_animal;
end $$;

-- ---------- read side ----------
-- Public-safe view: approved art only, resolved to storage paths. Clients build the public URL with the bucket base.
create or replace view animal_art as
  select i.animal_id, a.slug, i.growth_stage, i.variant, i.style_version, i.png_path, i.svg_path, i.content_hash
    from animal_illustrations i join animals a on a.id = i.animal_id
   where i.status = 'approved';

create or replace function illustration_urls(p_animal uuid, p_stage stage_t default 'adult', p_variant text default 'base') returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce((select jsonb_build_object('png', png_path, 'svg', svg_path, 'style_version', style_version, 'status', 'approved')
                     from animal_art where animal_id = p_animal and growth_stage = p_stage and variant = p_variant
                    order by style_version desc limit 1),
                  jsonb_build_object('png', null, 'svg', null, 'status', coalesce((select status::text from animal_illustrations where animal_id = p_animal and growth_stage = p_stage and variant = p_variant order by style_version desc limit 1), 'none')))
$$;

-- Admin library listing (every animal × stage × variant with status, provider, attempts, cost)
create or replace function admin_illustration_library() returns jsonb language sql stable security definer set search_path = public as $$
  select case when is_admin() or auth.role() = 'service_role' then
    coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'animal_id', a.id, 'slug', a.slug, 'name', a.name, 'family', a.family, 'stage', i.growth_stage, 'variant', i.variant,
      'style_version', i.style_version, 'status', i.status, 'png', i.png_path, 'svg', i.svg_path, 'provider', i.provider, 'model', i.model,
      'attempts', i.attempts, 'cost_cents', i.cost_cents, 'last_error', i.last_error, 'qa_notes', i.qa_notes, 'updated_at', i.updated_at)
      order by a.sort_order, a.name, i.growth_stage), '[]'::jsonb)
  else '[]'::jsonb end
  from animal_illustrations i join animals a on a.id = i.animal_id
$$;

-- card_json now carries the approved illustration for the card's stage (clients prefer svg, then png, then placeholder)
create or replace function card_json(c cards) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', c.id, 'animal_id', c.animal_id, 'slug', a.slug, 'name', a.name, 'code', a.code, 'family', a.family, 'rarity', a.rarity,
    'flavour_line', a.flavour_line, 'palette', a.palette, 'art', a.art,
    'illustration', illustration_urls(a.id, c.stage, 'base'),
    'serial_no', c.serial_no, 'serial', a.name || ' #' || lpad(c.serial_no::text, coalesce((cfg('app')->>'serial_pad')::int, 4), '0'),
    'scope', c.scope, 'period_key', c.period_key, 'tier', c.tier, 'stage', c.stage, 'finish', c.finish,
    'season', (select name from seasons s where s.id = c.season_id), 'stats', c.stats, 'verdict', c.verdict, 'issued_at', c.issued_at,
    'verify_url', (cfg('app')->>'verify_base_url') || '/' || a.slug || '/' || c.serial_no)
  from animals a where a.id = c.animal_id
$$;

-- ---------- RLS & grants ----------
alter table style_templates enable row level security;
alter table animal_illustrations enable row level security;
select _policy('style_read',  'style_templates', 'select', 'auth.role() in (''authenticated'',''service_role'')');
select _policy('style_admin', 'style_templates', 'all',    'is_admin()');
select _policy('illus_read',  'animal_illustrations', 'select', 'is_admin()');   -- players read art via animals.art / card_json / illustration_urls
select _policy('illus_admin', 'animal_illustrations', 'all',    'is_admin()');
grant select on style_templates, animal_illustrations, animal_art to authenticated;
grant insert, update, delete on style_templates, animal_illustrations to authenticated;
grant all on style_templates, animal_illustrations to service_role;
revoke execute on function illustrations_claim(int, text, int), illustrations_complete(uuid, text, text, text, text, text, text, text, numeric, text), illustrations_fail(uuid, text, text, numeric), illustrations_refresh_summary(uuid), illustrations_enqueue(uuid, text, int) from public, anon, authenticated;
grant execute on function illustrations_enqueue_missing(text), illustrations_review(uuid, text), admin_illustration_library(), illustration_urls(uuid, stage_t, text), illustration_path(text, stage_t, text, int, text) to authenticated;
grant execute on function illustration_urls(uuid, stage_t, text) to anon;
grant execute on all functions in schema public to service_role;

-- ---------- seed the v1 style template (mirrors design_system/illustration-style.json) ----------
insert into style_templates(version, name, template, stage_cues, negative, qa_criteria, retry_adjustments, output) values (1, 'Flying Cobra illustration style v1',
 'A single {animal_name}, {stage_cues}. {features}. Flat vector illustration with clean geometric shapes and smooth curves, limited harmonious palette, soft cel shading, no outlines or thin consistent outlines. Light, airy background in a pale warm tone with a soft radial glow behind the animal, gentle light rays and a few small sparkles for a quiet majestic feel. The animal is centred, facing slightly left, whole body visible, in a calm confident pose. No text, no letters, no logo, no watermark, no border, no frame, no people, no other animals. Not photorealistic, not 3D render, not painterly. Square composition with generous margin.',
 '{"baby":"as a baby: rounder body, noticeably bigger head and eyes, shorter limbs, soft and curious","young":"as a young animal: lighter build, slightly oversized paws or feet, alert and playful","adult":"as a full-grown adult: true proportions, strong confident stance, calm and majestic"}',
 'photo, photorealistic, realistic fur texture, 3D, render, painterly, sketch, text, letters, caption, watermark, signature, logo, border, frame, dark background, busy background, scenery, multiple animals, people, hands, blurry, cropped, deformed, extra limbs',
 '["the species is recognisably {animal_name}","exactly one animal, whole body visible, centred","light background (pale, airy), not dark or busy","flat vector illustration look: clean shapes, not a photograph, not a 3D render","no text, letters, watermark, logo, border or frame","subtle majestic effect present: a soft glow, light rays or sparkles","stage cues read correctly for {stage}"]',
 '["Emphasise: exactly one animal, whole body visible, centred, nothing else in the frame.","Emphasise: flat vector illustration, simple shapes, absolutely not a photograph.","Emphasise: plain pale background, no scenery, no text anywhere."]',
 '{"size":"1024x1024","format":"png","background":"opaque"}')
on conflict (version) do nothing;

-- Existing animals get their queue rows now (new animals get them via the trigger)
do $$ declare a record; begin for a in select id from animals where is_active loop perform illustrations_enqueue(a.id); end loop; end $$;
