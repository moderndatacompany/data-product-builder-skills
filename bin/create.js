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

// Mirrors src into dest: copies/overwrites everything from src, and also
// deletes any dest entry that no longer exists in src. Only safe for
// directories fully owned by this tool, so updates don't leave stale
// files/folders behind when the source structure changes between versions.
function syncDir(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  const srcNames = new Set(fs.readdirSync(src));

  for (const entry of fs.readdirSync(dest, { withFileTypes: true })) {
    if (!srcNames.has(entry.name) || entry.name === '.git') {
      fs.rmSync(path.join(dest, entry.name), { recursive: true, force: true });
    }
  }

  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    if (entry.name === '.git') continue; // source dirs may be git submodules — never ship their gitlink
    const s = path.join(src, entry.name);
    const d = path.join(dest, entry.name);
    entry.isDirectory() ? syncDir(s, d) : fs.copyFileSync(s, d);
  }
}

function countFiles(dir) {
  let n = 0;
  for (const e of fs.readdirSync(dir, { withFileTypes: true }))
    n += e.isDirectory() ? countFiles(path.join(dir, e.name)) : 1;
  return n;
}

// Installed folder names differ from this repo's own source folder names —
// this repo keeps `dataos` (it's the raw dataos submodule, sparse-checked out
// to just the vulcan docs subtree), but the docs shipped to a user's project
// are renamed to `vulcan-docs` since that's what they actually contain.
const DEST_NAME_OVERRIDES = { dataos: 'vulcan-docs' };

// `dataos` is sparse-checked-out to only this subpath — install its contents
// directly under dpbs-docs/vulcan-docs/ instead of nesting the full
// documentation/references/resources/vulcan/ path from the submodule.
const SRC_SUBPATH_OVERRIDES = { dataos: ['documentation', 'references', 'resources', 'vulcan'] };

// Mirrors scripts/sync-vulcan-sources.sh's PRUNE_NAMES — a safety net so
// vulcan-examples never ships README/*.md/csv/tsv/lockfile noise into a
// user's project, even if a stray file ever slips into a published tarball.
const EXAMPLES_PRUNE_NAMES = [
  '.gitignore',
  'README.md',
  '*.md',
  '*.csv',
  '*.tsv',
  'config.yaml',
  'domain-resource.yaml',
  'domain_resource.yaml',
  'usage.yaml',
  'package-lock.json',
  'requirements.txt',
  'limitations.yaml',
  'usecases.yaml',
];

function matchesPruneName(fileName, patterns) {
  return patterns.some(pattern =>
    pattern.startsWith('*.')
      ? fileName.endsWith(pattern.slice(1))
      : fileName === pattern
  );
}

// Recursively removes disallowed files from dir, then removes any directory
// left empty as a result.
function cleanDisallowedFiles(dir, patterns) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      cleanDisallowedFiles(p, patterns);
      if (fs.readdirSync(p).length === 0) fs.rmdirSync(p);
    } else if (matchesPruneName(entry.name, patterns)) {
      fs.rmSync(p, { force: true });
    }
  }
}

// Rewrites `dpbs-docs/dataos` references inside copied skill .md files to
// `dpbs-docs/vulcan-docs`, so the skill's instructions match the renamed
// folder that actually exists in the target project.
function rewritePathReferences(dir, from, to) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      rewritePathReferences(p, from, to);
    } else if (entry.name.endsWith('.md')) {
      const content = fs.readFileSync(p, 'utf8');
      if (content.includes(from)) {
        fs.writeFileSync(p, content.split(from).join(to));
      }
    }
  }
}

// Prompts interactively over a TTY, or replays piped/scripted stdin lines
// in order when stdin isn't a TTY (e.g. `echo "1\n2" | npx dataproduct-builder-skills`).
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
  { label: 'Cursor',            folder: '.cursor' },
  { label: 'Claude Code',       folder: '.claude'  },
  { label: 'Codex',             folder: '.codex'   },
  { label: 'VS Code (Copilot)', folder: '.github'  },
  { label: 'All',               folder: null       },
];

