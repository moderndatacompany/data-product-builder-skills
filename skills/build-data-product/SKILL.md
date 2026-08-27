---
name: build-data-product
description: >-
  Build-focused workflow that turns a validated Vulcan/DataOS design spec
  (data-product-plan.md) into a working, deployed data product — scaffolding models,
  generating SQL/YAML components, running vulcan plan/evaluate, enriching metadata,
  applying quality checks, and deploying to dev and prod. After the build, it tells the
  user what vulcan review needs (review.model config, provider API key) without ever
  running review itself. Use when the user is ready to build a Vulcan data product, or
  asks about vulcan scaffold, vulcan plan, vulcan run, vulcan evaluate, model generation,
  DQ checks, or DataOS deployment.
disable-model-invocation: true
---

# Build Data Product — Vulcan Build Workflow

Build, validate, and deploy Vulcan data products. Be proactive, thorough, and action-oriented.

This skill turns a validated design spec into a working, deployed data product as fast as possible. The input is a `data-product-plan.md` produced by the `design-data-product` skill.

> **How this skill is installed**: The skills and grounding docs are installed by running `npx dataproduct-builder-skills` in the project root. This copies the skill files into the IDE folder (`.cursor/skills/`, `.claude/skills/`, or `.codex/skills/`) and installs `dpbs-docs/vulcan-docs/`, `dpbs-docs/dataos-philosophy/`, and `dpbs-docs/vulcan-examples/` into the project. If at any point the grounding docs are missing or a `dpbs-docs/` read returns nothing, tell the user to run `npx dataproduct-builder-skills` in their project root to install them.

**Language note**: Vulcan is anti-pipeline. Never use "pipeline" in output or conversation. Use "model DAG", "data product", or "model layers" instead.

## Vulcan Project Layout (standard structure created by `vulcan init`)

```
config.yaml          — Project configuration (gateways, linter rules, model_defaults, notifications)
models/              — SQL or Python model definitions containing MODEL(...) blocks
  staging/           — Staging/intermediate models (stg_*, dim_*, fct_*)
  semantics/         — Semantic layer definitions (YAML: dimensions, measures, segments, joins)
  metrics/           — Metric definitions (YAML, kind: metric)
audits/              — Custom audit SQL files containing AUDIT(...) blocks
dq/                  — Data quality checks (YAML, kind: dq, one per model)
tests/               — Unit test definitions (YAML: mock inputs + expected outputs)
seeds/               — CSV seed data files (seed SQL models live in models/)
macros/              — Python macro functions (custom Jinja-like helpers)
usage.yaml           — Business-facing usage guidance (good_for, not_for, caveats, references)
linter/              — Custom linter rules (Python)
signals/             — Event signal handlers (Python)
```

---

## Gate Check

**Before anything else**: Confirm the user has *some* spec to build from — it does not have to be a `data-product-plan.md` produced by `design-data-product`. Classify what they hand you:

- **No spec at all** → stop. Direct them to `design-data-product` first (or, for a DataOS 1.0 project, `migrate-data-product`). Do NOT gather requirements or generate a design spec here — that is those skills' job, not this one's.
- **Canonical spec** — a `data-product-plan.md` (or `migration-map.md`) carrying the expected sections (engine, grain, entities, measures/dimensions/metrics, Section 13 Model Architecture, Section 15 Quality Rules) → proceed straight to Stage 0.
- **External spec** — anything else the user brings in: a PRD, a dbt/Cube/other tool's YAML, a wiki export, a hand-written note, a JSON contract, etc. → run **Spec Intake** below before Stage 0.

### Spec Intake (external specs only)

The rest of this workflow (Stage 0 onward, the error-handling loop, the syntax rules) is written assuming a `data-product-plan.md`-shaped input. An external spec needs to be mapped onto that shape first — this step does the mapping, it does not replace `design-data-product`'s discovery rigor.

**Required fields** (the "spec contract" this workflow actually consumes): engine, grain, entities, measures (with aggregation type), dimensions, metrics (measure + time dimension), model architecture / layering (Section 13 equivalent), quality rules (Section 15 equivalent — at minimum grain/key assertions).

