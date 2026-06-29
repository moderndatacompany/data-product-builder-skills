# dataproduct-builder-skills

Cursor agent skills for designing and building [Vulcan/DataOS](https://dataosinfo.gitbook.io) data products.

Run a single command to scaffold two powerful Cursor agent skills and the full Vulcan reference docs into any project.

## Installation

### Option 1 — Full install (recommended)

Installs the skills **and** the Vulcan reference docs your project needs:

```bash
# Interactive — prompts you to pick an engine
npx dataproduct-builder-skills

# Or pass the engine directly to skip the prompt
npx dataproduct-builder-skills snowflake
npx dataproduct-builder-skills postgres
npx dataproduct-builder-skills bigquery
```

This launches an interactive prompt:

```
dataproduct-builder-skills — scaffolding Cursor skills + docs

Which engine would you like to install examples for?

  0  All engines
  1  bigquery
  2  databricks
  3  fabric
  4  mssql
  5  mysql
  6  postgres
  7  redshift
  8  snowflake
  9  spark
  10 trino

Enter number (0–10):
```

### Option 2 — Skills only via `npx skills` (universal)

Works with Cursor, Claude Code, Codex, Windsurf, and [70+ other agents](https://github.com/vercel-labs/skills#supported-agents):

```bash
npx skills add Akshayram11/builder-skills -a cursor
```

> **Note:** This installs the SKILL.md files only — it does **not** copy the `docs/` folder.
> The skills rely on `docs/vulcan-book/` to function. Run Option 1 to get the full setup.

## What gets installed

```
.cursor/
  skills/
    design-data-product/
      SKILL.md        ← guides the agent through the full design workflow
    build-data-product-workflow/
      SKILL.md        ← turns a design spec into a deployed data product
docs/
  dataos-philosophy/  ← DataOS core concepts
  vulcan-docs/        ← Vulcan CLI & framework reference
  vulcan-examples/
    <engine>/         ← real working data product examples for your chosen engine
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

## License

MIT
