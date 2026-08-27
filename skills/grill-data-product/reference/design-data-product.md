---
name: design-data-product
description: >-
  Full design workflow for Vulcan/DataOS data products. Guides the agent from a vague idea
  to a validated data-product-plan.md spec through structured batches of questions, entity
  inference, table discovery, model-kind classification, grain definition, quality rules, and
  ai_context/behavior drafting. Use when the user wants to design a Vulcan data product, asks
  about data-product-plan.md, or starts a vulcan design session.
disable-model-invocation: true
---

# Design Data Product — Vulcan Design Workflow

Design data products for Vulcan/DataOS. Be methodical, artifact-driven, and assumption-averse. Take the user from a vague idea to a validated, implementation-ready design spec.

> **How this skill is installed**: The skills and grounding docs are installed by running `npx dataproduct-builder-skills` in the project root. This copies the skill files into the IDE folder (`.cursor/skills/`, `.claude/skills/`, or `.codex/skills/`) and installs `dpbs-docs/vulcan-docs/`, `dpbs-docs/dataos-philosophy/`, and `dpbs-docs/vulcan-examples/` into the project. If at any point the grounding docs are missing or a `dpbs-docs/` read returns nothing, tell the user to run `npx dataproduct-builder-skills` in their project root to install them.

---

## Core Principles

1. **Never invent information** — if documentation doesn't support a claim, say "Unknown." Never invent column names, table names, schema details, or documentation links.
2. **Never reason beyond the docs** — if a concept, syntax, or pattern isn't explicitly covered in `dpbs-docs/vulcan-docs/`, `dpbs-docs/dataos-philosophy/`, or `dpbs-docs/vulcan-examples/`, don't deduce or extrapolate an answer from general knowledge. Say it's undocumented and ask the user or point to the closest documented alternative. Do NOT search the web or consult dataos.info (or any other online DataOS/Vulcan documentation site) as a fallback — it may not match this project's bundled version. `https://v2.dataos.info` is the one exception — it's the correct, current documentation domain and may be used.
3. **Never skip requirements** — always gather context before jumping to solutions. Don't skip stages.
4. **Ground everything in the docs** — before using any Vulcan concept, syntax, or pattern in output, confirm it against the Vulcan documentation in `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/` (search your indexed workspace and read the relevant page). For concrete code syntax, also read from `dpbs-docs/vulcan-examples/`. When in doubt, look it up — never rely on memory.
5. **Build the artifact progressively** — create and update `data-product-plan.md` at every stage. Document decisions as you go.
6. **Mark assumptions explicitly** — use the `[Assumption]` tag for anything not confirmed by the user.
7. **Vulcan is anti-pipeline** — never use "pipeline." Use "model DAG", "data product", or "model layers" instead.

The data product you design will be implemented in this standard Vulcan project layout:

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

## Resource Selection Quick Reference

Use these resources proactively — grounding every decision in the docs is mandatory, not optional.

| Situation                           | What to do                                                                         | When                                                                           |
| ----------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Any Vulcan concept mentioned        | Read the relevant page(s) in `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/`     | BEFORE using the concept in any output                                         |
| Any design decision                 | Reason from the docs + confirmed requirements; record it in `data-product-plan.md` | AFTER each batch of questions                                                  |
| Need implementation pattern         | read from `dpbs-docs/vulcan-examples/` (category=..., engine=...)                       | BEFORE generating any code or recommending patterns                            |
| Quality checks for the data product | Derive them yourself from the spec columns, grounded in the `dq`/audits docs       | At end of Stage 3.5 (Step 2.5) after spec is finalized                         |
| Profile confirmed source tables     | `table_profile`                                                                    | AFTER columns are fetched for each confirmed table (Batch 2 — Table Discovery) |

When a docs page you used has a reference URL, show it to the user as "Reference docs:".

---

## Workflow

### Stage 0: PREREQUISITES CHECK (Mandatory — Run Before Anything Else)

**Goal**: Confirm the two required tools are available before starting the design session. If either is missing, stop and help the user resolve it.

#### Check 1 — Data Product MCP (`dataproduct-mcp/api/v1`)

Verify the Data Product MCP server is reachable. Call `search(index="data_product_search_index")` (zero arguments). This is the fastest round-trip that proves the MCP is live.

- **Pass**: the call returns any result (even an empty list) without an auth or connection error → proceed to Check 2.
- **Fail**: the call errors, times out, or returns an authentication/connection error →

> "To design a data product I need access to the Data Product MCP (`dataproduct-mcp/api/v1`), but I can't reach it right now.
>
> **To fix this:**
> 1. Open **Cursor Settings → MCP** and confirm a server named `dataproduct-mcp` (or similar) is listed and enabled.
> 2. If it is not listed, add it — your workspace admin should have the connection URL and credentials.
> 3. Once the server shows a green status, restart this session and try again.
>
> I'll wait here until the MCP is reachable."

Do NOT proceed past this check if the MCP is unreachable.

---

#### Check 2 — `search` Tool

Confirm the `search` tool is available in the current session. The same call used in Check 1 already exercises `search` — if it succeeded, this check passes automatically.

If Check 1 passed but `search` later returns `tool not found` or a similar "unknown tool" error at any point during the session:

> "The `search` tool is no longer available in this session. This tool is required for table discovery and data product lookup.
>
> **To fix this:**
> 1. Confirm the Data Product MCP server is still connected in **Cursor Settings → MCP**.
> 2. Refresh or restart the session, then re-run the skill.
>
> I'll pause here until `search` is available."

---

#### Prerequisites Result

Once both checks pass, display exactly this banner before starting Stage 1:

> **Prerequisites check passed.**
> - Data Product MCP (`dataproduct-mcp/api/v1`): connected
> - `search` tool: available
>
> Ready to begin the design session.

Then continue to Stage 1.

---

### Stage 1: DISCOVER

**Goal**: Understand what the user wants to build.

- Listen to the user's initial request
- If they use unfamiliar terms, read the relevant page in `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/` to clarify
- Ask probing questions: "What problem are you solving?", "Who consumes this?", "What decisions does it enable?"

No artifact yet — this is exploratory conversation.

---

### Stage 2: DEFINE (Iterative Batches)