1. Read the external spec in full. Map its content onto the required fields above.
2. For each required field the spec doesn't state explicitly, either infer it from what the spec *does* say (mark it `[Assumption]`, same discipline `design-data-product` uses) or ask the user directly — do not silently invent a grain, measure formula, or quality rule.
3. Write the mapped result into a normalized `data-product-plan.md` (reuse the Artifact Template from `design-data-product`'s SKILL.md; sections with no source content in the external spec stay marked "To be defined" or `[Assumption]`, not fabricated).
4. Proceed to Stage 0 using this normalized file as the spec.

**Tell the user plainly, before generating anything**, that this path produces a lower-confidence build than a spec that went through `design-data-product`:

> **Reduced-confidence build:** This spec didn't come from the `design-data-product` workflow, so it hasn't been through entity confirmation, table profiling, join/cardinality checks, the measure/metric formula probe, the answerability review, or `ai_context`/`behavior` drafting. I've mapped what your spec provides onto the fields this build needs and flagged the rest as assumptions or open questions below — please review those closely, they're the parts most likely to be wrong. For anything business-critical, running it through `design-data-product` first will produce a more reliable build.

Show the mapped fields, the `[Assumption]` list, and any open questions, and get explicit user confirmation before proceeding to Stage 0 — same checkpoint discipline as `design-data-product`'s Stage 2.5.

After the Gate Check (and Spec Intake, if it ran) passes, display this disclaimer exactly once before continuing:

> **Build Disclaimer:** This build is AI-assisted and generated from your design spec. Please review the plan and generated files carefully before deploying to development or promoting to production, especially for semantic correctness, data quality, and environment-specific behavior

## Command Execution

Do not invoke a DataOS-CTL MCP server/tool even if one is connected in this session — treat it as unavailable.

Always use the `vulcan` CLI directly. Before running any `vulcan` command, determine how to invoke it — try these in order and then use the first one that works for the rest of the session:

1. **CLI as-is**: Run `vulcan --version`. If it works, use `vulcan` directly.
2. **Workspace venv**: If step 1 fails, look for an existing virtual environment (`.venv/` or `venv/` in the project root) and check it — `.venv/bin/vulcan --version`. If `vulcan` resolves there, use that invocation for the rest of the session.
3. **Auto-install from bundled wheel**: If `vulcan` is not found in steps 1–2, install it automatically using the bundled wheel:
   1. Read `dpbs-docs/vulcan-docs/ldk.md` and present it to the user so they understand the setup.
   2. Find the wheel file: look for `dpbs-docs/vulcan-*.whl` (glob — pick the first match).
      - If **no match** → tell the user: "The Vulcan wheel is not found under `dpbs-docs/`. Please run `npx builder-skills` first to install it, then let me know." **STOP** until confirmed.
      - If **found** → let `WHEEL=$(ls dpbs-docs/vulcan-*.whl | head -1)` and proceed.
   3. Create the `.venv` — run this unconditionally (it is a no-op if `.venv` already exists):
      - First verify Python 3.10 is available (Vulcan requires `>=3.9, <3.11`):
        ```bash
        python3.10 --version
        ```
        If the command fails, tell the user: "Python 3.10 is required but not found. Please install it (`brew install python@3.10` on macOS) and try again." **STOP** until confirmed.
      - Then create the venv using Python 3.10 explicitly:
        ```bash
        python3.10 -m venv .venv
        ```
      - Confirm it worked before proceeding:
        ```bash
        ls .venv/bin/pip
        ```
        If `ls` fails, stop and tell the user: "Could not create `.venv` — please ensure Python 3.10 is installed (`python3.10 --version`) and try again."
   4. Determine the engine extra:
      - Check `data-product-plan.md` Section 2 for the engine (e.g. `postgres`, `snowflake`, `databricks`, `spark`, `trino`).
      - If not found in the spec, ask the user: "Which engine are you using? (postgres / snowflake / databricks / spark / trino)"
      - Store it as `ENGINE`.
   5. Install the wheel with the engine extra into the venv:
      ```bash
      .venv/bin/pip install "${WHEEL}[${ENGINE}]"
      ```
      For example, for Postgres: `.venv/bin/pip install "${WHEEL}[postgres]"`
   6. Verify: `.venv/bin/vulcan --version`. If it prints a version, use `.venv/bin/vulcan` for all subsequent commands in this session.
   7. If the install or verification still fails, **HARD STOP**:
      > "Vulcan CLI installation failed. Please check the error above, review `dpbs-docs/vulcan-docs/ldk.md` for prerequisites, and let me know when it's resolved."
      > Do NOT continue with any `vulcan` command until the user confirms it is fixed.

Once the working invocation is determined, use it consistently throughout the session.

---

### Project Initialization

Check if the project directory contains `config.yaml`, `models/`, `models/semantics/`, `dq/`, `tests/`, `audits/`, and `usage.yaml`.

- If **missing** → initialize the project using `vulcan init <engine_name>`:
  1. **Identify the engine**: Check the design spec or `data-product-plan.md` for the target warehouse/engine (e.g., `postgres`, `snowflake`, `bigquery`, `duckdb`).
  2. **If the engine is NOT found** in the spec → **STOP and ask the user**:
     > "Which database engine are you using? (e.g., postgres, snowflake, bigquery, duckdb)"
     > Do NOT proceed until the user provides the engine name.
  3. **Once the engine is known** → run:
     ```
     vulcan init <engine_name> --template empty
     ```
     For example: `vulcan init postgres --template empty` or `vulcan init snowflake --template empty`.

     **Always pass `--template empty`** — without it, `vulcan init` prompts interactively (DEFAULT vs EMPTY) and, if DEFAULT is picked, drops demo scaffolding that references a non-existent example model (e.g. `models/full_model.sql`, `models/incremental_model.sql`, `models/seed_model.sql`, `models/semantics/incremental_model.yml`, `models/metrics/*_activity.yml`, `dq/full_model.yml`, `tests/test_full_model.yaml`). Left in place, those fail the very first `vulcan plan` with `Relation does not exist` / `depends_on not found`. `--template empty` skips the prompt and creates only `config.yaml` and the empty project directories — no demo files to clean up.

  After init completes, **STOP** and tell the user:

  > "Project initialized with `<engine_name>` defaults. Please review and update `config.yaml` — especially warehouse connection settings (host, port, username, password, database). Let me know when you're ready to continue."

  **Set `config.yaml` `name:` to kebab-case now** — lowercase + hyphens (e.g. `customer-pricing-recommendations`, NOT `customer_pricing_recommendations`). `vulcan create_deploy_yaml` validates it against `^[a-z]([-a-z0-9]*[a-z0-9])?$` and rejects underscores; changing `name:` later invalidates the state registry and forces a `.state.db` delete + re-plan.
  **Wait for the user to confirm** before proceeding. Do NOT continue automatically.

  **Add `ignore_patterns` to `config.yaml` BEFORE any plan** — this is mandatory. Vulcan scans the entire project directory, so without ignore patterns it will pick up files from `dpbs-docs/` (including `dpbs-docs/vulcan-examples/`, `dpbs-docs/vulcan-docs/`, `dpbs-docs/dataos-philosophy/`) and attempt to compile them as models, causing spurious errors. Open `config.yaml` and add:

  ```yaml
  ignore_patterns:
    - "dpbs-docs/**"
  ```

  Do this immediately after init, before running any `vulcan plan` or generating any project files. If this step is skipped, every subsequent plan will fail with confusing errors from the docs files.

**Extending an existing data product?** If the user is not building from scratch, first identify what's new vs. what already exists. Use `vulcan diff prod` to assess impact. Only build the gap — don't regenerate components that already work.

---

## Stage 0: UNDERSTAND THE SPEC

**Goal**: Fully understand the design spec before writing a single line of code. Complete all steps and show the verification summary before proceeding to Stage 1.

**Step 1 — Read the spec thoroughly**

Read the entire `data-product-plan.md` end-to-end, including the Verification Summary from the design workflow if present. Hold its content in memory — you will work directly from it when planning the scaffold and enriching metadata in Stage 1.

Pay attention to: entities, grain, measures vs metrics, dimensions, sources, consumption pattern, and assumptions.

**Extract and hold the engine**: Find the `engine` field in Section 2 (Data Sources) or the YAML contract. Store it as `<ENGINE>`. For ALL example lookups in this session, you MUST only read from `dpbs-docs/vulcan-examples/<ENGINE>/`. Never open any other engine subfolder (e.g. if engine is `snowflake`, read only from `dpbs-docs/vulcan-examples/snowflake/` — never from `postgres/`, `trino/`, etc.). If the engine is missing from the spec, stop and ask the user before continuing.

**Step 2 — Verify build-specific concepts**

The design workflow already verified core Vulcan concepts (grain, measures, metrics, dimensions, entities, model kinds). Read the relevant pages in `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/` only for implementation-level concepts not covered in the design verification:

- `column_descriptions` — syntax and requirements for MODEL blocks
- `SEED models` — when to use seeds vs external models
- The cron schedule format from the spec (e.g., "@daily", "@hourly")
- Any business terms from the spec that lack clear definitions

If the spec has NO verification summary, fall back to full verification: read the `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/` pages for every Vulcan concept (grain, MODEL kind, assertions, semantic measures, time dimensions) and confirm every business term.

**Step 3 — Plan components**

From the spec, enumerate every component you will generate (seeds, staging/gold models, semantics, checks, tests, audits) in generation order. Hold this list — you will retrieve examples and templates for each component individually in Stage 1 immediately before generating it.

**Step 4 — Create verification summary**

Document your understanding and show this to the user before proceeding to Stage 1:

````
## STAGE 0 VERIFICATION SUMMARY

### Spec Understanding:
- **Grain**: [one row represents...]
  Source: dpbs-docs/vulcan-docs and dpbs-docs/dataos-philosophy (grain)
- **Entities**: [list]
- **Measures**: [list with aggregation types]
- **Metrics**: [list — each as measure + time dimension]
- **Dimensions**: [list with types]

### Implementation Reasoning (WHY & HOW):

**WHY these models:**
- **Gold Model**: [chosen because grain requires aggregation of X over Y timeframe, matches [example pattern] from dpbs-docs/vulcan-examples]
- **Silver Model** (if needed): [chosen because multiple gold models need [shared join], OR raw data needs [cleaning/dedup] before aggregation]
- **Bronze Models**: [chosen to ingest from [sources] because gold columns [A, B, C] come from these tables]

**HOW they connect:**

```
Flow: Bronze [raw_orders, raw_customers]
→ Silver [orders_enriched with JOIN on customer_id]
→ Gold [daily_sales aggregated by date+customer_tier]
→ Semantic [measures: total_revenue, dimensions: customer_tier, date]
```

**Model Selection Justification:**
- Model Kind: [FULL/INCREMENTAL_BY_TIME_RANGE/INCREMENTAL_BY_UNIQUE_KEY/EMBEDDED/SEED/SCD_TYPE_2_BY_TIME/SCD_TYPE_2_BY_COLUMN/VIEW] chosen because [data volume/refresh pattern/source characteristics from dpbs-docs/vulcan-docs and dpbs-docs/dataos-philosophy]
- Grain Justification: [one row per X because metrics require Y level of detail, verified against [example]]
- Staging Decision: [needed/not needed because: shared logic across N models / single gold use only]

### Vulcan Implementation Plan:
- **Model Kind**: [FULL/INCREMENTAL_BY_TIME_RANGE/INCREMENTAL_BY_UNIQUE_KEY/EMBEDDED/SEED/SCD_TYPE_2_BY_TIME/SCD_TYPE_2_BY_COLUMN/VIEW]
  Rationale: [from dpbs-docs/vulcan-docs and dpbs-docs/dataos-philosophy]
- **Schema**: [raw/staging/analytics]
- **Assertions Needed**: [list based on grain/measures]
- **Time Dimension**: [field name, TIMESTAMP cast required: yes/no]

### Components to Build:
- Seeds: [list with column counts]
- Staging: [list, or "None - direct bronze to gold"]
- Gold: [model name with grain]
- Semantic: [model alias with measure/dimension counts]
- Checks: [assertion types planned]
- Tests: [test case descriptions]

CHECKPOINT: Present this summary to the user and STOP. Do NOT proceed to Stage 1 until the user explicitly confirms. Wait for their response.
````

**Proceed to Stage 1 only when:** all tool calls completed, verification summary shown, and the user has replied with explicit confirmation. You should be able to confidently answer: What does one row represent? What are the source tables? What are the entities and relationships? What are measures vs metrics? What dimensions will the semantic layer expose?

---

## Reference

### Core Principles

1. **Ground in the docs** — before using any Vulcan concept, syntax, or pattern in output, confirm it against `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/` (and read from `dpbs-docs/vulcan-examples/` for syntax). See Resource Selection Quick Reference.
2. **Never reason beyond the docs** — if a concept, syntax, or pattern isn't explicitly covered in `dpbs-docs/vulcan-docs/`, `dpbs-docs/dataos-philosophy/`, or `dpbs-docs/vulcan-examples/`, don't deduce or extrapolate an answer from general knowledge. Say it's undocumented and ask the user or point to the closest documented alternative. Do NOT search the web or consult dataos.info (or any other online DataOS/Vulcan documentation site) as a fallback — it may not match this project's bundled version. `https://v2.dataos.info` is the one exception — it's the correct, current documentation domain and may be used.
3. **Fix, don't explain** — when errors occur, apply the exact fix. Don't stop at diagnosis.
4. **Iterate per component** — generate → `vulcan evaluate` → fix → `vulcan plan` → fix → next component. Never batch all files before your first plan run.

---

### Standard Error Handling Loop

This loop is used whenever `vulcan plan` fails, at any stage:

1. Read the error message from `vulcan plan` output
2. Look up the error in `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/` (search for the error text or the concept it touches) to understand the root cause and fix
3. Fix the broken file yourself, cross-checking against the relevant `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/` pages and the Vulcan syntax rules below
4. If the root cause is structural (not just syntax) → read from `dpbs-docs/vulcan-examples/` (category: `<affected category>`, engine: `<engine>`) to see how working projects handle it
5. Apply the fix
6. Re-run `vulcan plan`
7. Repeat until the plan succeeds

**Common error patterns:**

- "Entity has no valid time dimension" → the semantic model has no TIMESTAMP time dimension; cast the time column to TIMESTAMP in the SQL model
- "Column not found" → name mismatch between SQL SELECT and MODEL block
- "Duplicate model name" → model exists from a previous plan
- "Invalid assertion" → assertion references a column not in the SELECT
- "Relation does not exist" → source table not materialized (missing SEED?)
- "no join path between '<model>' and '<dep>'" on a measure → the column in the measure `expression` is not in the `dimensions:` list; add it (the error says "no join path", NOT "unknown dimension")
- "Extra inputs are not permitted" on a measure → you put `format:` (or another dimension-only/unknown key) on a measure; remove it (`format:` belongs on dimensions only)
- "Extra inputs are not permitted" in ai_context → an unknown ai_context key, or `examples` written as bare strings; `examples` must be a list of `{description, format, query}` objects
- Measure name collision → a measure name equals a dimension/column name; rename the measure (e.g. `m_<col>`, `avg_<col>`). `count` is reserved — never use it as a measure name
- `Measure '<m>' of type 'number' requires a non-empty expression` → the installed CLI won't accept the `ratio` behavior shape (numerator/denominator, no expression); drop the `ratio` behavior and compute the ratio as filtered `count`/`sum` measures, dividing downstream
- "stock" measure rejected / missing period_grain → a `stock` behavior is missing `period_grain` (and/or `time_dimension`/`period_treatment`); add all three
- "Model owner is not listed in config.users" → add the owner to `users:` in config.yaml before planning
- "Incomplete audit definition" → an `audits/*.sql` file is missing its `AUDIT (name ...)` header above the SELECT
- deprecation warning on `external_models.yaml`/`schema.yaml` → rename the external-sources file to `inputs.yaml`
- `_duckdb.BinderException: Ambiguous reference to ... "vulcan"` → local DuckDB state/data schema clash; use the fully-qualified path (`vulcan.vulcan`) and keep the state DB separate from the data schema
- "Extra inputs are not permitted" on `granularities:` → the installed CLI doesn't accept it; remove it and rely on the metric-level `granularity` for time buckets (only keep `granularities:` if your CLI accepts it)
- multi-column grain → use `grains [col1, col2, col3]` (canonical); `grain (col1, col2)` also works — both are valid, so don't treat either form as the error
- DQ `dimension: integrity` rejected → `integrity` is not one of Vulcan's 8 DQ dimensions; use `validity`/`consistency` (valid set: completeness, validity, accuracy, consistency, uniqueness, timeliness, conformity, coverage)
- test YAML "expected a dict, got str" / top-level `model:` rejected → wrap the test under a top-level name (`test_<name>:`) with `model`/`inputs`/`outputs` nested under it
- duplicate model / duplicate-key error after changing `config.yaml` `name:` (or renaming a model) → stale state registry; delete the state DB (`.state.db`) and re-plan
- `Relation does not exist` / `depends_on` not found on the FIRST plan → project was likely initialized without `--template empty`, leaving demo files referencing nonexistent models; STOP and ask the user how to proceed rather than deleting anything yourself
- `relation does not exist` during `vulcan evaluate -e dev` (NOT the first plan) → `evaluate` re-ran the SQL but didn't rewrite an intermediate VIEW dependency to its `__dev` name; query the already-materialized dev table directly with `vulcan fetchdf "SELECT * FROM <schema>__dev.<model> LIMIT 10"`
- YAML parse errors → indentation or syntax issue

Always use `vulcan plan`, NOT `vulcan plan` alone. The `--auto-apply` flag skips the interactive `y/n` prompt — without it, the command blocks the agent indefinitely.

---

### Resource Selection Quick Reference

Ground every step in the docs and real examples — this is mandatory, not optional.

| Situation                                          | What to do                                                                                                                                     | When                                                                                    |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Any Vulcan concept mentioned                       | Read the relevant page(s) in `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/`                                                                 | BEFORE using the concept in any output                                                  |
| Before starting a component group                  | Read files from `dpbs-docs/vulcan-examples/<engine>/` only — do NOT open any other engine subfolder                                                 | ONCE per group, before generating any file in it                                        |
| After generating a file, or when vulcan plan fails | Self-review the file against `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/`, the Vulcan syntax rules below, and the group examples          | After writing each file to catch Vulcan-specific issues; and in the error recovery loop |
| Plan the project structure                         | Derive the file manifest yourself from the spec + `VULCAN_PROJECT_LAYOUT` + examples                                                           | BEFORE generating files                                                                 |
| Enrich metadata                                    | Derive column descriptions/tags/owner/terms yourself from the spec + docs                                                                      | After Groups A-C are written to disk (Step 2.5)                                         |
| Plan quality rules and checks                      | Derived during design (Section 15 of spec); re-derive yourself after Group B only if Section 15 is absent or any values are marked [Estimated] | —                                                                                       |

When a docs page you used has a reference URL, show it to the user as "Reference docs:".

---

### Per-Engine Reference Notes

`dpbs-docs/vulcan-examples/<engine>/` gives you real files for the target engine, but doesn't call out *why* one engine's file looks different from another's. `engines/<engine>.md` (in this skill's own directory, next to this SKILL.md) fills that gap: identifier casing convention, physical-model typing style, model-kind default pattern, and — the highest-defect-rate item — the per-engine date/time function syntax used inside semantic `segments:`/measure `expression:` fields (e.g. Postgres's `CURRENT_DATE - INTERVAL '7 days'` vs Databricks/Spark's `DATE_SUB(CURRENT_DATE(), 7)` vs MSSQL/Fabric's `DATEADD(DAY, -7, CAST(GETDATE() AS DATE))` vs Trino's `INTERVAL '7' DAY`).

