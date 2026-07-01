# dataproduct-builder-skills

Cursor agent skills for designing and building [Vulcan/DataOS](https://dataosinfo.gitbook.io) data products.

Run a single command to scaffold agent skills for **Cursor**, **Claude Code**, or **Codex** — plus the full Vulcan reference docs — into any project.

## Usage

Installs the skills and the Vulcan reference docs your project needs:

```bash
# Interactive — prompts you to pick an engine
npx dataproduct-builder-skills

# Or pass the engine directly to skip the prompt
npx dataproduct-builder-skills snowflake
npx dataproduct-builder-skills postgres
npx dataproduct-builder-skills databricks
Need to install the following packages:
dataproduct-builder-skills@1.1.0
Ok to proceed? (y) y


dataproduct-builder-skills — scaffolding skills + docs

Which IDE(s) are you using? (comma-separated for multiple, e.g. 1,2)

  1  Cursor
  2  Claude Code
  3  Codex
  4  All

Enter number(s) (1–4): 1

  →  IDE(s): Cursor

Which engine would you like to install examples for?

  0  All engines
  1  databricks
  2  postgres
  3  snowflake
  4  spark
  5  trino

Enter number (0–5): 1

  →  Engine: databricks

  ✓  created  .cursor/skills/build-data-product/
  ✓  created  .cursor/skills/design-data-product/
  ✓  created  docs/dataos-philosophy/  (22 files)
  ✓  created  docs/vulcan-book/  (79 files)
  ✓  created  docs/vulcan-0.228.1.26-py3-none-any.whl
  ✓  created  docs/vulcan-examples/databricks/  (60 files)

Done!  Your project now has:

  →  .cursor/skills/design-data-product/
  →  .cursor/skills/build-data-product-workflow/
  →  docs/vulcan-examples/databricks/
  →  docs/vulcan-*.whl  — install: pip install "docs/vulcan-*.whl[${ENGINE}]"

Ask the agent to use the skills — e.g.:
  "design a data product for daily revenue by customer segment"

npm notice
npm notice New major version of npm available! 10.9.2 -> 11.18.0
npm notice Changelog: https://github.com/npm/cli/releases/tag/v11.18.0
npm notice To update run: npm install -g npm@11.18.0
npm notice
shreyanegi@TMDCIN048 testtemp % 
```

This launches an interactive prompt:

```
dataproduct-builder-skills — scaffolding skills + docs

Which engine would you like to install examples for?

  0  All engines
  1  databricks
  2  postgres
  3  snowflake
  4  spark
  5  trino

Enter number (0–5):
```

## What gets installed

```
.cursor/skills/              ← Cursor (created if you chose Cursor or All three)
  design-data-product/
    SKILL.md
  build-data-product-workflow/
    SKILL.md
.claude/skills/              ← Claude Code (created if you chose Claude Code or All three)
  design-data-product/
    SKILL.md
  build-data-product-workflow/
    SKILL.md
.codex/skills/               ← Codex (created if you chose Codex or All three)
  design-data-product/
    SKILL.md
  build-data-product-workflow/
    SKILL.md
docs/
  dataos-philosophy/  ← DataOS core concepts
  vulcan-docs/        ← Vulcan CLI & framework reference
  vulcan-examples/
    <engine>/         ← real working data product examples for your chosen engine
  vulcan-*.whl        ← Vulcan CLI wheel — install with: pip install docs/vulcan-*.whl
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

### `build-data-product-workflow`

Turns the validated design spec into a working, deployed Vulcan data product — scaffolding models, generating SQL/YAML, running `vulcan plan/evaluate`, enriching metadata, applying quality checks, and deploying to dev and prod.

**Trigger**: ask the agent to *"build the data product"*, *"scaffold the Vulcan project"*, or *"run vulcan plan"*.

## Requirements

- [Cursor IDE](https://cursor.com)
- Node.js ≥ 16
- Data Product MCP connected in Cursor (for the design skill)
- Vulcan CLI (`pip install vulcan-data-tool`) for the build skill

## Re-running

Running `npx dataproduct-builder-skills` again safely updates existing files with the latest skill and docs content.

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