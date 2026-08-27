# dataproduct-builder-skills (Python)

Agent skills for designing and building [Vulcan/DataOS](https://v2.dataos.info/) data products — the Python port of the `dataproduct-builder-skills` npm scaffolder. Run it via `uvx`/`pipx` instead of `npx`.

Scaffolds agent skills for **Cursor**, **Claude Code**, **Codex**, or **VS Code (Copilot)** — plus the full Vulcan reference docs — into any project.

## Usage

Installs the skills and the Vulcan reference docs your project needs:

```bash
# Installs examples for all engines by default
uvx dataproduct-builder-skills

# Or pass an engine to install examples for just that one
uvx dataproduct-builder-skills snowflake
uvx dataproduct-builder-skills postgres
uvx dataproduct-builder-skills databricks
```

Or with `pipx`:

```bash
pipx run dataproduct-builder-skills snowflake
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
  grill-data-product/
    SKILL.md
  build-data-product/
    SKILL.md
.claude/skills/               ← Claude Code (created if you chose Claude Code or All)
  grill-data-product/
    SKILL.md
  build-data-product/
    SKILL.md
.codex/skills/               ← Codex (created if you chose Codex or All)
  grill-data-product/
    SKILL.md
  build-data-product/
    SKILL.md
.github/skills/               ← VS Code / GitHub Copilot (created if you chose VS Code or All)
  grill-data-product/
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

### `grill-data-product`

Guides you from a vague idea to a validated `data-product-plan.md` spec by grilling you with sharp, one-at-a-time questions instead of a scripted questionnaire:

- Adaptive interrogation — asks exactly what's still missing, pulling context from bundled reference docs and the Data Product MCP instead of surveying everything
- Entity inference and table discovery via the Data Product MCP
- Model-kind classification, join recommendations
- Quality rules, AI context, and semantic behavior drafting

**Trigger**: ask the agent to *"design a data product"*, *"grill me for a data product"*, *"start a Vulcan design session"*, or *"help me with data-product-plan.md"*.

> **Requires**: Data Product MCP (`dataproduct-mcp/api/v1`) connected in Cursor Settings → MCP.

### `build-data-product`

Turns the validated design spec into a working, deployed Vulcan data product — scaffolding models, generating SQL/YAML, running `vulcan plan/evaluate`, enriching metadata, applying quality checks, and deploying to dev and prod.

**Trigger**: ask the agent to *"build the data product"*, *"scaffold the Vulcan project"*, or *"run vulcan plan"*.

## Requirements

- Python ≥ 3.9
- Data Product MCP connected in Cursor (for the design skill)
- Vulcan CLI (`pip install vulcan-data-tool`) for the build skill

## Re-running

Running `uvx dataproduct-builder-skills` again safely updates existing files with the latest skill and docs content.

## Vendoring shared content (maintainers)

Before building/testing, vendor the shared `skills/` and `dpbs-docs/` content from the repo root into the package's `data/` directory (mirrors what `bin/create.js`/`npm pack` ships for the npm package):

```bash
python3 scripts/vendor_data.py
```

## Building the package (maintainers)

```bash
python3 scripts/vendor_data.py
uv build   # or: python3 -m build
```

This produces an sdist and wheel in `python/dist/`.

## Testing locally without publishing (maintainers)

```bash
uv build
uvx --from dist/dataproduct_builder_skills-<version>-py3-none-any.whl dataproduct-builder-skills snowflake
# or
pipx run --spec dist/dataproduct_builder_skills-<version>-py3-none-any.whl dataproduct-builder-skills snowflake
```

Inspect `.claude/skills/`, `.cursor/skills/`, and `dpbs-docs/` in a scratch project to verify the output.

## Publishing a new version (maintainers)

Follow these steps every time you want to ship an update to PyPI.

### 1. Make your changes

Edit skill files, docs, or the CLI as needed.

### 2. Bump the version

Update `version` in `python/pyproject.toml` to match the npm package's version in `package.json` (patch/minor/major, same semver rules as npm).

### 3. Vendor and build

```bash
python3 scripts/vendor_data.py
uv build
```

### 4. Publish to PyPI

```bash
uv publish   # or: python3 -m twine upload dist/*
```

> First time only: configure your PyPI credentials (`uv publish --token <token>`, or `~/.pypirc` for twine).

### One-liner (steps 3–4 combined)

```bash
python3 scripts/vendor_data.py && uv build && uv publish
```

### 5. Verify

```bash
# confirm the new version is live on PyPI
pip index versions dataproduct-builder-skills

# test the published package end-to-end
uvx dataproduct-builder-skills@latest
```

---

## License

MIT