**Goal**: Gather complete requirements through structured questions, building the spec progressively.

Ask questions in **3 batches**. After EACH batch, synthesize what you learned (grounded in the docs) and update `data-product-plan.md`. Skip questions the user already answered. Probe deeper on vague answers before moving on.

**Important Distinctions** (clarify for the user if needed):

- **Measures** = aggregations (COUNT, SUM, AVG, DISTINCT COUNT). This INCLUDES derived calculations like `avg_order_value = total_revenue / order_count` — those are derived measures, not metrics.
- **Metrics** = a measure tracked over a time dimension. In Vulcan/DataOS, a metric is a business time series (e.g., "Revenue by Segment over order_date"). Every metric must specify which measure it tracks and which time dimension it uses.
- **Grain** = the primary key of the output model — the unique combination of columns that identifies one row. Think of it as: "If I were to write a PRIMARY KEY constraint on this table, what columns would it include?" Example: grain of (date, customer_segment, region) means one row per day × segment × region, and the combination of those three columns is unique. If unclear, mark as UNKNOWN and add to Open Questions.

---

**Batch 1 — What & Why (Q1–Q4)**

_Persona: business user / product owner. Keep all questions in plain business language. Do NOT ask about entities, tables, columns, joins, or data sources in this batch._

| #   | Question                                                                                                                      | Fills Section                       |
| --- | ----------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| 1   | What pain points or gaps exist today that this data product is meant to address?                                              | 1. Business Context — Problem       |
| 2   | In one sentence, what does this data product do and what decisions does it enable?                                            | 1. Business Context — Use Case      |
| 3   | Who are the primary consumers of this data product — which teams, roles, or tools will use it, and what will they do with it? | 1. Business Context — Consumers     |
| 4   | What are the key questions this data product should answer, and what numbers or trends matter most?                           | 1. Business Context — Key Questions |

After answers → create `data-product-plan.md` with Section 1 filled, rest marked "To be defined."

---

**Batch 2 — Data & Structure (Q5, Q6 + Recommendations)**

_Persona: analyst / data-aware user. Most of this batch is the assistant doing the work and presenting recommendations for confirmation, not asking the user to enumerate things from scratch._

**Q5 — Engine (mandatory)**

| #   | Question                                                                                                     | Fills Section   |
| --- | ------------------------------------------------------------------------------------------------------------ | --------------- |
| 5a  | Where is your data located at? (e.g., `snowflake`, `postgres`, `databricks`, `lakehouse`)                    | 2. Data Sources |
| 5b  | Which engine does this data product use? (e.g., `snowflake`, `postgres`, `redshift`, `databricks`, `duckdb`) | Engine          |

Do NOT proceed past Q5 without a confirmed data source (Q5a) and engine (Q5b). Once Q5b is confirmed, store it as `<ENGINE>`. For ALL example lookups in this session, only read from `dpbs-docs/vulcan-examples/<ENGINE>/` — never from any other engine subfolder.

---

**[Checkpoint — Entity Inference]**

Infer the core entities from Q1–Q4 answers. Do NOT ask the user "what are your entities?" — derive them, then confirm.

Present them as:

> "Based on what you've described, the core things this data product is about seem to be: **Entity1**, **Entity2**, **Entity3**. Does that sound right? Would you add or remove anything?"

If inference is low-confidence (fewer than 2 clear entities, or ambiguous nouns), ask a focused follow-up question rather than guessing. Do NOT move on until entities are confirmed.

---

**[Recommendation — Table Discovery]**

Before calling `search`, display this disclaimer exactly once:

> **Data Discovery Disclaimer:**
> - Table search and profiling are experimental features — results may be incomplete, include false matches, or reflect stale data. Treat all table recommendations and profile statistics as directional signals and confirm before proceeding.
> - The `search` tool can only find datasets that have been scanned by the **Nilus Metadata Workflow**. If you expect to use a specific database, schema, or dataset, make sure the Nilus Metadata Workflow has been run on it first — otherwise it will not appear in search results.

**Data source gate**: Do NOT call `search` until Q5a (data source) is confirmed. If data source is not yet confirmed, stop and ask for it before proceeding.

Once entities are confirmed, call `search(index="table_search_index", query=<entity keywords + Q4 metric keywords>, data_source=<Q5a>)` for each entity. Present the recommendations:

> "To build this data product, here are my recommended tables:
>
> - **table_name_1** → for Entity1 — _reason why_
> - **table_name_2** → for Entity2 — _reason why_
> - **table_name_3** → for Entity3 — _reason why_
>
> Do these look right? Any you'd swap or add?"

If the search response includes dataset links, always display them to the user alongside the table recommendations.

After tables are confirmed, call `search(index="table_search_index", detail_level="columns", data_source=<Q5a>)` for each confirmed table to fetch real columns. Do NOT use `[Assumption]` tags for any column name returned by this call.

**[Profiling — mandatory after column fetch]**

For each confirmed table, call `table_profile(table_fqn=<fqn from search>, detail_level="column")` to get row counts, null rates, and value distributions. The FQN is returned by `search` when `detail_level="columns"` — use it directly, do NOT construct it manually.

Present a brief summary to the user:

> "Here is a quick profile of the confirmed tables:
>
> - **table_name_1**: [row count], [any columns with high null %], [notable distributions]
> - **table_name_2**: [row count], [any columns with high null %], [notable distributions]
>
> Anything here that affects the design — e.g., sparse columns you'd rather exclude, or a time column that looks stale?"

Use the profile output to:

- Flag any column with high null % before it is referenced in a measure or join key — surface it as an `[Assumption]` if you proceed anyway
- Validate the proposed grain column(s) — a high distinct % confirms uniqueness; a low one signals a likely aggregation grain
- Inform freshness expectations — if the latest data timestamp is old, flag it as an open question

If `table_profile` returns "profiler has not been run", note it and continue — do NOT block on it.

**Fallback — no matches or user rejects all**:

> "I couldn't find any tables matching your data. This might be because the Nilus Metadata Workflow hasn't been run on the database or schema where your data lives."

> "Alternatively, you can provide seed data as a CSV — add it to the `seeds/` folder and share the filename."
> Register the seed CSV as the source for that entity.

**Gate**: every confirmed entity must have either a confirmed table (with fetched columns) or a registered seed CSV before moving on.

