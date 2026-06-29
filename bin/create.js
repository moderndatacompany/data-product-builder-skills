#!/usr/bin/env node

const fs       = require('fs');
const path     = require('path');
const readline = require('readline');

const RESET  = '\x1b[0m';
const GREEN  = '\x1b[32m';
const CYAN   = '\x1b[36m';
const YELLOW = '\x1b[33m';
const BOLD   = '\x1b[1m';
const DIM    = '\x1b[2m';

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

function prompt(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise(resolve => rl.question(question, ans => { rl.close(); resolve(ans.trim()); }));
}

async function main() {
  const packageDir  = path.join(__dirname, '..');
  const targetDir   = process.cwd();
  const examplesDir = path.join(packageDir, 'docs', 'vulcan-examples');

  const validEngines = fs.existsSync(examplesDir)
    ? fs.readdirSync(examplesDir, { withFileTypes: true })
        .filter(e => e.isDirectory() && e.name !== 'extra')
        .map(e => e.name)
        .sort()
    : [];

  log('');
  log(`${BOLD}dataproduct-builder-skills${RESET} — scaffolding Cursor skills + docs`);
  log('');

  // ── Engine selection ──────────────────────────────────────────────────────
  let engine = process.argv[2] ? process.argv[2].toLowerCase() : null;

  if (engine && !validEngines.includes(engine)) {
    err(`Unknown engine: "${engine}"`);
    log('');
    log(`  Available engines: ${validEngines.join(', ')}`);
    log('');
    process.exit(1);
  }

  if (!engine) {
    log(`${BOLD}Which engine would you like to install examples for?${RESET}`);
    log('');
    log(`  ${DIM}0${RESET}  All engines`);
    validEngines.forEach((e, i) => log(`  ${DIM}${i + 1}${RESET}  ${e}`));
    log('');

    const answer = await prompt(`Enter number (0–${validEngines.length}): `);
    const idx = parseInt(answer, 10);

    if (isNaN(idx) || idx < 0 || idx > validEngines.length) {
      err(`Invalid selection "${answer}". Please enter a number between 0 and ${validEngines.length}.`);
      log('');
      process.exit(1);
    }

    engine = idx === 0 ? null : validEngines[idx - 1];
    log('');
  }

  if (engine) info(`engine: ${BOLD}${engine}${RESET}`);
  log('');

  // ── .cursor/skills ────────────────────────────────────────────────────────
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

  // ── docs (non-examples) ───────────────────────────────────────────────────
  const docsSrc  = path.join(packageDir, 'docs');
  const docsDest = path.join(targetDir, 'docs');

  if (!fs.existsSync(docsSrc)) {
    warn('docs/ directory not found in package — skipping');
  } else {
    for (const dir of fs.readdirSync(docsSrc, { withFileTypes: true }).filter(e => e.isDirectory() && e.name !== 'vulcan-examples').map(e => e.name)) {
      const src     = path.join(docsSrc, dir);
      const dest    = path.join(docsDest, dir);
      const existed = fs.existsSync(dest);
      copyDir(src, dest);
      const n = countFiles(src);
      ok(`${existed ? 'updated' : 'created'}  docs/${dir}/  (${n} file${n === 1 ? '' : 's'})`);
    }
  }

  // ── docs/vulcan-examples (filtered or all) ────────────────────────────────
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

  // ── Done ──────────────────────────────────────────────────────────────────
  log('');
  log(`${GREEN}${BOLD}Done!${RESET}  Your project now has:`);
  log('');
  info('.cursor/skills/design-data-product/         — design a Vulcan data product from scratch');
  info('.cursor/skills/build-data-product-workflow/ — build & deploy from a design spec');
  info(`docs/vulcan-examples/${engine || '{all engines}'}/`);
  log('');
  log('Open Cursor and ask the agent to use the skills — e.g.:');
  log(`  ${CYAN}"design a data product for daily revenue by customer segment"${RESET}`);
  log('');
}

main().catch(e => { console.error(e); process.exit(1); });