| `<ENGINE>` | File | Notes |
|---|---|---|
| `postgres` | `engines/postgres.md` | Reference dialect — ANSI intervals, `::` casts |
| `snowflake` | `engines/snowflake.md` | UPPERCASE everywhere, defensive `::` casts even in `WHERE` |
| `databricks` | `engines/databricks.md` | Spark SQL family — no `::`, use `CAST()`; `DATE_SUB(CURRENT_DATE(), N)` |
| `spark` | `engines/spark.md` | Same cast rule as Databricks; casing follows the source table, not a fixed convention |
| `trino` | `engines/trino.md` | Explicit `columns()` block; `INTERVAL 'N' DAY` (number/unit split, not a quoted phrase) |
| `mssql` | `engines/mssql.md` | T-SQL — no `::`, use `CAST()`; `DATEADD`/`GETDATE()`, no native `DATE_TRUNC` |
| `fabric` | `engines/fabric.md` | Same T-SQL surface as `mssql` — thin file, points back to `mssql.md` |

**When**: read the file for `<ENGINE>` once, right before starting Group A/B (models) and again before Group C (semantics) — same timing as the `dpbs-docs/vulcan-examples/<engine>/` read, not a separate pass.

**How**: use it to decide casing and typing style *before* writing a file, and to look up the correct date/time function whenever a segment or measure `expression:` needs "last N days"/date-truncation/current-date logic — do not reuse another engine's date-function syntax verbatim even if the rest of the semantic YAML structure is identical across engines. If a shared `macros/*.py` file is in play (e.g. a `safe_divide` macro emitting `::FLOAT`), check the target engine's file for the `::`-cast note before assuming the macro is portable.