---

**[Checkpoint — Model Kind Classification]** (mandatory, once per confirmed table)

Read the **model kinds** page in `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/` now — before any architecture decisions are made.

Then, for each confirmed source table, classify it using this decision rule:

| Condition                                                                                             | Kind                                        | Rationale                                                        |
| ----------------------------------------------------------------------------------------------------- | ------------------------------------------- | ---------------------------------------------------------------- |
| Semantic model from another DP, used **as-is** (no changes to measures, dimensions, or grain)         | `EXTERNAL`                                  | Vulcan metadata stub — no transformation, no ownership transfer  |
| Semantic model from another DP, needs **modifications** (add/drop measure or dimension, change grain) | New model (`FULL` / `VIEW` / `INCREMENTAL`) | Must redefine to reflect changes — EXTERNAL cannot be customized |
| Raw source table outside any DP                                                                       | `EXTERNAL`                                  | Read-only source — Vulcan should not manage it                   |
| Table produced and owned by this DP                                                                   | `FULL` / `VIEW` / `INCREMENTAL` / `SEED`    | This DP holds the transformation responsibility                  |

Present the classification to the user:

> "Here is how I've classified each source:
> | Table | Owned By | Kind | Reason |
> |-------|----------|------|--------|
> | [table_name] | [this DP / other DP / raw source] | [EXTERNAL / FULL / VIEW / ...] | [reason] |
>
> Does this look right? Any ownership or kind to change?"

**Gate**: Do NOT proceed to join recommendations until every source has a confirmed Kind.

---

**[Recommendation — Joins]**

Using fetched column lists, infer join keys (e.g., a `customer_id` present in both `orders` and `customers`). Present them:

> "Based on the tables you've selected, here are the suggested joins:
>
> - `table_a.column` → `table_b.column` _(Entity1 to Entity2)_
> - `table_b.column` → `table_c.column` _(Entity2 to Entity3)_
>
> Do these joins look correct? Any missing or incorrect?"

**Fallback — join key unclear**:

> "I couldn't find a clear join key between **[Table A]** and **[Table B]**. What column links them?"

---

**Q6 — Population filters**

| #   | Question                                                                                                                                                                                   | Fills Section                                |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------- |
| 6   | What business rules filter which records are included **before or during** the join? (e.g. only active devices, exclude failed installations, only certain channels). If none, say "none". | 4. Entity Relationships — Population Filters |

---

**[Recommendation — Measures, Dimensions, Metrics]**

From Q4 (key questions / numbers) + confirmed tables + columns, derive and present:

- **Measures** (aggregations — including derived ratios/scores): e.g., `release_success_rate = successful_installs / total_installs`
- **Dimensions** (slice/filter axes): e.g., `device_type`, `region`, `release_version`
- **Metrics** (measure over a time dimension): e.g., `installation_failure_rate over install_date`

> "Does this look right? Anything to add, remove, or adjust?"

**Formula probe (mandatory for non-trivial measures)**: scan recommended measures for any ratio, score, derived value, or bucketed measure. For each one, ask:

> "For **[measure name]** — what's the exact formula? Specifically: what's the numerator, what's the denominator, and are there any row-level filters (e.g. only certain product types)?"
> "For **[score/bucket measure]** — how is it computed: static thresholds in a lookup table, dynamic percentile bucketing (like NTILE), or something else?"
> Do NOT proceed until every ratio/score/bucket measure has an explicit formula in the spec.

---

**[Recommendation — Grain]**

Synthesize grain from confirmed dimensions + measures + metrics:

> "Based on the above, one row in this data product represents: **[e.g., one device per release per day]**. Does that sound right?"

**Key construction probe (mandatory when grain key is composite)**: if the grain involves two or more source columns combined into one identifier, ask:

> "Is `[grain key]` a direct column in the source, or is it constructed from multiple fields? If constructed, describe the formula (e.g. concatenation, padding, hashing)."
> Document the construction logic in Section 8 of the plan.

---

After Batch 2 → synthesize the confirmed answers + recommendations (grounded in the docs) → update plan with sections 2-9.

---

**[Recommendation — Modeling Approach]** _(between Batch 2 and Batch 3)_

Based on entities, joins, grain, measures, and dimensions, recommend a modeling approach. Only two options are supported today:

- **Star Schema** — clear fact table (events / transactions at the grain) with surrounding dimension tables. Best when you have one central measure-bearing entity and many descriptive dimensions.
- **Medallion Architecture** — Bronze (raw) → Silver (cleaned/joined) → Gold (aggregated). Best when you have multiple sources needing staged transformation, shared join logic across several gold models, or layered cleaning.

Present as:

> "Based on your data structure, I recommend **[Star Schema | Medallion Architecture]** because **[rationale tied to entities/joins/grain/consumption]**. Which would you like to go with?"
>
> - Star Schema
> - Medallion Architecture

If neither fits cleanly, flag it as an open question rather than forcing a choice. Record the chosen approach in Section 13 of the plan.

---

**Batch 3 — Delivery & Freshness (Q7–Q9)**

_Persona: business user or analyst — these questions are simple enough for both._

| #   | Question                                                                                                                                                                                 | Fills Section                                     |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| 7   | Where will this data product be consumed? (e.g., AI agents or agentic applications — e.g. Claude, Cursor, or a custom MCP client; BI dashboard, API, ad-hoc queries, embedded in an app) | 10. Consumption & Freshness — Consumption Pattern |
| 8   | How often does the data need to be refreshed? (e.g., real-time, hourly, daily, weekly)                                                                                                   | 10. Consumption & Freshness — Freshness           |
| 9   | Do you need historical data loaded from the start, and if so, how far back? And separately: once built, should it keep generating new periods going forward (e.g. through the current date), or is the whole time range fixed/bounded (e.g. a closed historical snapshot)? | 10. Consumption & Freshness — Backfill / Ongoing Horizon |

After answers → update plan with section 10.

---

**Rules for all batches**:

- Keep a running record of all confirmed values in `data-product-plan.md`: problem, use_case, consumers, key_questions, data_source, engine, entities, tables, model_kinds (each with table, kind = EXTERNAL|FULL|VIEW|INCREMENTAL|SEED, and owned_by = this DP / <other-dp-name> / raw source), joins, filters, measures, dimensions, metrics, grain, modeling_approach, consumption, freshness, backfill.
- After each batch, actively look for gaps and open questions yourself — do not wait for the user to volunteer them. Ground every inference in `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/`.
- Summarize what you understood and confirm with the user before moving to the next batch

---

### Stage 2.5: REVIEW & CONFIRM (Final Checkpoint)

**Goal**: After all three batches, surface what was assumed and what is still unresolved — do NOT ask the user to volunteer these.

**[Assumptions — assistant generated]**

Walk through the conversation and list every `[Assumption]` tag you applied (e.g., join semantics, freshness defaults, scope cuts, missing definitions you filled in). Present them to the user:

> "Here are the assumptions I've made while putting this together:
>
> - [Assumption 1]
> - [Assumption 2]
> - ..."

**[Open Questions — assistant generated]**

List remaining gaps you could not resolve (low-confidence inferences, missing schema info, ambiguous filters, etc.):

> "Here are things still unclear or unresolved:
>
> - [ ] [Gap 1]
> - [ ] [Gap 2]"

Then ask:

> "Do these assumptions hold? Anything incorrect or missing?"

Iterate with the user until they confirm. Persist confirmed assumptions to Section 11 and unresolved items to Section 12 of the plan.

---

### Stage 3: FINALIZE & VALIDATE

**Goal**: Polish the spec, and validate with the user.

**Finalize**:

- Review the spec for completeness: all sections filled, no UNKNOWN grain, assumptions tagged
- There is no YAML-contract section in this template. `build-data-product` reads directly from
  the prose sections (1–13) plus Section 15/15.5/15.6 — do not generate a separate YAML restate
  of sections 1–10. (The only place that format is used is `build-data-product`'s own Spec
  Intake step, for normalizing an external spec — not part of this workflow's output.)
- Section 10.5 (Data Agreement) is mandatory — confirm it's drafted for every plan (not left as
  a placeholder), using the structure from `dpbs-docs/vulcan-docs/configurations/agreement.md`,
  tailored to this product's actual consumers and data. This is a house policy stricter than
  Vulcan's own optional default — say so if the user asks why.
- Section 15.8 (Rollup Candidates) — confirm it's either populated with a genuine candidate or
  explicitly marked `Not applicable`; don't leave it blank.

**Validate with the user**:

- Walk through the complete design
- Key questions: "Does this grain make sense?", "Any missing measures or dimensions?", "Do the marked assumptions hold?", "Any constraints I missed?"
- Iterate until the user confirms the design is solid
- Add the validation checklist (section 16) and update status to "Validated" (verify Section 15 is populated before marking complete)

**Stall handling**: If the user can't answer a critical question or you hit uncertainty:

- **Blocked on a question** (especially grain): Surface what's blocking, offer 2-3 concrete options grounded in the docs and real examples (read from `dpbs-docs/vulcan-examples/`). If still unresolved, document as an open question with a recommended default and move on.
- **Unknown concept**: Be transparent. Tell the user you couldn't find it in `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/`, ask if it's a custom term.
- **Vague requirements**: State specifically what you need to proceed. If you can't get clarity, provide a partial spec with grain marked UNKNOWN.
- **No matching examples**: Say so, and offer the closest alternatives from `dpbs-docs/vulcan-examples/`.

---

### Stage 3.5: VERIFY YOUR UNDERSTANDING (Mandatory Checkpoint)

**Goal**: Ensure YOU fully understand all concepts before handing off to build.

Complete all steps before handing off to build.

**Step 1 — Extract ALL technical terms from the spec:**

Create two checklists from your `data-product-plan.md`, then read the relevant page(s) in `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/` for each item (search your indexed workspace) and confirm your understanding:

**Vulcan Concepts Checklist** (minimum required — read the docs page for each):

- [ ] grain
- [ ] measures
- [ ] metrics
- [ ] dimensions
- [ ] entities
- [ ] model kinds — already reviewed in the Batch 2 Model Kind Classification checkpoint; confirm it was incorporated into Section 13 Kind column
- [ ] assertions
- [ ] semantic layer
- [ ] the freshness cadence from Q8 (e.g., "daily", "hourly", "incremental")

**Business Concepts Checklist** (extract from your spec):

- [ ] each business term from measures/metrics
- [ ] each domain-specific term

Read the `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/` pages for every Vulcan concept above; for business terms, confirm the definition with the user if the docs don't cover them.

**Step 2 — Retrieve reference patterns:**

Read files from `dpbs-docs/vulcan-examples/<Q5b>/` only — this is the confirmed engine folder. Do NOT read from any other engine subfolder. Browse within it for the relevant category (models, semantics, dq, checks, metrics, audits, tests).

- [ ] Read model files from `dpbs-docs/vulcan-examples/<Q5b>/` — see how real models and grain are structured
- [ ] Read semantics files from `dpbs-docs/vulcan-examples/<Q5b>/` — see how measures/dimensions are defined
- [ ] Read metrics files from `dpbs-docs/vulcan-examples/<Q5b>/` — see how metrics reference measures

If NO examples found: tell the user, and fall back to the patterns documented in `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/`.

**Step 2.5 — Derive quality rules**:

Derive the quality rules yourself from the finalized spec — there is no tool for this. Ground the
rule types and YAML structure in the `dq` and audits pages of `dpbs-docs/vulcan-docs/` and `dpbs-docs/dataos-philosophy/`, and read dq and audits files from `dpbs-docs/vulcan-examples/<Q5b>/` only
for concrete syntax. Because the model is not yet deployed, mark any numeric threshold as
[Estimated] — these MUST be replaced with real values after deployment (re-derive from
`vulcan evaluate` output during build).

Work from the spec columns, grain, and measures to propose:

- **Audit assertions** (blocking) — e.g. `not_null` on grain keys, `unique_combination_of_columns` on the grain, `accepted_range` on rates/ratios.
- **Custom audit files** — cross-model validations that don't fit a single `MODEL()` assertion.
- **Checks** (non-blocking monitoring) — a `kind: dq` rules block, one dimension per rule from Vulcan's 8 DQ dimensions (completeness, validity, accuracy, consistency, uniqueness, timeliness, conformity, coverage — `integrity` is NOT valid; use validity/consistency for referential checks).
- **SLOs** — freshness/quality targets tied to Section 10.
- **Coverage gaps** — anything you could not cover, and why.

