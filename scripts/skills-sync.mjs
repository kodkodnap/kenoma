#!/usr/bin/env node
// Reinstala el set de skills versionado en `skills-lock.json` en ~/.agents/skills,
// que es donde el cargador de la herramienta `skill` las busca. Idempotente:
// omite las que ya están instaladas salvo que se pase --force.

import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const LOCK = 'skills-lock.json';
const GLOBAL_SKILLS = join(homedir(), '.agents', 'skills');
const force = process.argv.includes('--force');

if (!existsSync(LOCK)) {
  console.error(`skills:sync — falta ${LOCK}. Instala una skill con \`npx skills add\` para generarlo.`);
  process.exit(1);
}

const lock = JSON.parse(readFileSync(LOCK, 'utf8'));
const names = Object.keys(lock.skills ?? {});
if (names.length === 0) {
  console.error('skills:sync — el lock no declara skills.');
  process.exit(1);
}

console.log(`skills:sync → ${GLOBAL_SKILLS}`);
let failed = 0;

for (const name of names) {
  const meta = lock.skills[name];
  if (!force && existsSync(join(GLOBAL_SKILLS, name, 'SKILL.md'))) {
    console.log(`  ok   ${name} (ya instalada)`);
    continue;
  }
  if (!meta?.source) {
    console.log(`  FAIL ${name} sin \`source\` en ${LOCK}`);
    failed += 1;
    continue;
  }
  console.log(`  ..   ${name} ← ${meta.source}`);
  const result = spawnSync(
    'npx',
    ['--yes', 'skills', 'add', meta.source, '--skill', name, '-g', '-y', '--copy', '--agent', 'universal'],
    { stdio: 'inherit', shell: true },
  );
  if (result.status !== 0) {
    console.log(`  FAIL ${name} (código ${result.status ?? '?'})`);
    failed += 1;
  } else console.log(`  ok   ${name} instalada`);
}

if (failed > 0) {
  console.error(`\nskills:sync FALLÓ en ${failed} skill/s.`);
  process.exit(1);
}

console.log(`\nskills:sync ok — ${names.length} skills disponibles.`);
console.log('Ejecuta `npm run skills:check` para validar router, lock y tablas.');