If no file exists yet for the target engine, say so and fall back to the general syntax rules in this document plus `dpbs-docs/vulcan-book/`.

---

### Layer Naming Convention

| Layer  | Schema        | Purpose                                     | Examples                                        |
| ------ | ------------- | ------------------------------------------- | ----------------------------------------------- |
| Bronze | `raw.*`       | Raw data ingestion (seeds, external models) | `raw.raw_orders`, `raw.raw_customers`           |
| Silver | `staging.*`   | Cleaned, joined, enriched. Shared logic.    | `staging.orders_enriched`, `staging.stg_orders` |
| Gold   | `analytics.*` | Final aggregated output for semantic layer  | `analytics.daily_sales`                         |

---

### Optional: Rollup Candidates (suggest, never assume)

Rollups pre-aggregate a semantic model for query performance (`dpbs-docs/vulcan-docs/models/semantic-models/rollups.md`) and are off by default (`enable_rollup: true` in `config.yaml`). This is a real-data, real-query-pattern decision — never add one without the user opting in.

**Check the design spec first.** Section 15.8 (Rollup Candidates) of `data-product-plan.md` may already have a candidate the design workflow flagged (see Group C pre-check step 8). If so, that's your starting point — confirm it's still relevant now that the semantic model actually exists, rather than re-deriving one from scratch.

After Group C (Semantic Layer) is written and passing `vulcan plan`, look at the measures + `time_dimension` combinations you just defined — whether or not Section 15.8 had a candidate. If Section 15.8 named one, ask about that specifically; if it's `Not applicable` but a pattern is now obvious with the real semantic model in front of you (a measure grouped by a time bucket plus one or two categorical dimensions that dashboards will hit constantly), ask the user once:

> "`[measure]` grouped by `[time_dimension]` (+ `[dimension]`) looks like a common query pattern. Want a rollup for it? (Optional — speeds up repeated queries once data volume grows; adds a managed table.)"

If yes: set `enable_rollup: true` in `config.yaml`, add a `rollups:` block to the semantic YAML (`measures`, `dimensions`, `time_dimension`, `granularity` — see the docs page for the full schema and the 32-character Postgres identifier limit on the combined `<semantic_model>_<rollup_name>` name), and re-run `vulcan plan`. If no, or nothing looks like an obvious repeated pattern, skip it entirely — don't ask again later in the same build.

---

## Workflow

### Stage 1: SCAFFOLD (Blueprint-Driven)

**Goal**: Get a project blueprint, then generate and verify each component group.

**Step 1 — Plan the blueprint**:

Derive the project blueprint yourself from the spec — there is no scaffold tool. Using the
`data-product-plan.md` (Section 13 Model Architecture especially), the `VULCAN_PROJECT_LAYOUT`,
and `dpbs-docs/vulcan-examples/` for each component type, produce a **ScaffoldPlan** consisting of:

- `file_manifest`: files to create, each with `path`, `vulcan_component`, `purpose`, `traceability` (which spec section drove it)
- `consistency_rules`: cross-file dependency rules (matching model names, matching column names, semantic measure names that differ from columns)
- `generation_order`: seeds → staging → final → semantics → metrics → checks → tests

Write this plan down before generating any files. Ground every file's structure in the matching
examples from `dpbs-docs/vulcan-examples/` (category: `...`, engine: `<engine>`) and the relevant `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/` pages.

**Note**: Metadata enrichment runs AFTER models are written to disk — see Step 2.5.

**Step 1.5 — Populate usage.yaml**:

After `vulcan init`, populate the root `usage.yaml` stub from the design spec. It has four optional top-level keys — `good_for`, `not_for`, `caveats`, `references` — each a list of strings OR `{title, details}` objects (`caveats` items may add `severity`; `references` items use `{title, url, type}` where `type` is one of `doc | design | dashboard | runbook | other` — `external` is NOT a valid value). There is NO separate `limitations.yaml` — known limits/constraints go under `caveats`. Example:

```yaml
good_for:
  - Track daily revenue by customer segment
  - title: Churn trend analysis
    details: Monitor churn rate trends over time across segments
not_for:
  - Real-time alerting or live operational dashboards
caveats:
  - Historical data only available from 2022-01-01 onwards
  - title: National channel excluded from segment rollups
    severity: low
references:
  - title: Design spec
    url: ./data-product-plan.md
    type: doc
```

Source `good_for` from Section 1 (Business Context: Use Case and Key Questions); source `not_for`/`caveats` from Section 12 (Open Questions / known constraints) plus any freshness or exclusion notes.

**Also write `agreement.md`**: Read Section 10.5 (Data Agreement) of `data-product-plan.md` — this section is now mandatory in every plan produced by `grill-data-product`/`design-data-product`, so expect it populated. Write its content as `agreement.md` at the project root: prose markdown covering who it covers, allowed/disallowed uses, handling, retention, crediting, and consequences — Vulcan doesn't parse this file, so write it as readable text for a human to accept, not YAML. The default `agreement_path` in `config.yaml` is already `agreement.md`, so no config change is needed unless the project already sets a different `agreement_path` or an inline `agreement` key — if one exists, tell the user about the conflict rather than silently overriding it. (If Section 10.5 is genuinely missing — e.g. an external/Spec-Intake spec that never went through the mandatory-agreement policy — draft one now from Section 1's consumers/use case, grounded in `dpbs-docs/vulcan-docs/configurations/agreement.md`, rather than skipping it.)

---

**Step 1.6 — Load quality rules from spec**:

Section 15 of `data-product-plan.md` already contains quality rules derived during design.
Read Section 15 now and hold these in memory for use in Groups B and D:

- Audit Assertions → will be merged into the gold model's `MODEL()` assertions block (Group B)
- Custom Audit Files → will be written to `audits/` (Group D)
- Data Quality Rules (`kind: dq`) → will be written to `dq/{model_name}.yml` (Group D)
- Coverage Gaps → surface HIGH-priority ones to the user as TODOs now

Present HIGH-priority coverage gaps to the user immediately:

```
Quality coverage gaps (from design spec):
HIGH: [area] — [recommendation]
MEDIUM: [area] — [recommendation]  (can address later)
```

**If Section 15 is absent or any values are marked [Estimated]**, re-derive the quality rules yourself
AFTER Group B completes (you will then have a deployed model — pull real schema/values from
`vulcan evaluate <model_ref> --limit 1`). Ground the rule types in the `dq`/audits pages of
`dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/` and read from `dpbs-docs/vulcan-examples/` (category: `dq` or `audits`, engine: `<engine>`), then
update Section 15 of `data-product-plan.md` with the refined rules and real thresholds.

**Step 2 — Generate and verify component-by-component**:

After generating each component group (A through E), you must:

1. Run `vulcan evaluate <model_name> --limit 10` for each SQL model in the group
2. Run `vulcan plan` and confirm it passes
3. Fix all errors before moving to the next group

Follow `generation_order`, grouped by component type. After each group, run `vulcan plan` and resolve all errors (using the Standard Error Handling Loop) before moving on.

| Order   | Component Group         | Directory           | Common Issues                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------- | ----------------------- | ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | ---- | ----- | ----------------------------------------------------------------------- |
| A       | Seed Models             | `models/`           | Column mismatch with CSV headers — always inspect the CSV first                                                                                                                                                                                                                                                                                                                                                 |
| B       | Staging / Final Models  | `models/`           | Column type mismatches, missing source refs, assertion syntax, missing DATE_TRUNC for time grains                                                                                                                                                                                                                                                                                                               |
| C       | Semantic Layer          | `models/semantics/` | `dimensions:` is a plain list (no includes/excludes); every column a measure `expression` references must be in `dimensions:`; measure names must differ from columns and never be `count`; `format:` is dimension-only (never on measures); ai_context only allows instructions/synonyms/caveats/examples (examples = `{description, format, query}` objects); typed dimensions use `behavior.type: identifier | categorical`; measures use `behavior.type: simple | flow | stock | ratio` (`stock` needs time_dimension + period_treatment + period_grain) |
| C.5     | Metrics                 | `models/metrics/`   | Must reference measure names that exist in models/semantics/\*.yml; kind: metric required                                                                                                                                                                                                                                                                                                                       |
| **2.5** | **Metadata enrichment** | _(all files)_       | Enrich the written files yourself from the spec + docs — see Step 2.5 below                                                                                                                                                                                                                                                                                                                                     |
| D       | Data Quality & Audits   | `dq/`, `audits/`    | Must use kind: dq format with depends_on and rules: block — not Soda-style                                                                                                                                                                                                                                                                                                                                      |
| E       | Tests                   | `tests/`            | `outputs` must use `query:` with nested `rows:` (no inline SQL string); INCREMENTAL models need `vars: {execution_time: <date>}` within the mock data range; mock the staging model (direct dep), not raw seeds                                                                                                                                                                                                 |

