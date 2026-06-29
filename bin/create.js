#!/usr/bin/env node

const fs   = require('fs');
const path = require('path');

const RESET  = '\x1b[0m';
const GREEN  = '\x1b[32m';
const CYAN   = '\x1b[36m';
const YELLOW = '\x1b[33m';
const BOLD   = '\x1b[1m';

function log(msg)  { process.stdout.write(msg + '\n'); }
function ok(msg)   { log(`  ${GREEN}✓${RESET}  ${msg}`); }
function info(msg) { log(`  ${CYAN}→${RESET}  ${msg}`); }
function warn(msg) { log(`  ${YELLOW}!${RESET}  ${msg}`); }
function err(msg)  { log(`  \x1b[31m✗${RESET}  ${msg}`); }

function copyDir(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name);
    const d = path.join(dest, entry.name);
    entry.isDirectory() ? copyDir(s, d) : fs.copyFileSync(s, d);
  }
}

function countFiles(dir) {
  let n = 0;
  for (const e of fs.readdirSync(dir, { withFileTypes: true }))
    n += e.isDirectory() ? countFiles(path.join(dir, e.name)) : 1;
  return n;
}

// ── Parse optional engine argument ───────────────────────────────────────────
const engine = process.argv[2] ? process.argv[2].toLowerCase() : null;

const packageDir   = path.join(__dirname, '..');
const targetDir    = process.cwd();
const examplesDir  = path.join(packageDir, 'docs', 'vulcan-examples');
const validEngines = fs.existsSync(examplesDir)
  ? fs.readdirSync(examplesDir, { withFileTypes: true })
      .filter(e => e.isDirectory())
      .map(e => e.name)
  : [];

if (engine && !validEngines.includes(engine)) {
  err(`Unknown engine: "${engine}"`);
  log('');
  log(`  Available engines: ${validEngines.join(', ')}`);
  log('');
  log(`  Usage: npx dataproduct-builder-skills [engine]`);
  log(`  Example: npx dataproduct-builder-skills snowflake`);
  log('');
  process.exit(1);
}

log('');
log(`${BOLD}dataproduct-builder-skills${RESET} — scaffolding Cursor skills + docs`);
if (engine) info(`engine filter: ${BOLD}${engine}${RESET} (only vulcan-examples/${engine} will be installed)`);
log('');

// ── .cursor/skills ───────────────────────────────────────────────────────────
const skillsSrc  = path.join(packageDir, 'skills');
const skillsDest = path.join(targetDir, '.cursor', 'skills');

if (!fs.existsSync(skillsSrc)) {
  warn('skills/ directory not found in package — skipping');
} else {
  for (const skill of fs.readdirSync(skillsSrc, { withFileTypes: true }).filter(e => e.isDirectory()).map(e => e.name)) {
    const src     = path.join(skillsSrc, skill);
    const dest    = path.join(skillsDest, skill);
    const existed = fs.existsSync(dest);
    copyDir(src, dest);
    ok(`${existed ? 'updated' : 'created'}  .cursor/skills/${skill}/`);
  }
}

// ── docs (non-examples) ───────────────────────────────────────────────────────
const docsSrc  = path.join(packageDir, 'docs');
const docsDest = path.join(targetDir, 'docs');

if (!fs.existsSync(docsSrc)) {
  warn('docs/ directory not found in package — skipping');
} else {
  const topDirs = fs.readdirSync(docsSrc, { withFileTypes: true })
    .filter(e => e.isDirectory() && e.name !== 'vulcan-examples')
    .map(e => e.name);

  for (const dir of topDirs) {
    const src     = path.join(docsSrc, dir);
    const dest    = path.join(docsDest, dir);
    const existed = fs.existsSync(dest);
    copyDir(src, dest);
    const n = countFiles(src);
    ok(`${existed ? 'updated' : 'created'}  docs/${dir}/  (${n} file${n === 1 ? '' : 's'})`);
  }
}

// ── docs/vulcan-examples (engine-filtered or all) ─────────────────────────────
if (fs.existsSync(examplesDir)) {
  const enginesToCopy = engine ? [engine] : validEngines;

  for (const eng of enginesToCopy) {
    const src     = path.join(examplesDir, eng);
    const dest    = path.join(docsDest, 'vulcan-examples', eng);
    const existed = fs.existsSync(dest);
    copyDir(src, dest);
    const n = countFiles(src);
    ok(`${existed ? 'updated' : 'created'}  docs/vulcan-examples/${eng}/  (${n} file${n === 1 ? '' : 's'})`);
  }
}

log('');
log(`${GREEN}${BOLD}Done!${RESET}  Your project now has:`);
log('');
info('.cursor/skills/design-data-product/         — design a Vulcan data product from scratch');
info('.cursor/skills/build-data-product-workflow/ — build & deploy from a design spec');
info(`docs/vulcan-examples/${engine || '{all engines}'}/     — Vulcan reference examples`);
log('');
log('Open Cursor and ask the agent to use the skills — e.g.:');
log(`  ${CYAN}"design a data product for daily revenue by customer segment"${RESET}`);
log('');
if (!engine) {
  log(`Tip: install examples for a specific engine only:`);
  log(`  ${CYAN}npx dataproduct-builder-skills snowflake${RESET}`);
  log(`  ${CYAN}npx dataproduct-builder-skills postgres${RESET}`);
  log('');
}