**Present the results to the user for review BEFORE writing to the spec.** Show a summary like:

```
## Quality Rules Recommendation

### Audit Assertions (blocking)
[list each audit_suggestion]

### Custom Audit Files
[list each custom_audit: path + audit_name]

### Checks (non-blocking monitoring)
[brief list of check names and dimensions — do NOT dump the full YAML here]

### SLOs
[list each slo.name + threshold + rationale]

### Coverage Gaps
HIGH: [gap.area] — [gap.recommendation]
MEDIUM: [gap.area] — [gap.recommendation]

Do these quality rules look right? Any to add, remove, or adjust before I lock them into the spec?
```

**Wait for the user's response.** If they approve (or say "looks good" / provide no objection), proceed.
If they request changes, incorporate their feedback and re-present before writing.

**Only after confirmation**: populate **Section 15: Quality Rules (Recommended)** in `data-product-plan.md` using the Section 15 template from the artifact. Map your derived rules (audit assertions, custom audits, data quality rules, SLOs, coverage gaps) into the corresponding subsections. The data quality rules must be written as a `kind: dq` YAML block under the "Data Quality Rules" subsection.

---

**Step 2.6 — Draft ai_context and tags for semantic objects**

AI readiness is graded on three axes, and all three are mandatory here, not optional extras: every semantic object needs a `description` (already required elsewhere in this workflow), `tags` (taxonomy), and `ai_context` (instructions/synonyms/examples). Do not let any dimension, measure, segment, or join reach Section 15.5 with zero tags or zero ai_context content — a field with genuinely nothing meaningful to add still gets at least one taxonomy `tag` (see below), because "no tags" is exactly the gap `vulcan review`'s AI-readiness score flags.

From the conversation so far (business terms from Q1–Q4, consumer info from Q3, key questions from Q4, confirmed dimension/measure names), draft both `ai_context` and `tags` for each semantic object.

For the **semantic model** (top-level):

- `instructions`: 2–3 sentences on how to interpret this model — what a row represents, which measure to use for which question type. May be a single string OR a YAML list of strings when multiple distinct instructions apply.
- `synonyms`: alternate names consumers or LLMs might use to refer to this data product
- `examples`: 2–3 example queries this data product answers, each as an OBJECT `{description, format, query}` — `description` is the natural-language question (pull verbatim from Q4 where they fit), `format` is e.g. `sql`, `query` is the semantic/SQL query that answers it. Vulcan requires ai_context examples to be objects, NOT bare strings.
- `tags`: 2–4 taxonomy labels for the product as a whole (domain area, subject matter, e.g. `revenue`, `retention`, `executive-reporting`)

For each **dimension**:

- `synonyms`: alternate column names a consumer might say (e.g. `"plan"` for `plan_type`, `"tier"` for `customer_segment`)
- `caveats`: (optional) list of interpretation warnings — add only when the dimension has a meaningful misuse risk (e.g. "do not group by raw timestamp; use the date granularity", "values include soft-deleted records")
- `tags`: 1–3 taxonomy labels classifying what kind of dimension this is (e.g. `identifier`, `geography`, `time`, `categorical`) — every dimension gets at least one tag, even a purely structural one

For each **measure**:

- `synonyms`: alternate phrasings for this measure (e.g. `"bookings"` for `total_revenue`)
- `examples`: example queries for this measure, each an OBJECT `{description, format, query}` (`description` = the NL question, `query` = the query that uses this measure)
- `caveats`: (optional) list of interpretation warnings — add only when the measure has aggregation-specific pitfalls or misuse risks (e.g. "do not sum ARR across daily rows in a range", "pin start_date to period end", "query numerator and denominator separately when a time grain is present")
- `tags`: 1–3 taxonomy labels (e.g. `revenue`, `financial`, `arr`, `retention`, `growth`) — every measure gets at least one tag

For **segments** and **joins**: add `synonyms` and/or `instructions` only where the spec provides enough context to be meaningful, but `tags` is still mandatory — at minimum one label naming what the segment/join represents (e.g. `cohort`, `region-mapping`).

Present the full draft to the user:

> "Here is the ai_context and tags I've drafted for the semantic layer. Review and edit before I lock it into the spec:
> [show each object with its proposed ai_context fields and tags]
> Does this look right? Any synonyms missing, instructions to tweak, tags off, or examples to swap?"

Wait for confirmation. Incorporate any edits. Only after the user approves: populate **Section 15.5: AI Context** in `data-product-plan.md` using this structure:

````markdown
## 15.5 AI Context (for semantic layer)

### Semantic Model

```yaml
instructions: |
  [text]
# OR, when multiple instructions apply, use a YAML list:
# instructions:
#   - "..."
#   - "..."
synonyms:
  - "..."
examples:
  - description: "..."   # the question in natural language
    format: sql
    query: |
      SELECT ...         # the semantic/SQL query that answers it
tags:
  - "..."
```

### Dimensions

- **dimension_name**:
  - `synonyms`: ["..."]
  - `caveats`: ["..."]  (optional — only when the dimension has a misuse risk)
  - `tags`: ["..."]  (mandatory — at least one taxonomy label)

### Measures

- **measure_name**:
  - `synonyms`: ["..."]
  - `examples`: `[{description: "...", format: sql, query: "SELECT ..."}]`
  - `caveats`: ["..."]  (optional — only when aggregation pitfalls or misuse warnings apply)
  - `tags`: ["..."]  (mandatory — at least one taxonomy label)

### Granularities / Segments / Joins

- [include every object; `synonyms`/`instructions` only where meaningful, but `tags` always present]
````

Keep `ai_context` (including `tags`) in the plan only — it is consumed by the build workflow, not re-derived.

---

**Step 2.7 — Draft behavior (typed dimensions and measures)**

`behavior` declares the semantic _type_ of each dimension and measure. It is required for typed dimensions and strongly recommended for all measures. Draft it now from the conversation so far so the build workflow can read it from the spec instead of guessing.

For each **dimension** carrying semantic meaning (i.e. used for slicing/filtering, not just a column passthrough), assign:

- `behavior.type: identifier` — IDs, primary keys, foreign keys (e.g. `customer_id`, `order_id`)
- `behavior.type: categorical` — enums, statuses, grouping fields (e.g. `plan_type`, `region`, `status`)

If a dimension's role is genuinely ambiguous, leave it untyped and surface it as an Open Question — do NOT guess.

For each **measure**, assign one of:

- `behavior.type: simple` — additive count/sum that does not need special time treatment
- `behavior.type: flow` — accumulates over time (events/transactions, e.g. `total_orders`, `total_signups`)
- `behavior.type: stock` — point-in-time value that should NOT be summed across days (e.g. `total_arr`, `mrr`, `active_users`). For stock measures, also note the `time_dimension`, `period_treatment` (typically `last`), and `period_grain` (e.g. `day`/`month`) — all three are required when the build writes the measure.
- `behavior.type: ratio` — computed from numerator and denominator measures. Use the formula already captured in Q5 of the Measures recommendation (or the ratio formula probe). For ratio measures, record the `numerator` and `denominator` measure names — these are siblings of `type` under `behavior`, NOT nested under a `ratio:` key, and the measure must NOT have an `expression`. **Required, not optional**: also record a `formula_fallback` field (a sibling of `behavior`, not nested inside it) — the exact formula from Section 6's Definition column, including numerator, denominator, and any row filters. Some Vulcan CLIs reject the `ratio` behavior shape (they require a `type: number` measure to carry an `expression`); `formula_fallback` is what lets build compute the ratio directly (filtered `count`/`sum` measures + downstream division) without needing `numerator`/`denominator` to exist as standalone measures anywhere else in the spec.

If a measure's type is genuinely ambiguous (e.g. could be flow or stock without more business context), leave it untyped and surface it as an Open Question.

Present the full draft to the user:

> "Here is the behavior I've drafted — these declare the semantic _type_ of each dimension and measure. Review and edit before I lock it into the spec:
> [show each dimension with its proposed type; each measure with its proposed type and (for ratio) numerator + denominator; flag any items left untyped]
> Does this look right? Any types to flip, or ambiguous ones we should resolve now?"

Wait for confirmation. Incorporate any edits. Only after the user approves: populate **Section 15.6: Behavior** in `data-product-plan.md` using the template under "Artifact Template" below.

Keep `behavior` in the plan only — it is consumed by the build workflow, not re-derived.

---

**Step 2.8 — Segments (optional — but actively look for them, don't just wait to be told)**

Segments are reusable named filters on the semantic model — still not mandatory, but don't leave
this to chance. Before defaulting to `Not applicable`, actively scan for a candidate:

- Re-read every example query you just drafted in Step 2.6 (`ai_context.examples`) and every
  Population Filter in Section 4 — if the same filter combination (e.g. one categorical dimension
  = a fixed value, or two combined) shows up more than once, that's a candidate, whether or not
  the user ever said the word "segment."
- If you find one, propose it explicitly rather than silently skipping it:

  > "`[dimension] = [value]` (+ `[dimension2] = [value2]`) came up more than once while drafting
  > this — want it as a reusable named segment (e.g. `[suggested_name]`)?
  > A) Yes — save it as `[suggested_name]`
  > B) Yes — but a different name/rule (tell me)
  > C) No — ad hoc filtering only, don't add it"

- Only mark Section 15.7 `Not applicable` after you've actually looked and asked — not because
  nothing repeated to look at, and not just because the user didn't bring it up unprompted.

---

**Step 2.9 — Rollup candidates (optional — but actively look for them too)**

Rollups pre-aggregate a semantic model for performance (`enable_rollup: true` in `config.yaml`,
see `dpbs-docs/vulcan-docs/models/semantic-models/rollups.md`) — still not mandatory, and the
final decision still belongs at build time once real query volume exists. But if the spec you've
already drafted makes an obvious repeated query shape visible right now, flag it instead of
staying silent until `build-data-product` maybe notices later:

- Look at Section 7's metrics and Section 6's measures: does one of them get grouped by a time
  bucket (the metric's time dimension) plus one or two Section 5 dimensions, in a way that
  clearly matches Section 10's Consumption Pattern (e.g. a recurring dashboard)?
- If yes, propose it as a **candidate for build time**, not a decision to make now:

  > "`[measure]` grouped by `[time_dimension]` (+ `[dimension]`) looks like the primary way this
  > will be queried. Want me to flag it as a rollup candidate for `build-data-product` to revisit
  > once there's real data volume to justify it?
  > A) Yes — flag `[measure] × [time_dimension] × [dimension]`
  > B) No — skip, decide at build time with real usage data"

- If flagged, populate **Section 15.8: Rollup Candidates** with the measure/dimension/time bucket
  and a one-line reason. If nothing looks like an obvious pattern, or the user says no, mark
  Section 15.8 `Not applicable` — never enable a rollup or touch `config.yaml` here; this section
  only ever records a candidate for `build-data-product` to act on.

---

**Step 3 — Document your verification:**

Create a summary showing you completed the work:

````
## VERIFICATION SUMMARY

### Concepts Verified:
- Grain: [definition from dpbs-docs/vulcan-docs and dpbs-docs/dataos-philosophy]
- Measures: [list with explanations for each]
- Metrics: [list — each as measure + time dimension, e.g., "revenue_by_segment = total_revenue over order_date"]
- Dimensions: [list with types]
- Model Kind: [chosen kind with rationale from dpbs-docs/vulcan-docs and dpbs-docs/dataos-philosophy]
- Assertions: [types needed based on grain/measures]

### Model Selection Reasoning (WHY):

**Target Metrics from Spec:**
- [Metric 1]: [business purpose] → needs [specific measure(s)]
- [Metric 2]: [business purpose] → needs [specific measure(s)]

**Model Architecture Decision:**
- **Why Gold Model**: [grain + aggregation pattern justify this model]
- **Why Silver Model (if needed)**: [shared joins/logic across X gold models, or cleaning needed for Y reason]
- **Why Bronze Models**: [need to ingest from X sources because gold requires columns A, B, C]

**Rationale Chain:**

