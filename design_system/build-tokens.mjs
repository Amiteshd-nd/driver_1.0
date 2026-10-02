#!/usr/bin/env node
// Flying Cobra design system — token build.
// Reads tokens.json and writes:
//   tokens.css   custom properties for the web (workbench, marketing, verify page)
//   tokens.dart  constants for the Flutter app (drop-in for app/lib/core/theme/tokens.dart values)
// Run:  node design_system/build-tokens.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const T = JSON.parse(readFileSync(join(here, 'tokens.json'), 'utf8'));
const banner = `/* GENERATED from design_system/tokens.json v${T.version} — do not edit by hand. Run: node design_system/build-tokens.mjs */`;

// ---------- CSS ----------
const css = [];
css.push(banner, '');
const colorVars = (mode) => Object.entries(T.color[mode]).map(([k, v]) => `  --color-${kebab(k)}: ${v};`).join('\n');
css.push(':root {');
css.push('  color-scheme: light dark;');
css.push(colorVars('light'));
for (const [name, f] of Object.entries(T.family)) css.push(`  --fam-${name}-bg: ${f.bg}; --fam-${name}-fg: ${f.fg}; --fam-${name}-accent: ${f.accent};`);
for (const [name, r] of Object.entries(T.rarity)) css.push(`  --rarity-${name}-border: ${r.borderWidth}px; --rarity-${name}-reveal: ${r.revealMs}ms; --rarity-${name}-particles: ${r.particles};`);
for (const [name, t] of Object.entries(T.tier)) css.push(`  --tier-${name}-art: ${t.artScale}; --tier-${name}-initial: ${t.initialScale}cqw;`);
for (const [name, f] of Object.entries(T.finish)) css.push(`  --finish-${name}-blur: ${f.glowBlur}px; --finish-${name}-alpha: ${f.glowAlpha};`);
css.push(`  --font-display: '${T.typography.display.family}', ${T.typography.display.fallback};`);
css.push(`  --font-text: '${T.typography.text.family}', ${T.typography.text.fallback};`);
for (const [name, s] of Object.entries(T.typography.scale)) {
  css.push(`  --type-${kebab(name)}-size: ${s.size}px; --type-${kebab(name)}-line: ${s.line}px; --type-${kebab(name)}-weight: ${s.weight};${s.tracking ? ` --type-${kebab(name)}-tracking: ${s.tracking}em;` : ''}`);
}
for (const [k, v] of Object.entries(T.space)) css.push(`  --space-${k}: ${v}px;`);
for (const [k, v] of Object.entries(T.radius)) css.push(`  --radius-${k}: ${v}px;`);
for (const [k, v] of Object.entries(T.elevation)) css.push(`  --elevation-${kebab(k)}: ${v};`);
for (const [k, v] of Object.entries(T.motion.duration)) css.push(`  --duration-${kebab(k)}: ${v}ms;`);
for (const [k, v] of Object.entries(T.motion.easing)) css.push(`  --easing-${k}: ${v};`);
css.push(`  --card-aspect: ${T.layout.cardAspect}; --card-width: ${T.layout.cardWidthDefault}px; --card-width-tile: ${T.layout.cardWidthTile}px; --touch-min: ${T.layout.touchTargetMin}px;`);
css.push('}', '');
css.push(`/* dark: follows the system unless [data-theme] pins it */`);
css.push(`:root:not([data-theme='light']) { @media (prefers-color-scheme: dark) {\n${colorVars('dark')}\n  --elevation-card: ${T.elevation.cardDark};\n} }`);
css.push(`:root[data-theme='dark'], [data-mode='dark'] {\n${colorVars('dark')}\n  --elevation-card: ${T.elevation.cardDark};\n}`);
css.push(`:root[data-theme='light'], [data-mode='light'] {\n${colorVars('light')}\n  --elevation-card: ${T.elevation.card};\n}`);
css.push('', '/* family scope: put data-family on any ancestor and components pick it up */');
for (const name of Object.keys(T.family)) css.push(`[data-family='${name}'] { --fam-bg: var(--fam-${name}-bg); --fam-fg: var(--fam-${name}-fg); --fam-accent: var(--fam-${name}-accent); }`);
const reduced = Object.keys(T.motion.duration).map(k => `--duration-${kebab(k)}: 1ms;`).join(' ');
css.push('', `/* reduced motion: system preference, or the workbench toggle via [data-reduced] */`);
css.push(`@media (prefers-reduced-motion: reduce) { :root { ${reduced} } }`);
css.push(`[data-reduced='true'] { ${reduced} }`);
writeFileSync(join(here, 'tokens.css'), css.join('\n') + '\n');

