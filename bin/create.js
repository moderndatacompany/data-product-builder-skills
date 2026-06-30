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

async function createPrompt() {
  const isTTY = process.stdin.isTTY;
  const lines  = [];
  let   lineIdx = 0;

  if (!isTTY) {
    // piped input — read all lines up front
    await new Promise(resolve => {
      const rl = readline.createInterface({ input: process.stdin });
      rl.on('line', l => lines.push(l.trim()));
      rl.on('close', resolve);
    });
  }

  const rl = isTTY
    ? readline.createInterface({ input: process.stdin, output: process.stdout })
    : null;

  async function ask(question) {
    if (!isTTY) {
      process.stdout.write(question);
      const ans = lineIdx < lines.length ? lines[lineIdx++] : '';
      process.stdout.write(ans + '\n');
      return ans;
    }
    return new Promise(resolve => rl.question(question, ans => resolve(ans.trim())));
  }

  function close() { if (rl) rl.close(); }
  return { ask, close };
}

const IDE_OPTIONS = [
  { label: 'Cursor',     folder: '.cursor' },
  { label: 'Claude Code',folder: '.claude'  },
  { label: 'Codex',      folder: '.codex'   },
  { label: 'All three',  folder: null       },
];

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

  const { ask, close } = await createPrompt();

  log('');
  log(`${BOLD}dataproduct-builder-skills${RESET} — scaffolding skills + docs`);
  log('');

  // ── Step 1: IDE selection ─────────────────────────────────────────────────
  const IDE_LIST = IDE_OPTIONS.filter(o => o.folder); // exclude "All three"

  log(`${BOLD}Which IDE(s) are you using?${RESET} ${DIM}(comma-separated for multiple, e.g. 1,2)${RESET}`);
  log('');
  IDE_LIST.forEach((ide, i) => log(`  ${DIM}${i + 1}${RESET}  ${ide.label}`));
  log(`  ${DIM}${IDE_LIST.length + 1}${RESET}  All`);
  log('');

  const ideAnswer = await ask(`Enter number(s) (1–${IDE_LIST.length + 1}): `);

  const ideNums = ideAnswer.split(',').map(s => parseInt(s.trim(), 10));
  const invalidIde = ideNums.find(n => isNaN(n) || n < 1 || n > IDE_LIST.length + 1);
  if (invalidIde !== undefined) {
    err(`Invalid selection "${ideAnswer}". Use numbers 1–${IDE_LIST.length + 1}, comma-separated.`);
    close(); process.exit(1);
  }

  const ideFolders = ideNums.includes(IDE_LIST.length + 1)
    ? IDE_LIST.map(o => o.folder)
    : ideNums.map(n => IDE_LIST[n - 1].folder);

  const ideLabels = ideFolders.map(f => IDE_LIST.find(o => o.folder === f).label).join(', ');
  log('');
  info(`IDE(s): ${BOLD}${ideLabels}${RESET}`);
  log('');

  // ── Step 2: Engine selection ──────────────────────────────────────────────
  log(`${BOLD}Which engine would you like to install examples for?${RESET}`);
  log('');
  log(`  ${DIM}0${RESET}  All engines`);
  validEngines.forEach((e, i) => log(`  ${DIM}${i + 1}${RESET}  ${e}`));
  log('');

  const engAnswer = await ask(`Enter number (0–${validEngines.length}): `);
  const engIdx    = parseInt(engAnswer, 10);

  close();

  if (isNaN(engIdx) || engIdx < 0 || engIdx > validEngines.length) {
    err(`Invalid selection "${engAnswer}". Please enter a number between 0 and ${validEngines.length}.`);
    log(''); process.exit(1);
  }

  const engine = engIdx === 0 ? null : validEngines[engIdx - 1];
  log('');
  info(`Engine: ${BOLD}${engine || 'all'}${RESET}`);
  log('');

  // ── Step 3: Skills ────────────────────────────────────────────────────────
  const skillsSrc = path.join(packageDir, 'skills');

  if (!fs.existsSync(skillsSrc)) {
    warn('skills/ directory not found in package — skipping');
  } else {
    const skills = fs.readdirSync(skillsSrc, { withFileTypes: true })
      .filter(e => e.isDirectory())
      .map(e => e.name);

    for (const ideFolder of ideFolders) {
      for (const skill of skills) {
        const src    = path.join(skillsSrc, skill);
        const dest   = path.join(targetDir, ideFolder, 'skills', skill);
        const existed = fs.existsSync(dest);
        copyDir(src, dest);
        ok(`${existed ? 'updated' : 'created'}  ${ideFolder}/skills/${skill}/`);
      }
    }
  }

  // ── Step 4: docs (non-examples) ───────────────────────────────────────────
  const docsSrc  = path.join(packageDir, 'docs');
  const docsDest = path.join(targetDir, 'docs');

  if (!fs.existsSync(docsSrc)) {
    warn('docs/ directory not found in package — skipping');
  } else {
    for (const dir of fs.readdirSync(docsSrc, { withFileTypes: true })
        .filter(e => e.isDirectory() && e.name !== 'vulcan-examples')
        .map(e => e.name)) {
      const src     = path.join(docsSrc, dir);
      const dest    = path.join(docsDest, dir);
      const existed = fs.existsSync(dest);
      copyDir(src, dest);
      const n = countFiles(src);
      ok(`${existed ? 'updated' : 'created'}  docs/${dir}/  (${n} file${n === 1 ? '' : 's'})`);
    }
    // loose files at docs/ root (e.g. .whl)
    fs.mkdirSync(docsDest, { recursive: true });
    for (const entry of fs.readdirSync(docsSrc, { withFileTypes: true }).filter(e => !e.isDirectory())) {
      const src     = path.join(docsSrc, entry.name);
      const dest    = path.join(docsDest, entry.name);
      const existed = fs.existsSync(dest);
      fs.copyFileSync(src, dest);
      ok(`${existed ? 'updated' : 'created'}  docs/${entry.name}`);
    }
  }

  // ── Step 5: docs/vulcan-examples (filtered or all) ────────────────────────
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
  for (const ideFolder of ideFolders) {
    info(`${ideFolder}/skills/design-data-product/`);
    info(`${ideFolder}/skills/build-data-product-workflow/`);
  }
  info(`docs/vulcan-examples/${engine || '{all engines}'}/`);
  info(`docs/vulcan-*.whl  — install: pip install "docs/vulcan-*.whl[\${ENGINE}]"`);
  log('');
  log('Ask the agent to use the skills — e.g.:');
  log(`  ${CYAN}"design a data product for daily revenue by customer segment"${RESET}`);
  log('');
}

main().catch(e => { console.error(e); process.exit(1); });