**Before generating Seed Models (Group A)**: Check the `model_kinds` list in `data-product-plan.md` for any entity marked `SEED`. If none exist, skip Group A entirely and delete the empty `seeds/` directory — it's just an unused stub from `vulcan init --template empty`. If SEED entities do exist, read the actual CSV files in `seeds/` to verify column names and types. The CSV headers are the source of truth — do NOT assume columns from the design spec alone. If the user has real source tables (not CSVs), use EXTERNAL models instead of SEEDs: run `vulcan create_external_models` to generate `inputs.yaml` at the project root (the current filename — `external_models.yaml`/`schema.yaml` are deprecated and log a warning). After Group A, if `seeds/` ended up empty (e.g. all planned seeds turned into EXTERNAL models instead), delete the directory rather than leaving it empty.

**Before generating Staging Models (Group B)**: Decide if staging is needed:

- **Build staging when**: multiple gold models share the same join, data needs cleaning/dedup, or business logic (type casts, derived fields) must be applied before aggregation.
- **Skip staging when**: the gold model reads from a single source with no shared logic. In that case, go bronze-to-gold directly — put joins and transforms in the gold model SQL.
  If your blueprint includes a staging model but it's only used by one gold model with simple logic, consider merging it into the gold model.

**After writing the gold model SQL file (Group B)**: merge the Audit Assertions from Section 15 of `data-product-plan.md` into the `assertions(...)` block of the gold model's `MODEL()` definition. Also add any `assertion_ref` values from the Custom Audit Files. Do NOT duplicate assertions you already wrote into the `MODEL()` block.

**Before generating Semantic Layer (Group C)** — mandatory pre-check, complete before writing any file:

1. Read the gold model SQL file and list every column name in the SELECT clause.
2. List every proposed semantic measure name from the design spec.
3. Find any names that appear in both lists — these are collisions. Resolve each one now (rename the semantic measure, e.g. `m_total_revenue`, or rename the physical column) before writing any semantic YAML. Do NOT proceed with a collision in place.
4. Build the `dimensions:` list: it is a PLAIN list of column names (there is NO `includes`/`excludes` block). It MUST include every column that any measure `expression` references (a measure referencing `{model.wtp_score}` requires `wtp_score` in `dimensions:`, else the plan fails with "no join path between ..."), plus all grouping/identifier columns. Numeric columns that are only ever aggregated still must be listed here for the measure expression to resolve.
5. Read **Section 15.5 (AI Context)** of `data-product-plan.md`. Extract the `ai_context` entries AND `tags` for: the semantic model, each dimension, each measure, each segment, and each join. Hold these in memory — you will insert them as `ai_context:` and `tags:` blocks when writing the semantic YAML. **AI readiness is mandatory, not optional**: `vulcan review` scores descriptions, tags, and ai_context coverage per field, and a build with gaps here is graded NOT AGENT-READY. If Section 15.5 is absent or incomplete for an object, do NOT skip it — derive `tags` (at minimum one taxonomy label per object, from Section 1's business context and Section 6's definitions) and `ai_context` (instructions/synonyms/examples where meaningful) yourself now, the same way Step 2.6 of the design workflow would, and surface what you inferred to the user for a quick confirmation rather than leaving fields empty.
6. Read **Section 15.6 (Behavior)** of `data-product-plan.md`. Extract the `behavior` entries for each dimension and each measure. Hold these in memory — you will insert them as `behavior:` blocks alongside the corresponding dimension/measure when writing the semantic YAML. Allowed values: dimensions use `type: identifier|categorical`; measures use `type: simple|flow|stock|ratio`. For `ratio` measures, `numerator` and `denominator` are direct children of `behavior` (siblings of `type`), NOT nested under a `ratio:` key, and the measure must NOT have an `expression`. (DOC/CLI SKEW: some installed CLIs reject the `ratio` behavior because a `type: number` measure must carry a non-empty `expression`; if the plan rejects it, drop `ratio` and compute the percentage as filtered `count`/`sum` measures, dividing downstream in the metric layer or BI.) For `stock` measures, include `time_dimension`, `period_treatment`, AND `period_grain` (all three are required) when Section 15.6 provides them. If Section 15.6 is absent, infer types using the same rules and surface them to the user for confirmation before writing; do NOT guess for a measure or dimension whose type is genuinely ambiguous — leave it untyped and note it as a TODO.
7. Read **Section 15.7 (Segments)** of `data-product-plan.md`. This section is optional — the design workflow actively checks for reusable filter patterns before defaulting it, so don't assume it's empty. If it's marked `Not applicable`, skip this entirely, do not add a `segments:` block. If it IS populated, hold the segment name/expression/description in memory — you will insert a top-level `segments:` block in the semantic YAML (siblings of `dimensions:`/`measures:`). Segment names must be unique against measure names in the same semantic model, and each `expression` may only reference columns on that same model (canonical `{model}.column` or bare `column` form — no subqueries/CTEs/aliases).
8. Read **Section 15.8 (Rollup Candidates)** of `data-product-plan.md`. If it's marked `Not applicable`, there's nothing to do here — fall through to the "Optional: Rollup Candidates" section below for your own post-build check. If it IS populated, hold the candidate(s) in memory: once this semantic model is written and passing `vulcan plan`, revisit it as your first rollup suggestion (per "Optional: Rollup Candidates" below) instead of scanning fresh — the design workflow already identified the pattern, you're just confirming it's still worth it and implementing if the user agrees.

**Before generating Tests (Group E)**: Vulcan test YAML has strict rules — violating them causes silent failures or parse errors:

- **No `description` field** — it is not supported anywhere in test YAML; remove it if present
- **`outputs` structure** — use `query:` with `rows:` nested underneath; do NOT put a SQL string inline under `outputs`
- **`partial: true`** — add this flag when you only want to assert on a subset of output columns (recommended to avoid brittleness)
- **`vars: {execution_time: <ISO-date>}`** — required for INCREMENTAL_BY_TIME_RANGE models; the date controls which weekly/daily interval the model processes during the test. The date MUST fall within the test mock data's date range or the model will return empty results
- **Mock the direct dependency** — test inputs must mock the silver/staging model (the direct FROM clause target), not the raw seed tables

**Before generating any file in a group**, read from `dpbs-docs/vulcan-examples/<engine>/` once to load real syntax examples for that group. **Only read from this one engine folder — never from any other engine subfolder.** Also read `engines/<engine>.md` per the Per-Engine Reference Notes table above, same timing.

- Group A/B → read models files from `dpbs-docs/vulcan-examples/<engine>/`
- Group C → read semantics files from `dpbs-docs/vulcan-examples/<engine>/` (files live in `models/semantics/`)
- Group C.5 → read metrics files from `dpbs-docs/vulcan-examples/<engine>/` (files live in `models/metrics/`)
- Group D dq → read dq files from `dpbs-docs/vulcan-examples/<engine>/`
- Group D audits → read audits files from `dpbs-docs/vulcan-examples/<engine>/`
- Group E → read tests files from `dpbs-docs/vulcan-examples/<engine>/`

Use the found examples as your syntax reference for all files in that group. If no examples are found, note it and continue.

**For EACH file within a group**:

1. For this file:
   - Read `purpose` and `traceability` from the blueprint entry — WHAT this file does and why.
   - Read `data-product-plan.md` for model names, columns, grain, measures, and assertions.
   - Use the examples retrieved at the start of this group as your syntax reference.