async function main() {
  const packageDir  = path.join(__dirname, '..'); // this npm package's own install dir (source of truth)
  const targetDir   = process.cwd();               // the user's project (destination)
  const examplesDir = path.join(packageDir, 'dpbs-docs', 'vulcan-examples');

  const ALLOWED_ENGINES = ['databricks', 'fabric', 'mssql', 'postgres', 'snowflake', 'spark', 'trino'];

  // Only offer engines that actually shipped examples in this package version.
  const validEngines = fs.existsSync(examplesDir)
    ? ALLOWED_ENGINES.filter(e => fs.existsSync(path.join(examplesDir, e)))
    : [];

  // ── CLI arg: optional engine shortcut ────────────────────────────────────
  const cliEngine = process.argv[2] ? process.argv[2].toLowerCase() : null;

  if (cliEngine && !validEngines.includes(cliEngine)) {
    err(`Unknown engine: "${cliEngine}"`);
    log('');
    log(`  Available engines: ${validEngines.join(', ')}`);
    log('');
    process.exit(1);
  }

  const { ask, close } = await createPrompt();

  log('');
  log(`${BOLD}dataproduct-builder-skills${RESET} — scaffolding skills + docs`);
  log('');

  // ── Step 1: IDE selection ─────────────────────────────────────────────────
  const IDE_LIST = IDE_OPTIONS.filter(o => o.folder);

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

  // ── Step 2: Engine selection ────────────────────────────────────────────
  // No interactive prompt — always install all engines' docs unless a specific
  // engine is passed as a CLI arg (e.g. `npx dataproduct-builder-skills snowflake`).
  let engine;
  if (cliEngine) {
    engine = cliEngine;
    info(`Engine: ${BOLD}${engine}${RESET} (from CLI argument)`);
    log('');
  } else {
    engine = null;
    info(`Engine: ${BOLD}all${RESET} (default)`);
    log('');
  }
  /* Previously prompted the user to pick an engine interactively:
  log(`${BOLD}Which engine would you like to install examples for?${RESET}`);
  log('');
  log(`  ${DIM}0${RESET}  All engines`);
  validEngines.forEach((e, i) => log(`  ${DIM}${i + 1}${RESET}  ${e}`));
  log('');

  const engAnswer = await ask(`Enter number (0–${validEngines.length}): `);
  const engIdx    = parseInt(engAnswer, 10);

  if (isNaN(engIdx) || engIdx < 0 || engIdx > validEngines.length) {
    err(`Invalid selection "${engAnswer}". Please enter a number between 0 and ${validEngines.length}.`);
    close(); log(''); process.exit(1);
  }

  engine = engIdx === 0 ? null : validEngines[engIdx - 1];
  log('');
  info(`Engine: ${BOLD}${engine || 'all'}${RESET}`);
  log('');
  */

  close();

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
        syncDir(src, dest);
        rewritePathReferences(dest, 'dpbs-docs/dataos', 'dpbs-docs/vulcan-docs');
        ok(`${existed ? 'updated' : 'created'}  ${ideFolder}/skills/${skill}/`);
      }
    }
  }

  // ── Step 4: dpbs-docs (non-examples) ───────────────────────────────────────────
  const docsSrc  = path.join(packageDir, 'dpbs-docs');
  const docsDest = path.join(targetDir, 'dpbs-docs');

  if (!fs.existsSync(docsSrc)) {
    warn('dpbs-docs/ directory not found in package — skipping');
  } else {
    for (const dir of fs.readdirSync(docsSrc, { withFileTypes: true })
        .filter(e => e.isDirectory() && e.name !== 'vulcan-examples')
        .map(e => e.name)) {
      const destName    = DEST_NAME_OVERRIDES[dir] || dir;
      const srcSubpath  = SRC_SUBPATH_OVERRIDES[dir] || [];
      const src     = path.join(docsSrc, dir, ...srcSubpath);
      const dest    = path.join(docsDest, destName);
      const existed = fs.existsSync(dest);
      syncDir(src, dest);
      const n = countFiles(src);
      ok(`${existed ? 'updated' : 'created'}  dpbs-docs/${destName}/  (${n} file${n === 1 ? '' : 's'})`);
    }
    // Clean up a stale `dataos/` folder left by a pre-rename version of this
    // tool, now that it's installed as `vulcan-docs/`.
    const staleDataosDest = path.join(docsDest, 'dataos');
    if (DEST_NAME_OVERRIDES.dataos && fs.existsSync(staleDataosDest)) {
      fs.rmSync(staleDataosDest, { recursive: true, force: true });
    }
    // loose files at dpbs-docs/ root (e.g. .whl) — first delete any dest loose file
    // no longer present in src (e.g. a prior version's differently-named .whl),
    // then copy the current set, so re-running never leaves an old wheel behind.
    fs.mkdirSync(docsDest, { recursive: true });
    const looseSrcEntries = fs.readdirSync(docsSrc, { withFileTypes: true }).filter(e => !e.isDirectory());
    const looseSrcNames   = new Set(looseSrcEntries.map(e => e.name));
    for (const entry of fs.readdirSync(docsDest, { withFileTypes: true }).filter(e => !e.isDirectory())) {
      if (!looseSrcNames.has(entry.name)) {
        fs.rmSync(path.join(docsDest, entry.name), { force: true });
      }
    }
    for (const entry of looseSrcEntries) {
      const src     = path.join(docsSrc, entry.name);
      const dest    = path.join(docsDest, entry.name);
      const existed = fs.existsSync(dest);
      fs.copyFileSync(src, dest);
      ok(`${existed ? 'updated' : 'created'}  dpbs-docs/${entry.name}`);
    }
  }

  // ── Step 5: dpbs-docs/vulcan-examples (filtered or all) ────────────────────────
  if (fs.existsSync(examplesDir)) {
    // Only touches the selected engine folder(s) — examples for engines installed
    // in a previous run but not chosen this time are left untouched.
    const enginesToCopy = engine ? [engine] : validEngines;
    for (const eng of enginesToCopy) {
      const src     = path.join(examplesDir, eng);
      const dest    = path.join(docsDest, 'vulcan-examples', eng);
      const existed = fs.existsSync(dest);
      syncDir(src, dest);
      cleanDisallowedFiles(dest, EXAMPLES_PRUNE_NAMES);
      const n = countFiles(dest);
      ok(`${existed ? 'updated' : 'created'}  dpbs-docs/vulcan-examples/${eng}/  (${n} file${n === 1 ? '' : 's'})`);
    }
  }

  // ── Done ──────────────────────────────────────────────────────────────────
  log('');
  log(`${GREEN}${BOLD}Done!${RESET}  Your project now has:`);
  log('');
  for (const ideFolder of ideFolders) {
    info(`${ideFolder}/skills/design-data-product/`);
    info(`${ideFolder}/skills/build-data-product/`);
  }
  info(`dpbs-docs/vulcan-examples/${engine || '{all engines}'}/`);
  info(`dpbs-docs/vulcan-*.whl  — install: pip install "dpbs-docs/vulcan-*.whl[${engine || 'ENGINE'}]"`);
  log('');
  log('Ask the agent to use the skills — e.g.:');
  log(`  ${CYAN}"design a data product for daily revenue by customer segment"${RESET}`);
  log('');
}

main().catch(e => { console.error(e); process.exit(1); });
