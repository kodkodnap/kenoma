#!/usr/bin/env node
// Gate de skills. Valida que el router (`.agents/skills/manifest.json`), la instalación
// global (`~/.agents/skills`, donde las busca la herramienta `skill`), `skills-lock.json`
// y las tablas de los AGENTS.md sigan alineados. Sale con 1 si algo diverge.

import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, sep } from 'node:path';

const ROOT = process.cwd();
const MANIFEST = '.agents/skills/manifest.json';
const SKILLS_DIR = '.agents/skills';
const GLOBAL_SKILLS = join(homedir(), '.agents', 'skills');
const LOCK = 'skills-lock.json';
const IGNORED_DIRS = new Set(['node_modules', '.git', 'dist', '.godot', '.freebuff', '.agents']);
const IGNORED_FILES = new Set(['.DS_Store', 'Thumbs.db']);

const failures = [];
const check = (name, ok, detail = '') => {
  if (ok) console.log(`  ok   ${name}`);
  else {
    failures.push(`${name} ${detail}`.trim());
    console.log(`  FAIL ${name} ${detail}`);
  }
};

const readJson = (file) => JSON.parse(readFileSync(join(ROOT, file), 'utf8'));

const walk = (dir = '.') => {
  const out = [];
  for (const entry of readdirSync(join(ROOT, dir), { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (IGNORED_DIRS.has(entry.name)) continue;
      out.push(...walk(dir === '.' ? entry.name : `${dir}/${entry.name}`));
    } else if (!IGNORED_FILES.has(entry.name)) {
      out.push((dir === '.' ? entry.name : `${dir}/${entry.name}`).split(sep).join('/'));
    }
  }
  return out;
};

/** Glob mínimo: `**`, `*` y `?`; todo lo demás es literal. */
const globToRegExp = (glob) => {
  let out = '';
  for (let i = 0; i < glob.length; i += 1) {
    const char = glob[i];
    if (char === '*') {
      if (glob[i + 1] === '*') {
        i += 1;
        if (glob[i + 1] === '/') {
          i += 1;
          out += '(?:[^/]+/)*';
        } else out += '.*';
      } else out += '[^/]*';
    } else if (char === '?') out += '[^/]';
    else if ('\\^$.|+()[]{}'.includes(char)) out += `\\${char}`;
    else out += char;
  }
  return new RegExp(`^${out}$`);
};

const skillName = (file) => {
  if (!existsSync(file)) return null;
  const text = readFileSync(file, 'utf8').replace(/^\uFEFF/, '');
  const front = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!front) return null;
  const line = front[1].split(/\r?\n/).find((l) => /^name\s*:/.test(l));
  return line ? line.replace(/^name\s*:\s*/, '').trim().replace(/^["']|["']$/g, '') : null;
};

console.log('skills:check');

const manifest = readJson(MANIFEST);
const lock = existsSync(join(ROOT, LOCK)) ? readJson(LOCK) : null;
const files = walk();
const docs = new Map();

check('manifiesto legible', Array.isArray(manifest.skills) && manifest.skills.length > 0);
check(`${LOCK} presente`, Boolean(lock), `falta ${LOCK}`);
check(`instalación global (${GLOBAL_SKILLS})`, existsSync(GLOBAL_SKILLS), 'falta ~/.agents/skills');

for (const doc of manifest.protocol.docs) {
  const path = join(ROOT, doc);
  check(`${doc} existe`, existsSync(path));
  if (!existsSync(path)) continue;
  const text = readFileSync(path, 'utf8');
  docs.set(doc, text);
  check(`${doc} tiene "${manifest.protocol.heading}"`, text.includes(manifest.protocol.heading));
}

const repoSkillDirs = existsSync(join(ROOT, SKILLS_DIR))
  ? readdirSync(join(ROOT, SKILLS_DIR), { withFileTypes: true })
      .filter((e) => e.isDirectory())
      .map((e) => e.name)
  : [];
check(
  'sin copias locales duplicadas',
  repoSkillDirs.length === 0,
  `elimina ${repoSkillDirs.join(', ')}; las skills se instalan con \`npm run skills:sync\``,
);

const seen = new Set();
for (const skill of manifest.skills) {
  const where = `${skill.name} (${skill.scope})`;
  check(`${where} declarada una sola vez`, !seen.has(skill.name), 'duplicada en el manifiesto');
  seen.add(skill.name);

  const doc = docs.get(skill.docs);
  check(`${where} documentada en ${skill.docs}`, Boolean(doc) && doc.includes(skill.name));
  check(`${where} tiene criterio de uso`, typeof skill.when === 'string' && skill.when.trim().length > 0);

  if (skill.scope === 'project') {
    const file = join(GLOBAL_SKILLS, skill.name, 'SKILL.md');
    check(`${where} instalada globalmente`, existsSync(file), `falta ${file}`);
    check(`${where} frontmatter`, skillName(file) === skill.name, `name != ${skill.name}`);
    check(`${where} restaurable`, Boolean(lock?.skills?.[skill.name]), `ausente en ${LOCK}`);
  } else {
    check(`${where} no versionada en el repo`, !(lock?.skills ?? {})[skill.name]);
  }

  if (!Array.isArray(skill.triggers) || skill.triggers.length === 0) {
    console.log(`  --   ${where} sin globs (se activa por síntoma, no por ruta)`);
    continue;
  }
  for (const trigger of skill.triggers) {
    const re = globToRegExp(trigger);
    const hits = files.filter((f) => re.test(f)).length;
    check(`${where} glob ${trigger}`, hits > 0, 'no coincide con ningún archivo');
  }
}

console.log(
  `  --   ${manifest.skills.filter((s) => s.scope === 'project').length} skills de proyecto + ` +
    `${manifest.skills.filter((s) => s.scope === 'builtin').length} del entorno`,
);
console.log(`  --   router: ${[...docs.keys()].join(', ') || 'sin docs'}`);

if (failures.length > 0) {
  console.error(`\nskills:check FALLÓ (${failures.length} problema/s):`);
  for (const failure of failures) console.error(`  - ${failure}`);
  console.error(
    '\nArregla el manifiesto, ejecuta `npm run skills:sync` o repón la tabla en AGENTS.md.',
  );
  process.exit(1);
}

console.log('skills:check ok — router, skills, lock y tablas alineados.');
