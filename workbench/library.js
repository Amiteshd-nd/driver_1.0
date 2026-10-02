/* Flying Cobra workbench — Illustration Library page (PRD §8) and the art loader.
   Talks to the pipeline API: locally tools/illustrate/serve.mjs (/api/*); in production the same shapes come
   from Supabase RPCs + the illustrate Edge Function (see README). Exposed as window.Library. */
(function () {
  'use strict';
  const esc = FC.esc;
  const API = window.PIPELINE_API || '/api';
  const ART_BASE = window.ART_BASE || '/workbench/art/';
  let rows = [], status = null, filter = { status: 'all', family: 'all' }, styleRows = [], draft = null;

  async function j(method, path, body) { const r = await fetch(API + path, { method, headers: { 'content-type': 'application/json' }, body: body ? JSON.stringify(body) : undefined }); if (!r.ok) throw new Error(await r.text()); return r.json(); }
  async function load() {
    try { [rows, status, styleRows] = await Promise.all([j('GET', '/illustrations'), j('GET', '/status'), j('GET', '/style')]); }
    catch (e) { // no pipeline API (static publish): read the manifest the local runner wrote
      const m = await fetch(ART_BASE + 'manifest.json').then(r => r.ok ? r.json() : null).catch(() => null);
      rows = m?.rows || []; status = m?.status || { provider: 'manifest', model: '—', qa: '—', counts: {} }; styleRows = m?.style || []; window.LIBRARY_READONLY = true;
    }
    window.dispatchEvent(new Event('fc:art-changed'));
  }

  /** Approved art for an animal slug + stage → {svg, png, url} or null. Used by the card renderer inside the phone. */
  function artFor(slug, stage) {
    const r = rows.find(x => x.slug === slug && x.stage === stage && x.status === 'approved' && (x.svg || x.png));
    if (!r) return null;
    const path = r.svg || r.png; return { svg: r.svg, png: r.png, url: ART_BASE + path, provider: r.provider };
  }
  function urlFor(path) { return path ? ART_BASE + path : null; }

  const PILL = { approved: 'success', pending_review: 'warn', failed: 'danger', rejected: 'danger', generating: 'accent', queued: 'muted', ready: 'accent' };
  function pill(s) { return `<span class="lib-pill lib-pill--${PILL[s] || 'muted'}">${esc(s.replace('_', ' '))}</span>`; }

  function render(host, mode) {
    host.hidden = false; host.setAttribute('data-mode', mode);
    const fams = [...new Set(rows.map(r => r.family))].sort();
    const shown = rows.filter(r => (filter.status === 'all' || r.status === filter.status) && (filter.family === 'all' || r.family === filter.family));
    const counts = (status && status.counts) || {};
    const cost = rows.reduce((s, r) => s + Number(r.cost_cents || 0), 0);
    host.innerHTML = `<style>
      .lib-head{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-bottom:12px}.lib-head h1{font-size:24px;margin:0;flex:1}
      .lib-counts{display:flex;flex-wrap:wrap;gap:6px}.lib-count{font-size:12px;border:1px solid var(--color-line);border-radius:999px;padding:3px 10px;color:var(--color-ink-muted)}.lib-count b{color:var(--color-ink);font-family:var(--font-display)}
      .lib-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px}.lib-card{background:var(--color-surface);border:1px solid var(--color-line);border-radius:14px;padding:10px;display:grid;gap:6px}
      .lib-thumb{aspect-ratio:1;border-radius:10px;background:var(--fam-bg,var(--color-surface-alt));display:grid;place-items:center;overflow:hidden;position:relative}.lib-thumb img{width:100%;height:100%;object-fit:cover}.lib-thumb .ph{font-family:var(--font-display);font-size:48px;color:var(--fam-fg);opacity:.5}
      .lib-name{font-family:var(--font-display);font-size:14px}.lib-meta{font-size:11px;color:var(--color-ink-muted);line-height:1.35}.lib-note{font-size:11px;color:var(--color-ink-muted);display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
      .lib-pill{font-size:10px;letter-spacing:.06em;text-transform:uppercase;font-weight:700;border-radius:999px;padding:2px 8px;background:var(--color-surface-alt);color:var(--color-ink-muted)}
      .lib-pill--success{background:color-mix(in srgb,var(--color-success) 18%,var(--color-surface));color:var(--color-success)}.lib-pill--warn{background:color-mix(in srgb,var(--color-warn) 18%,var(--color-surface));color:var(--color-warn)}
      .lib-pill--danger{background:color-mix(in srgb,var(--color-danger) 18%,var(--color-surface));color:var(--color-danger)}.lib-pill--accent{background:color-mix(in srgb,var(--color-accent) 18%,var(--color-surface));color:var(--color-accent)}
      .lib-actions{display:flex;gap:5px;flex-wrap:wrap}.lib-actions button{font:inherit;font-size:11px;font-weight: 700;border:1px solid var(--color-line);background:var(--color-surface);color:var(--color-ink);border-radius:8px;padding:5px 8px;cursor:pointer}.lib-actions button:disabled{opacity:.4;cursor:default}
      .lib-actions button.go{background:var(--color-accent);color:var(--color-accent-ink);border-color:transparent}
      .lib-bar{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin:8px 0 14px}.lib-bar select,.lib-bar .chip{font:inherit;font-size:12px}
      .lib-style{border-top:1px solid var(--color-line);margin-top:20px;padding-top:16px}.lib-style textarea,.lib-style input{width:100%;font:inherit;font-size:12.5px;border:1px solid var(--color-line);border-radius:8px;padding:8px;background:var(--color-surface);color:var(--color-ink)}
      .lib-style label{display:grid;gap:3px;font-size:11px;color:var(--color-ink-muted);margin-bottom:8px}.lib-style .cols{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
      .lib-preview{display:grid;grid-template-columns:260px 1fr;gap:14px;align-items:start;margin-top:10px}.lib-preview img{width:100%;border-radius:12px;border:1px solid var(--color-line)}.lib-preview pre{white-space:pre-wrap;font-size:11.5px;color:var(--color-ink-muted);margin:0}
      .lib-provider{font-size:11px;color:var(--color-ink-muted)}
    </style>
    <div class="lib-head"><h1>Illustration Library</h1><span class="lib-provider">provider <b>${esc(status?.provider || '—')}</b> · model ${esc(status?.model || '—')} · QA ${esc(status?.qa || '—')} · total cost ¢${cost.toFixed(1)}</span></div>
    <div class="lib-counts">${['queued', 'generating', 'pending_review', 'approved', 'rejected', 'failed'].map(s => `<span class="lib-count"><b>${counts[s] || 0}</b> ${s.replace('_', ' ')}</span>`).join('')}</div>
    <div class="lib-bar">
      <button class="btn-sm" id="lib-gen">Generate missing</button><button class="btn-sm ghost" id="lib-run">Run worker (one pass)</button><button class="btn-sm ghost" id="lib-all">Run until queue is empty</button>
      <span style="flex:1"></span>
      <select id="lib-f-status"><option value="all">all statuses</option>${['queued', 'generating', 'pending_review', 'approved', 'rejected', 'failed'].map(s => `<option${filter.status === s ? ' selected' : ''}>${s}</option>`).join('')}</select>
      <select id="lib-f-family"><option value="all">all families</option>${fams.map(f => `<option${filter.family === f ? ' selected' : ''}>${f}</option>`).join('')}</select>
    </div>
    <p class="hint">${status?.provider === 'mock' ? '<b>Mock provider.</b> These are procedural emblems proving the pipeline (claim → generate → QA → store → review), not final art. Set OPENAI_API_KEY and restart to generate real illustrations; ANTHROPIC_API_KEY turns on the vision QA.' : 'Only <b>approved</b> art reaches cards. Everything else shows the family placeholder.'}</p>
    <div class="lib-grid">${shown.map(r => `<div class="lib-card" data-family="${esc(r.family)}">
      <div class="lib-thumb">${r.svg || r.png ? `<img src="${esc(urlFor(r.svg || r.png))}" alt="${esc(r.name)} ${esc(r.stage)}" loading="lazy">` : `<span class="ph">${esc(r.name[0])}</span>`}</div>
      <div><div class="lib-name">${esc(r.name)} <span class="lib-meta">· ${esc(r.stage)} · ${esc(r.variant)} · v${r.style_version}</span></div>${pill(r.status)}</div>
      <div class="lib-meta">${esc(r.provider || '—')}${r.model ? ' · ' + esc(r.model) : ''} · attempts ${r.attempts} · ¢${Number(r.cost_cents || 0).toFixed(1)}</div>
      ${r.qa_notes || r.last_error ? `<div class="lib-note" title="${esc(r.qa_notes || r.last_error)}">${esc(r.qa_notes || r.last_error)}</div>` : ''}
      <div class="lib-actions"><button class="go" data-rev="approve" data-id="${r.id}" ${r.status === 'pending_review' || r.status === 'rejected' ? '' : 'disabled'}>Approve</button><button data-rev="reject" data-id="${r.id}" ${r.status === 'pending_review' || r.status === 'approved' ? '' : 'disabled'}>Reject</button><button data-rev="regenerate" data-id="${r.id}" ${r.status === 'queued' || r.status === 'generating' ? 'disabled' : ''}>Regenerate</button></div>
    </div>`).join('')}</div>
    <section class="lib-style"><h2 style="font-size:18px;margin:0 0 4px">Style template</h2><p class="hint">Every illustration is generated from this template plus the animal's name, features and stage cues. Saving creates a new version; existing art is never overwritten.</p>
      ${styleEditor()}</section>`;

    host.querySelector('#lib-gen').onclick = async () => { await j('POST', '/enqueue-missing'); await j('POST', '/run', { all: true }); await refresh(host, mode); };
    host.querySelector('#lib-run').onclick = async () => { await j('POST', '/run', { batch: 3 }); await refresh(host, mode); };
    host.querySelector('#lib-all').onclick = async () => { await j('POST', '/run', { all: true }); await refresh(host, mode); };
    host.querySelector('#lib-f-status').onchange = e => { filter.status = e.target.value; render(host, mode); };
    host.querySelector('#lib-f-family').onchange = e => { filter.family = e.target.value; render(host, mode); };
    host.querySelectorAll('[data-rev]').forEach(b => b.onclick = async () => { await j('POST', '/review', { id: b.dataset.id, decision: b.dataset.rev }); await refresh(host, mode); });
    wireStyle(host, mode);
  }

  function styleEditor() {
    const t = draft || styleRows[0] || {}; const cues = t.stage_cues || {};
    return `<label>Name<input id="st-name" value="${esc(t.name || '')}"></label>
      <label>Template (placeholders: {animal_name} {stage_cues} {features})<textarea id="st-template" rows="5">${esc(t.template || '')}</textarea></label>
      <div class="cols"><label>Baby cues<textarea id="st-baby" rows="3">${esc(cues.baby || '')}</textarea></label><label>Young cues<textarea id="st-young" rows="3">${esc(cues.young || '')}</textarea></label><label>Adult cues<textarea id="st-adult" rows="3">${esc(cues.adult || '')}</textarea></label></div>
      <label>Avoid (negative)<textarea id="st-negative" rows="2">${esc(t.negative || '')}</textarea></label>
      <div class="lib-bar"><select id="st-slug">${['cheetah', 'elephant', 'rabbit', 'star-tortoise', 'bengal-tiger'].map(s => `<option>${s}</option>`).join('')}</select><select id="st-stage"><option>adult</option><option>baby</option><option>young</option></select>
        <button class="btn-sm ghost" id="st-preview">Preview on one animal</button><button class="btn-sm" id="st-save">Save as new version (now v${(styleRows[0]?.version || 0) + 1})</button><span class="hint" style="margin:0">current v${styleRows[0]?.version || '—'}</span></div>
      <div id="st-out" class="lib-preview"></div>`;
  }
  function readDraft(host) { const g = id => host.querySelector('#' + id).value; return { name: g('st-name'), template: g('st-template'), stage_cues: { baby: g('st-baby'), young: g('st-young'), adult: g('st-adult') }, negative: g('st-negative'), qa_criteria: styleRows[0]?.qa_criteria || [], retry_adjustments: styleRows[0]?.retry_adjustments || [] }; }
  function wireStyle(host, mode) {
    host.querySelector('#st-preview').onclick = async () => { draft = readDraft(host); const out = host.querySelector('#st-out'); out.innerHTML = '<span class="hint">Generating preview…</span>';
      const r = await j('POST', '/preview', { ...draft, slug: host.querySelector('#st-slug').value, stage: host.querySelector('#st-stage').value });
      const src = r.svg ? 'data:image/svg+xml;utf8,' + encodeURIComponent(r.svg) : r.png ? 'data:image/png;base64,' + r.png : null;
      out.innerHTML = `${src ? `<img src="${src}" alt="preview">` : '<div></div>'}<div><div class="hint">Composed prompt (${esc(r.provider)}):</div><pre>${esc(r.prompt)}</pre></div>`; };
    host.querySelector('#st-save').onclick = async () => { draft = readDraft(host); const r = await j('POST', '/style', draft); draft = null; await refresh(host, mode); host.querySelector('#st-out').innerHTML = `<div></div><div class="hint">Style version bumped to <b>v${r.version}</b>. Existing art untouched; new generations use the new version.</div>`; };
  }
  async function refresh(host, mode) { await load(); render(host, mode); }

  window.Library = { load, render: async (host, mode) => { await load(); render(host, mode); }, artFor, urlFor, rows: () => rows };
})();