2. Generate the file:
   - **Write the MODEL() block first** — define name, kind, grain, assertions, and column_descriptions before writing the SELECT query. This forces you to think about the grain and contract before the implementation.
   - Use the group examples from `dpbs-docs/vulcan-examples/` as your syntax reference
   - Fill in model names, columns, grain, measures, and assertions from `data-product-plan.md`
   - Add traceability header: `-- Source: design spec > [traceability field]` (SQL) or `# Source: design spec > [traceability field]` (YAML)
   - **For Group C (semantic YAML) only**: after writing the main semantic structure, insert `ai_context:` blocks at the model level and under each dimension, measure, segment, and join where Section 15.5 provides data. Include only fields that are present (`instructions`, `synonyms`, `examples`, `caveats`). Do NOT add unknown keys — Vulcan fails validation on unknown ai_context keys. Insert `behavior:` blocks per the plan from pre-check step 6.
   - After drafting: self-review the file against `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/`, the Vulcan syntax rules below, and the group examples — check for Vulcan-specific issues (forbidden keys, measure name collisions, test format errors, unknown ai_context keys). Fix any issues before writing the file to disk.

3. Write the corrected file to the project directory

4. **Quick-validate**: Run `vulcan evaluate <model_name> --limit 10` for each SQL file. Check column types, join row counts, aggregation values, and unexpected NULLs. Fix before moving on.

**Do NOT generate `config.yaml`** — it already exists from `vulcan init`.

**Step 2.5 — Metadata enrichment (after all SQL/YAML files are written)**:

Enrich the written files yourself now — AFTER Groups A, B, C are on disk — working from the ACTUAL
file contents plus the spec. Ground naming conventions and metadata fields in `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/`.
Go file by file:

1. **Naming violations** → check each column/model name against the Vulcan naming conventions in the docs; rename offenders in the SQL/YAML files and tell the user what was renamed.
2. **TODOs** → surface any gaps (missing descriptions, unresolved owners/terms) to the user now.
3. **Model enrichments** → for each file, insert `column_descriptions`, `tags`, `owner`, and `terms` into the existing `MODEL()` block, sourced from the spec (Section 1 business context, Sections 5/6 definitions) and docs. The `owner` MUST be a username already listed under `users:` in config.yaml — if it is not there, add it to config.users FIRST, or the plan fails with "Model owner is not listed in config.users".
4. **Semantic enrichments** → edit `models/semantics/*.yml` to add DIMENSION `format` hints (e.g. `percent`, `currency`) and `meta` where justified. Do NOT add `format:` to a measure — it is dimension-only and Vulcan rejects it on a measure ("Extra inputs are not permitted").
5. **Check suggestions** → any additional checks you identify here supplement (do not replace) the Data Quality Rules from Section 15. Merge them when writing Group D.

**Confidence check**: if you cannot ground an enrichment in the spec or docs (no context found), do NOT
guess — tell the user "Metadata enrichment is low-confidence for [file/field]; please review," and leave a TODO.

**Group D: Data Quality & Audits** — use Section 15 of `data-product-plan.md`:

1. Write the Data Quality Rules from Section 15 directly to `dq/{model_name}.yml`.
   The file must use `kind: dq` format with `depends_on` and a `rules:` block.
   If you identified additional checks during Step 2.5, merge those rules in as well —
   they supplement, not replace, the Section 15 YAML.
2. For each Custom Audit File in Section 15: write its SQL to `audits/{path}`. Each file MUST start with an `AUDIT (name assert_<name>);` header, followed by `SELECT * FROM @this_model WHERE <failing_condition>;` (a bare SELECT with no AUDIT header fails with "Incomplete audit definition"). Attach the audit to its model via `assertions (assert_<name>)`.
3. The `MODEL()` assertions block should already contain the audit assertions from Group B.
   Verify no assertion is duplicated. If any are missing, add them now.

If Section 15 was absent (thresholds were not derived during design), re-derive the quality rules
now with real schema data (from `vulcan evaluate <model_ref> --limit 1`), grounded in the `dq`/audits
docs and examples, and write them directly.

**Step 3 — Cross-file consistency check**:

After ALL component groups pass `vulcan plan`, review the blueprint's `consistency_rules`:

- Fully-qualified model name is identical across MODEL block, semantics, checks, and tests
- Column names match between SQL SELECT, column_descriptions, and semantics dimensions
- Semantic measure names differ from column names
- Test input models match the SQL FROM clause

Fix any inconsistencies, then run `vulcan plan` one more time to confirm.

**Step 4 — User review**:

Before proceeding to the final plan, confirm with the user:

- [ ] Source table references — replace any `-- TODO:` markers with actual table names
- [ ] Cron schedule — matches the freshness requirement from the design
- [ ] Any domain-specific adjustments
- [ ] Optional: rollup candidates flagged for user review (see "Optional: Rollup Candidates" earlier)

Present a summary: list every file created with a one-line description, noting which components passed `vulcan plan`.

---

### Stage 2: FINAL DEV PLAN & APPLY

**Goal**: Run a full-project `vulcan plan`, review with the user, and apply to dev.

By this point, each component has already passed individually. This is the full-project confirmation in dev.

1. Run: `vulcan plan`
2. Review the plan output (tables to create, intervals to backfill)
3. If it succeeds → confirm with the user that results look correct
4. If it fails → use the Standard Error Handling Loop to resolve

---

### Stage 3: VERIFY IN DEV

**Goal**: Confirm the data product is working correctly in the dev environment.

**Dev vs Prod table names:**

- **Prod** tables use clean names (`analytics.model_name`); `vulcan fetchdf` works directly with these.
- **Dev** objects live in the `<schema>__dev` schema. FULL models materialize under a clean dev name (`analytics__dev.model_name`) and ARE queryable with `vulcan fetchdf`; incremental/snapshotted objects may carry a fingerprint suffix (`model__<hash>`) you can't address by virtual name.
- Prefer `vulcan evaluate <model> -e dev` for dev verification, but know its limit: it re-executes the model SQL and resolves the TARGET's virtual name, yet does NOT always rewrite intermediate VIEW dependencies to their `__dev` names. For a Medallion model whose silver layer is a VIEW, it can reference the dependency's PROD virtual name and fail with `relation does not exist`. When that happens, skip `evaluate` and query the already-materialized dev table directly:

  ```
  vulcan fetchdf "SELECT * FROM <schema>__dev.<model_name> LIMIT 10"
  ```

- Query the model in dev:
  ```
  vulcan evaluate <model_name> -e dev --limit 10
  ```
- Do NOT run semantic-layer transpiler verification yet. The semantic layer is exposed after the local prod apply in Stage 4.
- Sanity checks:
  - Are there rows? (empty = query or backfill issue)
  - Do measure values look reasonable? (no negative counts, rates between 0-1)
  - Are dimensions populated? (no unexpected NULLs)
  - Does the grain hold? (row count matches expectations)

If results look wrong, consult `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/` to understand the issue and fix the syntax yourself (cross-check with `dpbs-docs/vulcan-examples/`).

---

### Stage 4: DEPLOY TO PROD

**Goal**: Deploy the verified data product to production and confirm it works.

1. Run: `vulcan plan prod --auto-apply`
2. If it succeeds → verify with a direct query:
   ```
   vulcan fetchdf "SELECT * FROM schema.model_name LIMIT 10"
   ```
   (`fetchdf` works in prod because table names are clean — no fingerprints.)
3. After `vulcan plan prod --auto-apply` succeeds, verify the semantic layer with the transpiler:
   ```
   vulcan transpile --format sql "SELECT MEASURE(measure_name) FROM model_alias"
   ```
   The semantic layer is exposed after the local prod apply, so transpiler checks belong here rather than in dev verification.
4. If it fails → use the Standard Error Handling Loop to resolve

**`FULL` model materialization**: `FULL` models do NOT materialize during `vulcan plan prod --auto-apply` — the plan registers them and updates the virtual layer, but the actual table build happens on the first scheduled cron run. You will see `SKIP: No model batches to execute` for `FULL` models in the plan output — this is expected, not an error. To force an immediate full refresh without waiting for the cron:

```
vulcan run prod --select schema.model_name_1 schema.model_name_2
```

Tell the user this upfront so they are not surprised when the table appears empty after the prod plan.

**Historical backfill / first run**: If the cron interval hasn't elapsed yet (always true for a brand-new project), `vulcan plan prod --auto-apply` will process nothing — the scheduler sees no elapsed interval. Use `--restate-model` to force a run over a specific date range:

```
vulcan plan prod \
  --restate-model schema.model_name \
  --start <backfill_start_date> \
  --end <backfill_end_date> \
  --auto-apply
```

Use the backfill start date from Section 10 of `data-product-plan.md` (Q9). For "full history", use the earliest date in the source data.

