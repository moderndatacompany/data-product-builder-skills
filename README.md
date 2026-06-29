# builder-skills

Cursor agent skills for designing and building [Vulcan/DataOS](https://dataosinfo.gitbook.io) data products.

Run a single command to scaffold two powerful Cursor skills and the full Vulcan reference docs into any project.

## Usage

```bash
npx builder-skills
```

That's it. The command creates the following structure in your current directory:

```
.cursor/
  skills/
    design-data-product/
      SKILL.md        ← guides the agent through the full design workflow
    build-data-product-workflow/
      SKILL.md        ← turns a design spec into a deployed data product
docs/
  dataos-philosophy/  ← DataOS core concepts
  vulcan-book/        ← Vulcan CLI & framework reference
  vulcan-examples/    ← real working data product examples (Snowflake, Postgres, Spark, …)
```

## What the skills do

### `design-data-product`
Guides you from a vague idea to a validated `data-product-plan.md` spec through structured question batches, entity inference, table discovery, model-kind classification, grain definition, quality rules, and AI context drafting.

**Trigger**: ask the agent to *"design a data product"*, *"start a Vulcan design session"*, or *"help me with data-product-plan.md"*.

### `build-data-product-workflow`
Turns the validated design spec into a working, deployed Vulcan data product — scaffolding models, generating SQL/YAML components, running `vulcan plan/evaluate`, enriching metadata, applying quality checks, and deploying to dev and prod.

**Trigger**: ask the agent to *"build the data product"*, *"scaffold the Vulcan project"*, or *"run vulcan plan"*.

## Requirements

- [Cursor IDE](https://cursor.com)
- Node.js ≥ 16
- Vulcan CLI installed (`pip install vulcan-data-tool`) for the build skill

## Re-running

Running `npx builder-skills` again safely updates existing files with the latest skill content.

## License

MIT
