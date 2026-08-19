# dataproduct-builder-skills

Cursor agent skills for designing and building [Vulcan/DataOS](https://dataosinfo.gitbook.io) data products.

Run a single command to scaffold agent skills for **Cursor**, **Claude Code**, **Codex**, or **VS Code (Copilot)** — plus the full Vulcan reference docs — into any project.

## Usage

Installs the skills and the Vulcan reference docs your project needs:

```bash
# Installs examples for all engines by default
npx dataproduct-builder-skills

# Or pass an engine to install examples for just that one
npx dataproduct-builder-skills snowflake
npx dataproduct-builder-skills postgres
npx dataproduct-builder-skills databricks
```

This launches an interactive prompt for which IDE(s) to install into:

```
dataproduct-builder-skills — scaffolding skills + docs

Which IDE(s) are you using? (comma-separated for multiple, e.g. 1,2)

  1  Cursor
  2  Claude Code
  3  Codex
  4  VS Code (Copilot)
  5  All

Enter number(s) (1–5):
```

Engine selection is **not** interactive — it's `all` by default, or whichever engine you passed as a CLI argument.



## What gets installed

```
.cursor/skills/              ← Cursor (created if you chose Cursor or All)
  design-data-product/
    SKILL.md
  build-data-product/
    SKILL.md
.claude/skills/               ← Claude Code (created if you chose Claude Code or All)
  design-data-product/
    SKILL.md
  build-data-product/
    SKILL.md
.codex/skills/               ← Codex (created if you chose Codex or All)
  design-data-product/
    SKILL.md
  build-data-product/
    SKILL.md
.github/skills/               ← VS Code / GitHub Copilot (created if you chose VS Code or All)
  design-data-product/
    SKILL.md
  build-data-product/
    SKILL.md
dpbs-docs/
  dataos-philosophy/  ← DataOS core concepts
  vulcan-docs/        ← Vulcan CLI & framework reference
  vulcan-examples/
    <engine>/         ← real working data product examples for your chosen engine
  vulcan-*.whl        ← Vulcan CLI wheel — install with: pip install dpbs-docs/vulcan-*.whl
```



## What the skills do



### `design-data-product`

Guides you from a vague idea to a validated `data-product-plan.md` spec through:

- Structured question batches (business context, data sources, grain, measures, metrics)
- Entity inference and table discovery via the Data Product MCP
- Model-kind classification, join recommendations
- Quality rules, AI context, and semantic behavior drafting

**Trigger**: ask the agent to *"design a data product"*, *"start a Vulcan design session"*, or *"help me with data-product-plan.md"*.

> **Requires**: Data Product MCP (`dataproduct-mcp/api/v1`) connected in Cursor Settings → MCP.



### `build-data-product`

Turns the validated design spec into a working, deployed Vulcan data product — scaffolding models, generating SQL/YAML, running `vulcan plan/evaluate`, enriching metadata, applying quality checks, and deploying to dev and prod.

**Trigger**: ask the agent to *"build the data product"*, *"scaffold the Vulcan project"*, or *"run vulcan plan"*.

## Requirements

- Node.js ≥ 16
- Data Product MCP connected in Cursor (for the design skill)
- Vulcan CLI (`pip install vulcan-data-tool`) for the build skill



## Re-running

Running `npx dataproduct-builder-skills` again safely updates existing files with the latest skill and docs content.

## Syncing Vulcan docs & examples (maintainers)

`dpbs-docs/dataos` and `dpbs-docs/vulcan-examples` are git submodules (GitHub `moderndatacompany/dataos` and Bitbucket `rubik_/vulcan-examples`, both tracking their `main` branch per `.gitmodules`), reused locally instead of re-cloned every time.

```bash
npm run sync:vulcan          # dry-run — shows what would change
npm run sync:vulcan:apply    # applies it
```

This updates/force-restores both submodules to their currently pinned commits, and restricts `dpbs-docs/dataos`'s working tree to just `documentation/references/resources/vulcan` via sparse-checkout. It does **not** filter `dpbs-docs/vulcan-examples` — that submodule is left with its full raw content after this script runs; engine/file filtering happens only at install time (`bin/create.js`) and at packaging time (see below). Run this whenever you want the full submodule content back for local browsing after packaging has pruned it, or after pulling `main` and seeing the submodules show up as "modified (new commits)" — a teammate updated the pinned commit and you just need to check it out locally.

To pull the *latest* upstream commit for both submodules (not just re-apply the currently pinned one):

```bash
git submodule update --remote --merge
npm run sync:vulcan:apply                            # re-apply the dataos sparse-checkout
git add dpbs-docs/dataos dpbs-docs/vulcan-examples   # stage the new pinned commits
```



### Automatic pruning before packaging

`npm pack`/`npm publish` runs `scripts/prepack-clean-examples.sh` automatically via the `prepack` npm lifecycle hook. It deletes everything in `dpbs-docs/vulcan-examples` except the allowed engines (`databricks`, `fabric`, `mssql`, `postgres`, `snowflake`, `spark`, `trino`) and strips junk files (`README.md`, `*.md`, `*.csv`, `*.tsv`, lockfiles, etc.) — without it, the raw submodule (200MB+ of seed CSVs, disallowed engines) would ship verbatim in the published tarball.

⚠️ This **mutates your working tree**, not just the pack output — after running `npm pack`/`npm publish`, `dpbs-docs/vulcan-examples` on disk will be pruned down. Run `npm run sync:vulcan:apply` (or `git submodule update --init --force dpbs-docs/vulcan-examples`) afterward to restore full content for local dev.

## Testing locally without publishing (maintainers)

Build a `.tgz` from your current working tree and install it into a scratch project to see exactly what a real `npx` install would produce, without publishing anything:

```bash
# from this repo's root — packs whatever is currently on disk (including
# any locally-synced submodule content in dpbs-docs/)
npm pack
```

This creates `dataproduct-builder-skills-<version>.tgz` in the repo root. Install it into any other folder:

```bash
mkdir -p /tmp/vulcan-test-project && cd /tmp/vulcan-test-project
npm init -y
npm install /path/to/builder-skillss/dataproduct-builder-skills-<version>.tgz
./node_modules/.bin/dataproduct-builder-skills snowflake
```

Inspect `.claude/skills/`, `.cursor/skills/`, and `dpbs-docs/` in that test project to verify the output. Re-run `npm pack` and reinstall the tarball after making further changes to pick them up. `*.tgz` files are gitignored — don't commit them.

## Publishing a new version (maintainers)

Follow these steps every time you want to ship an update to npm and GitHub.

### 1. Make your changes

Edit skill files, docs, or the CLI as needed.

### 2. Bump the version

```bash
# patch = bug fix (1.0.0 → 1.0.1)
# minor = new feature, backward-compatible (1.0.0 → 1.1.0)
# major = breaking change (1.0.0 → 2.0.0)
npm version patch   # or: minor | major
```

This automatically updates `package.json` and creates a git version commit + tag.

### 3. Push to GitHub

```bash
git push origin main --follow-tags
```



### 4. Publish to npm

```bash
npm publish --access public
```

> First time only: run `npm login` before publishing and sign in with your npm account.



### One-liner (steps 2–4 combined)

```bash
npm version patch && npm publish --access public && git push origin main --follow-tags
```



### 5. Verify

```bash
# confirm the new version is live on npm
npm view dataproduct-builder-skills version

# test the published package end-to-end
npx dataproduct-builder-skills@latest
```

---



## License

MIT