```
Target Metrics → Required Measures → Required Dimensions → Required Grain → Model Layers Needed
Example: "revenue_by_segment" → "total_revenue, order_count" → "customer_tier, region, date" → "one row per date+tier+region" → Gold (aggregated) + Silver (joined orders+customers) + Bronze (raw sources)
```

### Uncertainties Resolved:
- [Any concepts that were unclear initially and are now clear]

### Ready for Build:
- All Vulcan concepts explained
- All business terms clarified
- Examples found matching use case
- Model reasoning documented (WHY these models)
- No [Needs Clarification] tags in spec
````

**Only proceed to handoff when you can show this summary to the user.**

**Step 4 — Handoff**: Confirm all items in Section 16 (Validation Checklist) are checked and the verification summary above is complete. Then direct the user to the `build-data-product` skill — the `data-product-plan.md` with its YAML contract and verification summary is the input for that workflow.

---

## Artifact Template: `data-product-plan.md`

Create this file after Batch 1 and progressively fill it through the workflow.

````markdown
# Data Product Plan: [Name]

## Status: [Requirements Gathering | Design Complete | Validated]

## Created: [Date]

---

## 1. Business Context

- **Problem**: [Q1 — pain points or gaps this data product addresses]
- **Use Case**: [Q2 — one sentence: what it does + decisions enabled]
- **Consumers**: [Q3 — teams / roles / tools and what they'll do with it]
- **Key Questions / Metrics**: [Q4 — questions to answer, numbers/trends that matter]

## 2. Data Sources

- **Engine**: [Q5 — e.g., snowflake, postgres, redshift, databricks, duckdb]

| Source                                                                | Description   | Owner            | Key Columns                                                                                    |
| --------------------------------------------------------------------- | ------------- | ---------------- | ---------------------------------------------------------------------------------------------- |
| [confirmed from Table Discovery recommendation, or seed CSV filename] | [description] | [owner if known] | [col1 (type), col2 (type), … — populated from search(detail_level="columns"); "N/A" for seeds] |

## 3. Entities

[confirmed from Entity Inference checkpoint — core things: customer, product, subscription, etc.]

## 4. Entity Relationships and Joins

| Join                        | Left Entity  | Right Entity    | Join Key      | Purpose                                     |
| --------------------------- | ------------ | --------------- | ------------- | ------------------------------------------- |
| [e.g., Orders -> Customers] | [raw_orders] | [raw_customers] | [customer_id] | [Need customer_tier and region for slicing] |

**Population Filters** (business rules applied before/during joins — from Q6):

- [e.g., status = 'Active' — only active accounts]
- [e.g., order_flag = 'Y' — only customers who have ordered]
- [e.g., channel != 'National' — exclude national channel accounts]

## 5. Dimensions

| Dimension                                         | Definition            | Entity   |
| ------------------------------------------------- | --------------------- | -------- |
| [from Measures/Dimensions/Metrics recommendation] | [business definition] | [entity] |

## 6. Measures (Aggregations)

| Measure               | Definition                                         | Row Filter                   | Computation Method           | Entity   |
| --------------------- | -------------------------------------------------- | ---------------------------- | ---------------------------- | -------- |
| [from recommendation] | [exact formula — denominators required for ratios] | [WHERE condition, or ‘none’] | [SUM / ratio / NTILE / etc.] | [entity] |

## 7. Metrics (Measure over Time)

| Metric                | Measure                  | Time Dimension | Description                        |
| --------------------- | ------------------------ | -------------- | ---------------------------------- |
| [from recommendation] | [which measure to track] | [time field]   | [business question as time series] |

## 8. Grain

> What does one row represent?

[from Grain recommendation — UNKNOWN if not yet defined]

**Grain Key Construction**: [How the grain key is built if composite or derived — e.g. LPAD(site,4) || LPAD(customer_no,7). Write "natural key" if it’s a direct column.]

## 9. Measure and Metric Reasoning

**Rationale chain** (traces from business question to required data):

[Metric] -> needs [Measure(s)] -> needs [Column(s)] -> from [Source Entity]

**Key design decisions**: [Why each measure uses its aggregation type, why any metric is derived, any columns requiring joins — link back to section 4]

## 10. Consumption & Freshness

- **Consumption Pattern**: [Q7 — dashboard / API / ad-hoc / embedded]
- **Freshness**: [Q8 — real-time / hourly / daily / weekly]
- **Backfill**: [Q9 — how far back, or "none"]
- **Ongoing Horizon**: [Q9 — does the model keep extending forward past the backfill window (e.g. through `CURRENT_DATE`), or is the time range permanently fixed/bounded? Default to "extends forward" unless the user states the range is a closed historical snapshot. This is the field `build-data-product` must use to decide whether any generated month/date spine gets a dynamic upper bound or a literal one — the backfill start/end dates above describe the initial load only, never a permanent ceiling on future runs unless this line says so explicitly.]

## 10.5 Data Agreement

**Mandatory for every plan** — house policy, stricter than Vulcan's own default guidance (Vulcan
itself treats `agreement.md` as optional; this project always generates one). Draft it using the
structure from `dpbs-docs/vulcan-docs/configurations/agreement.md`, tailored to this specific data
product — never boilerplate, never copy the doc's illustrative example verbatim.