// ---------- Dart ----------
const d = [];
d.push(`// GENERATED from design_system/tokens.json v${T.version} — do not edit by hand.`);
d.push(`// Run: node design_system/build-tokens.mjs   then copy into app/lib/core/theme/generated_tokens.dart`);
d.push(`// ignore_for_file: constant_identifier_names`, `import 'package:flutter/material.dart';`, '');
d.push('/// Chrome colours per mode (DESIGN.md §3.1).');
d.push('class TokenColors {', '  TokenColors._();');
for (const mode of ['light', 'dark']) for (const [k, v] of Object.entries(T.color[mode])) if (v.startsWith('#')) d.push(`  static const ${mode}${cap(k)} = Color(0xFF${v.slice(1)});`);
d.push('}', '');
d.push('/// Family palettes (DESIGN.md §3.2). Keyed by family slug.');
d.push('class TokenFamily {', '  const TokenFamily(this.bg, this.fg, this.accent, this.label);', '  final Color bg, fg, accent; final String label;');
d.push('  static const Map<String, TokenFamily> all = {');
for (const [name, f] of Object.entries(T.family)) d.push(`    '${name}': TokenFamily(Color(0xFF${f.bg.slice(1)}), Color(0xFF${f.fg.slice(1)}), Color(0xFF${f.accent.slice(1)}), '${f.label}'),`);
d.push('  };', '}', '');
d.push('/// Rarity expression (DESIGN.md §3.3). New rarity = new entry here, no new widget.');
d.push('class TokenRarity {', '  const TokenRarity(this.borderWidth, this.foil, this.particles, this.revealMs, this.drawWeight);');
d.push('  final double borderWidth; final bool foil; final int particles, revealMs, drawWeight;');
d.push('  static const Map<String, TokenRarity> all = {');
for (const [name, r] of Object.entries(T.rarity)) d.push(`    '${name}': TokenRarity(${r.borderWidth.toFixed(1)}, ${r.foil}, ${r.particles}, ${r.revealMs}, ${r.drawWeight}),`);
d.push('  };', '}', '');
d.push('class TokenTier {', '  const TokenTier(this.artScale, this.minKm);', '  final double artScale, minKm;', '  static const Map<String, TokenTier> all = {');
for (const [name, t] of Object.entries(T.tier)) d.push(`    '${name}': TokenTier(${t.artScale}, ${t.minKm}),`);
d.push('  };', '}', '');
d.push('class TokenFinish {', '  const TokenFinish(this.glowBlur, this.glowAlpha, this.breathe, this.minRunDays);', '  final double glowBlur, glowAlpha; final bool breathe; final int minRunDays;', '  static const Map<String, TokenFinish> all = {');
for (const [name, f] of Object.entries(T.finish)) d.push(`    '${name}': TokenFinish(${f.glowBlur}, ${f.glowAlpha}, ${f.breathe}, ${f.minRunDays}),`);
d.push('  };', '}', '');
d.push('class TokenSpace {', '  TokenSpace._();');
for (const [k, v] of Object.entries(T.space)) d.push(`  static const double ${k} = ${v};`);
d.push('}', '', 'class TokenRadius {', '  TokenRadius._();');
for (const [k, v] of Object.entries(T.radius)) d.push(`  static const double ${k} = ${v};`);
d.push('}', '', '/// Durations in milliseconds; wrap with Duration(milliseconds: x).');
d.push('class TokenMotion {', '  TokenMotion._();');
for (const [k, v] of Object.entries(T.motion.duration)) d.push(`  static const int ${k} = ${v};`);
d.push('  static const Curve standard = Cubic(0.4, 0, 0.2, 1);', '  static const Curve decelerate = Cubic(0, 0, 0.2, 1);', '  static const Curve accelerate = Cubic(0.4, 0, 1, 1);', '  static const Curve emphasised = Cubic(0.22, 0.9, 0.3, 1);', '  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1);');
d.push('}', '');
writeFileSync(join(here, 'tokens.dart'), d.join('\n') + '\n');

console.log(`tokens.css and tokens.dart written from tokens.json v${T.version}: ${Object.keys(T.family).length} families, ${Object.keys(T.rarity).length} rarities, ${Object.keys(T.tier).length} tiers, ${Object.keys(T.finish).length} finishes.`);

function kebab(s) { return s.replace(/([a-z0-9])([A-Z])/g, '$1-$2').toLowerCase(); }
function cap(s) { return s.charAt(0).toUpperCase() + s.slice(1); }