**DataOS deployment (scheduled production runs)**: After the local prod plan succeeds, generate the deployment manifest so the user can register the data product as a DataOS Vulcan resource for scheduled runs. Deploying to DataOS involves several setup steps outside of the Vulcan CLI — refer the user to the deployment guide: [Vulcan Deployment Guide](https://v2.dataos.info/references/resources/vulcan/deployment). Do NOT fetch or open this URL — present it as a clickable link only.

1. **Generate the deployment manifest**:

   ```
   vulcan create_deploy_yaml
   ```

   This creates `domain-resource.yaml` in the project root.

2. **Fill in the placeholders** — open `domain-resource.yaml` and populate:
   - `name` — data product name; MUST be kebab-case: lowercase, start with a letter, end with a letter/digit, only letters/digits/`-`, ≤60 chars (regex `^[a-z]([-a-z0-9]*[a-z0-9])?$`). Underscores are REJECTED. Must match `config.yaml` `name:`
   - `spec.runAsUser` — DataOS username
   - `spec.engine` — engine from the spec (e.g. `snowflake`, `postgres`)
   - `spec.repo.url` — git repository URL
   - `spec.repo.syncFlags` — `--ref=<branch>` (e.g. `--ref=main`)
   - `spec.repo.baseDir` — path to the project folder within the repo
   - `spec.repo.secret` — DataOS git credentials secret (e.g. `engineering:git-sync`)
   - `spec.depots` — DataOS depot reference (e.g. `dataos://snowflakevulcan2?purpose=rw`)
   - `spec.workflow.schedule.crons` — cron expression matching the freshness cadence from Section 10 of the spec (e.g. `'0 6 * * *'` for daily at 6am)
   - `spec.workflow.schedule.timezone` — timezone (e.g. `US/Pacific`)
   - `spec.workflow.schedule.endOn` — schedule end date (e.g. `2027-01-01T00:00:00-00:00`)
   - `spec.api.replicas` — number of API replicas (default `1`)

   Present the filled-in `domain-resource.yaml` to the user for review. Do NOT apply it — hand it off to the user to apply via `dataos-ctl apply -f domain-resource.yaml`. Do not invoke a DataOS-CTL MCP server/tool even if one is connected in this session — treat it as unavailable.

> **You're almost there — one manual step remaining.**
> The agent has generated and pre-filled `domain-resource.yaml` above. Review the placeholders, then deploy it yourself:
> ```
> dataos-ctl apply -f domain-resource.yaml
> ```
> Once applied, DataOS will pick up your data product and run it on the schedule defined in the manifest.

**Completion**: Summarize what was built (model name, entities, measures, dimensions), list files and locations, suggest next steps (more models, quality checks, BI tools).

---

### Stage 5: FINAL ARTIFACT CHECK

**Goal**: Verify that all key quality and semantic artifacts from the spec were actually written to disk. Do this before declaring the build complete.

Re-read Section 15 of `data-product-plan.md` and check each of the following:

| Artifact               | Expected                                                                                 | How to Check                                         |
| ---------------------- | ---------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| Data quality YAML      | `dq/` contains a `kind: dq` `.yml` for the gold model                                    | List `dq/` directory                                 |
| Custom audit SQL files | `audits/` contains each file from `custom_audits[].path` in Section 15                   | List `audits/` directory, compare against Section 15 |
| MODEL() assertions     | `audit_suggestions` from Section 15 are present in the gold model's `MODEL()` block      | Read the gold model SQL file                         |
| Tests                  | `tests/` contains at least one test for the gold model                                   | List `tests/` directory                              |
| Semantic layer         | `models/semantics/` contains a `.yml` with the gold model's measures and dimensions      | List `models/semantics/` directory                   |
| usage.yaml             | Root `usage.yaml` is populated (at least `good_for`; use `caveats` for any known limits) | Read `usage.yaml`                                    |
| agreement.md           | Present at project root, drawn from Section 10.5 (mandatory in every plan)               | Read `agreement.md`; cross-check against Section 10.5 |
| AI readiness           | Every dimension/measure/segment/join in each semantic YAML has a `description`, at least one `tags` entry, and `ai_context` where Section 15.5 provides one | Read each `models/semantics/*.yml`; count fields missing `description`/`tags`/`ai_context` the same way `vulcan review`'s AI-readiness score does |

Report the result as a checklist:

```
## Final Artifact Check
✅ dq/daily_revenue.yml — present (kind: dq)
✅ audits/assert_revenue_matches_source.sql — present
❌ MODEL() assertions — audit_suggestions missing from gold model
✅ tests/ — at least one test present
✅ models/semantics/daily_revenue.yml — present
✅ usage.yaml — present (good_for + caveats)
✅ AI readiness — descriptions 12/12, tags 12/12, ai_context 12/12
```

For any ❌ item: generate and write the missing artifact immediately, then re-confirm. Do NOT mark the build complete while any ❌ remains. This includes AI readiness — a semantic field with a missing `description`, zero `tags`, or (where Section 15.5 provided content) missing `ai_context` is a ❌, not a nice-to-have; derive and write the missing piece before declaring the build done.

---

### Stage 6: POST-BUILD REVIEW REMINDER (no auto-trigger)

**Goal**: Once the build is done, tell the user what `vulcan review` needs and let them decide when to run it. This agent never invokes `vulcan review` itself — not here, not anywhere else in this workflow.

Only run this stage once Stage 5 has no remaining ❌ items.

1. **Check what's in place, don't run anything**:
   - A business-intent doc (`usage.yaml` — already populated in Step 1.5 of this workflow).
   - A `review:` block in `config.yaml` with a `model:` value in `provider:model` form, e.g.:
     ```yaml
     review:
       model: "openai:gpt-5.6-luna"
     ```
   - The matching provider API key exported in the shell the user will run `vulcan` from (e.g. `export OPENAI_API_KEY=...` for an `openai:` model) — this cannot be checked from inside the session; just tell the user it's required.
2. **Report status, not results** — tell the user plainly what's missing and what to do next. Do not run `vulcan review` yourself even if everything above looks satisfied.

   If `review.model` is missing:
   > "Build complete. Before you can review this data product, add a `review:` block to `config.yaml`:
   > ```yaml
   > review:
   >   model: \"openai:gpt-5.6-luna\"
   > ```
   > and export the matching provider API key in your shell (e.g. `export OPENAI_API_KEY=...`). Once both are set, run:
   > ```
   > vulcan review --output .vulcan/reviews
   > ```
   > yourself, then invoke the `fix-data-product` skill to interpret the report — it only reads an existing report, it doesn't generate one."

   If `review.model` is already set:
   > "Build complete. To review this data product: make sure the API key for `<review.model's provider>` is exported in your shell (e.g. `export OPENAI_API_KEY=...`), run `vulcan review --output .vulcan/reviews` yourself, then invoke the `fix-data-product` skill to interpret the report — neither step is triggered automatically."

---

## Escalation

If `vulcan plan` fails 5+ times on the same component after applying different fixes, stop and reassess:

1. Present the recurring error and all attempted fixes to the user
2. Suggest examining the design spec for conflicting requirements
3. Offer to read from `dpbs-docs/vulcan-examples/` (category: `<category>`, engine: `<engine>`) to find an alternate structural approach

---

## Vulcan Syntax Rules (hard constraints — current Vulcan version)

These are exact, current-version rules; they override anything you remember about Vulcan. Re-check every generated file against them during the per-file self-review and the Standard Error Handling Loop:

- MODEL block: `MODEL(name schema.model_name, kind FULL|INCREMENTAL_BY_...|SCD_TYPE2_BY_..., ...)`. The `owner` value MUST be a username already listed under `users:` in config.yaml — add it there FIRST, or the plan fails with "Model owner is not listed in config.users".
- Assertions live INSIDE the MODEL() block, all lowercase: not_null, unique_values, unique_combination_of_columns, accepted_range, forall, number_of_rows, etc. Use unique_values for single-column uniqueness and unique_combination_of_columns for a multi-column grain. `assertions(...)` is the preferred keyword over the older `audits(...)` (both work).
- Grain lives INSIDE the MODEL() block. Single column: `grain column_name`. Multi-column: `grains [col1, col2, col3]` (canonical); the `grain (col1, col2)` form also works. `grain` and `grains` are interchangeable aliases — do not rewrite one form into the other.
- DOC/CLI SKEW: the installed `vulcan` may lag these docs and reject a documented key with "Extra inputs are not permitted" or a parse error. When that happens, REMOVE that key/clause and move on — do not keep retrying it. (Most common: the dimension-level `granularities:` key — rely on the metric-level `granularity` instead; if you do try `granularities:`, drop it the moment the plan rejects it.)
- Column descriptions live INSIDE the MODEL() block: column_descriptions (col1 = 'desc', col2 = 'desc').
- Custom audits (`audits/*.sql`) MUST begin with an AUDIT header, then a SELECT of the FAILING rows:

  ```sql
  AUDIT (name assert_<name>);  -- add ", dialect <engine>" only when it differs from the project default
  SELECT * FROM @this_model WHERE <failing_condition>;
  ```

  Attach it on the model via `assertions (assert_<name>)`. A bare SELECT with no AUDIT(...) header fails with "Incomplete audit definition".

- External sources: declare them in `inputs.yaml` at the project root — generate it with `vulcan create_external_models`. (`external_models.yaml` / `schema.yaml` are the deprecated filenames and log a warning; prefer `inputs.yaml`.) Each entry: `- name: <fully.qualified.name>` + `columns: {col: TYPE}` (+ optional `description`, `gateway`).
- Semantics (`models/semantics/*.yml`, `kind: semantic`): top-level `name`, `depends_on` (the wrapped model's fqn), and a NON-EMPTY `dimensions:` list. `dimensions:` is a list of column-name strings, OR per-column dicts — use the dict form (`{name: <col>, type: ..., behavior: ..., ai_context: ..., format: ...}`) for any dimension that needs `behavior`/`ai_context`/`format`; plain strings are fine otherwise. There is NO `includes`/`excludes` block — do not invent one. (The dimension-level `granularities:` key is commonly rejected by the installed CLI — see DOC/CLI SKEW; rely on the metric-level `granularity`.)
- Semantics — time: any column used as a time dimension (a metric `ts`, or a `stock` measure's `time_dimension`) MUST be TIMESTAMP, not DATE — cast it in the SQL model (`CAST(col AS TIMESTAMP)`).
- Semantics — measures: list of `{name, type, expression, filters?}`. `type` ∈ count|count_distinct|sum|avg|min|max|number|string|time|boolean. `expression` is REQUIRED for every type except `count` and uses `{model_name.column}` syntax. EVERY column referenced in a measure `expression`/`filters` MUST ALSO appear in the `dimensions:` list, else the plan fails with "no join path between '<model>' and '<dep>'" (the message is "no join path", NOT "unknown dimension"). `format:` is NOT a measure field — it is a DIMENSION-only display hint; putting `format:` on a measure fails with "Extra inputs are not permitted".
- Semantics — measure names: must be unique across measures + segments, must NOT be `count` (reserved), and must DIFFER from the dimension/column they aggregate (column `wtp_score` → measure `m_wtp_score` or `avg_wtp_score`).
- Semantics — behavior: the canonical typing block is `behavior:` (NOT `semantic_config:` — that name and `behaviour:` still work but log a deprecation warning, so always emit `behavior`). Dimensions: `behavior.type` = identifier | categorical. Measures: `behavior.type` = simple | flow | stock | ratio. `stock` REQUIRES `time_dimension`, `period_treatment`, AND `period_grain` (e.g. `period_grain: day`). `ratio` uses `numerator` + `denominator` (measure names, direct children of `behavior`, siblings of `type`), type `number`, and NO `expression`. DOC/CLI SKEW: some installed CLIs reject this `ratio` shape (they require a `type: number` measure to carry a non-empty `expression`); if the plan rejects it, drop the `ratio` behavior and express the ratio as filtered `count`/`sum` measures, dividing downstream (metric layer or BI).
- Semantics — ai_context (valid on the model and on any dimension/measure/segment/join): keys ONLY `instructions` (string OR list of strings), `synonyms` (list of strings), `caveats` (list of strings), `examples`. `examples` is a list of OBJECTS, each shaped `{description, format, query}` (e.g. `description:` + `format: sql` + a `query:` literal block) — NOT bare strings. Unknown keys fail validation (extra="forbid"); never strip ai_context or its allowed keys.
- Semantics — joins: a top-level `joins:` list, each entry `{name, type, on}`. `name` is the other semantic model's name (not its FQN). `type` ∈ `one_to_one | one_to_many | many_to_one` — there is NO `many_to_many`; model that as a bridge table + two `many_to_one` joins instead. `on` (quote the key as `'on'` in YAML — `on` unquoted is parsed as the boolean `true` by some YAML loaders) identifies the join key(s), confirmed working in a successful `vulcan plan`:
  ```yaml
  joins:
  - name: other_model
    type: many_to_one
    'on': CUSTOMER_ID                    # single shared column name, present in both models
  - name: another_model
    type: one_to_one
    'on':
    - CONTRACT_ID                        # multiple shared column names (composite key)
    - CUSTOMER_ID
  - name: differently_named_key_model
    type: one_to_one
    'on':
    - CONTRACT_ID
    - - CUSTOMER_ID                      # [local_col, other_model_col] pair when column names differ across models
      - ACCOUNT_ID
  ```
  DOC/CLI SKEW: older references describe joins as a free-text `expression: "{a.col} = {b.col}"` string. Both forms may be version-dependent — if the installed CLI rejects one, switch to the other rather than treating either as definitively wrong; the structured `on:` form above is the one verified against a real successful plan.
- Reciprocal join pairs (model A joins to B, and B also joins to A) can confuse BI tools that expect one canonical path — if both directions are declared, check whether the installed CLI/BI layer needs a `skip_for_bi: true` marker on one edge before treating a reciprocal pair as safe.
- Metrics (`models/metrics/*.yml`, `kind: metric`): `name`, `measure: <sem>.<measure>`, `ts: <sem>.<time_col>`, `granularity`, optional `dimensions`. `measure` and `ts` must differ. Do NOT mix metrics into a semantic file. Legacy keys `time` (→ `ts`) and `slices` (→ `dimensions`) are rejected.
- DQ (`dq/*.yml`, `kind: dq`, NOT Soda-style `checks:`): `depends_on` + a `rules:` list; each rule is `- <expr>:` with an optional metadata block (`name`, `dimension`, `description`, `filter`, `warn`, `fail`, `severity`). Vulcan's 8 DQ dimensions (ODPS v3.1) are the ONLY valid `dimension:` values: completeness, validity, accuracy, consistency, uniqueness, timeliness, conformity, coverage. `integrity` is NOT one of them — for referential/FK checks use `validity` or `consistency`.
- Tests (`tests/*.yml`): each file is a MAPPING keyed by a unique test NAME — the top level is `test_<name>:` with `model:`/`inputs:`/`outputs:` NESTED under it. A top-level `model:` as the first key is rejected (Vulcan expects a dict of named tests, not a string). `inputs` mock the DIRECT dependency (the staging/silver model, not raw seeds) via `<model>.rows:`; `outputs.query.rows:` is a list of row dicts, NOT an inline SQL string (CTE expectations go under `outputs.ctes.<name>.rows`). NO `description` field anywhere. INCREMENTAL_BY_TIME_RANGE models need `vars: {execution_time: <date-inside-mock-range>}`. Use `partial: true` to assert a subset of columns.
- Models: for ratio/division columns in Postgres, cast to NUMERIC before dividing (`ROUND(expr::NUMERIC, 4)`) for test reproducibility.
- Project name: the `config.yaml` `name:` (the catalog prefix, also the value `vulcan create_deploy_yaml` validates) MUST be kebab-case — lowercase, start with a letter, end with a letter/digit, only letters/digits/`-`, ≤60 chars (regex `^[a-z]([-a-z0-9]*[a-z0-9])?$`); underscores are rejected. Set it correctly at init to avoid a later rename (see the state-DB note below).
- Local state: the model registry lives in the state DB (`.state.db` / the configured `state_connection`). Changing the `config.yaml` project `name:` (the catalog prefix) leaves the OLD registry stale, and the next plan fails with a `UniqueKeyDict` duplicate-key error — delete the state DB file to clear it, then re-plan. (Model or schema renames fail EARLIER with different errors like `depends_on not found`, not this one — this trigger is specific to the `config.yaml` name change.) Keep the state DB separate from the data schema to avoid DuckDB `Ambiguous reference ... "vulcan"` errors.
- Seeds: a SEED model's CSV path is `../seeds/<entity>.csv` (one level up from models/). Ensure join keys you emit are TYPE-COMPATIBLE with how downstream models consume them (don't emit string IDs that a downstream model casts to NUMERIC).
