// Illustration pipeline — prompt composition from the versioned style template.
// Pure. Shared by the Deno Edge Function and the local Node runner.

/** Distinctive-feature line from the animal's encyclopedia entry (facts, habitat, superpower). */
export function featuresFor(animal) {
  const enc = animal.encyclopedia || {};
  const bits = [];
  if (enc.superpower) bits.push(String(enc.superpower));
  if (enc.habitat) bits.push(`found in ${enc.habitat}`);
  if (Array.isArray(enc.facts) && enc.facts[0]) bits.push(String(enc.facts[0]));
  if (enc.size) bits.push(String(enc.size));
  const line = bits.join('; ').replace(/\s+/g, ' ').trim();
  return line ? `Distinctive features: ${line}` : `Distinctive features: the true colours, markings and silhouette of a ${animal.name}`;
}

/** Fill the template. `template` is a style_templates row (or illustration-style.json). */
export function composePrompt(template, animal, stage, attempt = 1) {
  const cues = (template.stage_cues || template.stageCues || {})[stage] || '';
  let prompt = template.template
    .replaceAll('{animal_name}', animal.name)
    .replaceAll('{stage_cues}', cues)
    .replaceAll('{features}', featuresFor(animal));
  // Retries append one adjustment each, in order (PRD §5 step 6).
  const adj = template.retry_adjustments || template.retryAdjustments || [];
  for (let i = 0; i < Math.min(attempt - 1, adj.length); i++) prompt += ' ' + adj[i];
  return { prompt, negative: template.negative || '' };
}

export function qaCriteria(template, animal, stage) {
  return (template.qa_criteria || template.qaCriteria || []).map(c => String(c).replaceAll('{animal_name}', animal.name).replaceAll('{stage}', stage));
}