- **Who this covers**: [consumers from Section 1 — teams, roles, tools, and any AI agent acting on their behalf]
- **What you can use it for**: [bullet list, grounded in Section 1's use case + Section 7's metrics]
- **What you can't use it for**: [bullet list — at minimum: no redistribution outside named consumers; no use as a system of record if this product is analytical-only; no re-identification if anything here is anonymized or aggregated from PII]
- **How to handle it**: [where it may live — approved tools only; PII-minimization notes if Section 2/5 involves personal data]
- **How long you can keep it**: [retention rule for extracts — default to Section 10's freshness cadence unless a stricter rule applies]
- **Crediting it**: [how a derived report should cite this data product + the refresh date used]
- **If the rules aren't followed**: [consequence — typically: access logged, treated as a governance issue]
- **How long this applies**: [duration — typically: for as long as access is held, and for anything retained afterward]

## 11. Assumptions

- [Assumption] [populated from Final Checkpoint — Review & Confirm]

## 12. Open Questions

- [ ] [populated from Final Checkpoint — unresolved gaps]

## 13. Model Architecture

| Layer    | Model Name                             | Kind     | Purpose                                                                       | Sources                                               |
| -------- | -------------------------------------- | -------- | ----------------------------------------------------------------------------- | ----------------------------------------------------- |
| External | [catalog.schema.customer_intelligence] | EXTERNAL | [Semantic model from customer-intelligence DP — used as-is, no modifications] | [customer-intelligence DP]                            |
| Bronze   | [raw.raw_orders]                       | SEED     | [Load orders CSV]                                                             | [seeds/raw_orders.csv]                                |
| Silver   | [staging.stg_orders_enriched]          | VIEW     | [Join orders + customers + products]                                          | [raw.raw_orders, raw.raw_customers, raw.raw_products] |
| Gold     | [analytics.daily_sales]                | FULL     | [Daily aggregation for dashboard]                                             | [staging.stg_orders_enriched]                         |

**Architecture decisions**:

- **Why EXTERNAL**: [e.g., "customer_intelligence owned by another DP, no modifications needed — reference as metadata stub only"]
- **Why silver/staging**: [e.g., "3 sources need joining, shared join logic"]
- **Why [model kind]**: [e.g., "Daily aggregation, manageable data volume"]
- **Why not INCREMENTAL**: [e.g., "Table size doesn't warrant it yet"]

## 15. Quality Rules (Recommended)

### Audit Assertions (blocking — add to MODEL() assertions block at build time)

- [populated at Stage 3.5 Step 2.5]

### Custom Audit Files (cross-model validation — write to audits/ at build time)

- [populated at Stage 3.5 Step 2.5]

### Data Quality Rules (non-blocking monitoring — write to dq/{model_name}.yml at build time)

```yaml
kind: dq
name: <model_name>_dq
depends_on: schema.model_name
rules: [rules you derived in Stage 3.5 Step 2.5]
```

### SLOs

- [populated at Stage 3.5 Step 2.5]

### Coverage Gaps (address at build time)

- [populated at Stage 3.5 Step 2.5]

## 15.5 AI Context (for semantic layer)

[populated at Stage 3.5 Step 2.6 — ai_context for model, dimensions, measures, segments, joins]

## 15.6 Behavior (typed dimensions and measures)

[populated at Stage 3.5 Step 2.7 — read by the build workflow; build should NOT re-derive these]

### Dimensions

```yaml
- dimension_name:
    behavior:
      type: identifier   # or: categorical
```

- [omit dimensions with no semantic role; mark genuinely ambiguous ones as untyped + add to Open Questions]

### Measures

```yaml
- measure_name:
    behavior:
      type: simple       # or: flow | stock | ratio
      # For stock (all three required):
      #   time_dimension: <time_dim_name>
      #   period_treatment: last
      #   period_grain: <day|week|month|...>
      # For ratio (required, siblings of `type`, NOT under a `ratio:` key):
      #   numerator: <numerator_measure_name>
      #   denominator: <denominator_measure_name>
      #   (ratio measures must NOT have an `expression`)
    formula_fallback: <REQUIRED for ratio measures — the exact formula from Section 6's
      Definition column, e.g. "cancelled_subs / active_subs_at_month_start">
      # sibling of `behavior`, not nested inside it — lets build compute the ratio directly
      # if the installed CLI rejects the `ratio` behavior shape
```

- [mark genuinely ambiguous measures as untyped + add to Open Questions]

## 15.7 Segments (optional — reusable named filters)

Not mandatory. Populate only if a genuinely reusable, business-named filter surfaced during
grilling (e.g. "high value accounts", "at risk users") — something consumers will slice by
repeatedly, not a one-off ad hoc filter. If nothing like that came up, leave this section as:
`Not applicable — no reusable segment surfaced.` Do not manufacture one to fill the section.

```yaml
- segment_name:
    expression: "{model.column} <condition>"   # must reference only this semantic model's columns
    description: <what this represents, in business terms>
```

## 15.8 Rollup Candidates (optional — recommendations for build-data-product)

Optional. Populate only if Step 2.9 found an obvious repeated query pattern (a measure grouped by
a time bucket plus one or two dimensions) and the user agreed to flag it. This section only ever
records a *candidate* — it does not enable rollups or touch `config.yaml`; `build-data-product`
decides whether to actually build one once real data exists. If nothing surfaced, leave this as:
`Not applicable — no rollup candidate surfaced.`

```yaml
- rollup_name:
    measures: [measure_name]
    dimensions: [dimension_name]
    time_dimension: <time_dim_name>
    granularity: <day|week|month|...>
    reason: <why this looks like the primary query pattern>
```

## 16. Validation Checklist

- [ ] Goal and consumers confirmed by stakeholder
- [ ] Data sources verified accessible
- [ ] Grain explicitly defined (not UNKNOWN)
- [ ] Measures vs Metrics distinction clear
- [ ] Entity relationships and joins documented
- [ ] Measure/metric reasoning documented
- [ ] Model architecture decided and documented
- [ ] All EXTERNAL models identified, ownership confirmed, and documented in Section 13
- [ ] All [Assumption] tags reviewed with stakeholder
- [ ] Open questions resolved or documented as out-of-scope
- [ ] Quality rules reviewed and added to spec (Section 15) — format is kind: dq
- [ ] AI context AND tags drafted and confirmed for every semantic object — model, dimensions, measures, segments, joins (Section 15.5) — no object left with zero tags
- [ ] Semantic types (behavior) drafted and confirmed (Section 15.6) — or genuinely ambiguous ones moved to Open Questions
- [ ] Every ratio measure in Section 15.6 has a formula_fallback tied to its Section 6 definition
- [ ] Segments (Section 15.7) — actively checked for a repeated filter pattern (Step 2.8), not
  just left to chance; populated or correctly marked not applicable
- [ ] Rollup Candidates (Section 15.8) — actively checked for a repeated query pattern (Step 2.9),
  not just left to chance; populated or correctly marked not applicable
- [ ] Data Agreement (Section 10.5) — drafted for this specific product (mandatory, every plan);
  not a placeholder, not copied verbatim from the docs example
- [ ] Verification Summary (Stage 3.5 Step 3) is written into this file, not just shown in chat
- [ ] Ready for implementation → proceed to the build-data-product skill
````
