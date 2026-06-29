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

---

## Core Principles

1. **Never invent information** — if documentation doesn't support a claim, say "Unknown." Never invent column names, table names, schema details, or documentation links.
2. **Never skip requirements** — always gather context before jumping to solutions. Don't skip stages.
3. **Ground everything in the docs** — before using any Vulcan concept, syntax, or pattern in output, confirm it against the Vulcan documentation in `docs/vulcan-book/` (search your indexed workspace and read the relevant page). For concrete code syntax, also call `retrieve_examples`. When in doubt, look it up — never rely on memory.
4. **Build the artifact progressively** — create and update `data-product-plan.md` at every stage. Document decisions as you go.
5. **Mark assumptions explicitly** — use the `[Assumption]` tag for anything not confirmed by the user.
6. **Vulcan is anti-pipeline** — never use "pipeline." Use "model DAG", "data product", or "model layers" instead.

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
| Any Vulcan concept mentioned        | Read the relevant page(s) in `docs/vulcan-book/`                                   | BEFORE using the concept in any output                                         |
| Any design decision                 | Reason from the docs + confirmed requirements; record it in `data-product-plan.md` | AFTER each batch of questions                                                  |
| Need implementation pattern         | `retrieve_examples(file_category=..., engine=...)`                                 | BEFORE generating any code or recommending patterns                            |
| Quality checks for the data product | Derive them yourself from the spec columns, grounded in the `dq`/audits docs       | At end of Stage 3.5 (Step 2.5) after spec is finalized                         |
| Profile confirmed source tables     | `table_profile`                                                                    | AFTER columns are fetched for each confirmed table (Batch 2 — Table Discovery) |

When a docs page you used has a reference URL, show it to the user as "Reference docs:".

---

## Workflow

### Stage 1: DISCOVER

**Goal**: Understand what the user wants to build.

- Listen to the user's initial request
- If they use unfamiliar terms, read the relevant page in `docs/vulcan-book/` to clarify
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

Do NOT proceed past Q5 without a confirmed data source (Q5a) and engine (Q5b).

---

**[Checkpoint — Entity Inference]**

Infer the core entities from Q1–Q4 answers. Do NOT ask the user "what are your entities?" — derive them, then confirm.

Present them as:

> "Based on what you've described, the core things this data product is about seem to be: **Entity1**, **Entity2**, **Entity3**. Does that sound right? Would you add or remove anything?"

If inference is low-confidence (fewer than 2 clear entities, or ambiguous nouns), ask a focused follow-up question rather than guessing. Do NOT move on until entities are confirmed.

---

**[Recommendation — Table Discovery]**

Before calling `search`, display this disclaimer exactly once:

> **Data Discovery Disclaimer:** Table search and profiling are experimental features — results may be incomplete, include false matches, or reflect stale data. Treat all table recommendations and profile statistics as directional signals and confirm before proceeding.

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

> "I couldn't find relevant tables for **[entity]**. You can provide seed data as a CSV — add it to the `seeds/` folder and share the filename."
> Register the seed CSV as the source for that entity.

**Gate**: every confirmed entity must have either a confirmed table (with fetched columns) or a registered seed CSV before moving on.

---

**[Checkpoint — Model Kind Classification]** (mandatory, once per confirmed table)

Read the **model kinds** page in `docs/vulcan-book/` now — before any architecture decisions are made.

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
| 9   | Do you need historical data loaded from the start, and if so, how far back?                                                                                                              | 10. Consumption & Freshness — Backfill            |

After answers → update plan with section 10.

---

**Rules for all batches**:

- Keep a running record of all confirmed values in `data-product-plan.md`: problem, use_case, consumers, key_questions, data_source, engine, entities, tables, model_kinds (each with table, kind = EXTERNAL|FULL|VIEW|INCREMENTAL|SEED, and owned_by = this DP / <other-dp-name> / raw source), joins, filters, measures, dimensions, metrics, grain, modeling_approach, consumption, freshness, backfill.
- After each batch, actively look for gaps and open questions yourself — do not wait for the user to volunteer them. Ground every inference in `docs/vulcan-book/`.
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
- Add the YAML contract (section 14) to `data-product-plan.md` (section 15 will be populated by Step 2.5)

**Validate with the user**:

- Walk through the complete design
- Key questions: "Does this grain make sense?", "Any missing measures or dimensions?", "Do the marked assumptions hold?", "Any constraints I missed?"
- Iterate until the user confirms the design is solid
- Add the validation checklist (section 16) and update status to "Validated" (verify Section 15 is populated before marking complete)

**Stall handling**: If the user can't answer a critical question or you hit uncertainty:

- **Blocked on a question** (especially grain): Surface what's blocking, offer 2-3 concrete options grounded in the docs and real examples (`retrieve_examples`). If still unresolved, document as an open question with a recommended default and move on.
- **Unknown concept**: Be transparent. Tell the user you couldn't find it in `docs/vulcan-book/`, ask if it's a custom term.
- **Vague requirements**: State specifically what you need to proceed. If you can't get clarity, provide a partial spec with grain marked UNKNOWN.
- **No matching examples**: Say so, and offer the closest alternatives from `retrieve_examples`.

---

### Stage 3.5: VERIFY YOUR UNDERSTANDING (Mandatory Checkpoint)

**Goal**: Ensure YOU fully understand all concepts before handing off to build.

Complete all steps before handing off to build.

**Step 1 — Extract ALL technical terms from the spec:**

Create two checklists from your `data-product-plan.md`, then read the relevant page(s) in `docs/vulcan-book/` for each item (search your indexed workspace) and confirm your understanding:

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

Read the `docs/vulcan-book/` page for every Vulcan concept above; for business terms, confirm the definition with the user if the docs don't cover them.

**Step 2 — Retrieve reference patterns:**

`retrieve_examples` takes a `file_category` (one of: models, semantics, dq, checks, metrics, audits, tests) and an `engine` — it returns real files of that type for the dialect. Always pass `engine=<Q5b>`.

- [ ] `retrieve_examples(file_category="models", engine=<Q5b>)` — see how real models and grain are structured
- [ ] `retrieve_examples(file_category="semantics", engine=<Q5b>)` — see how measures/dimensions are defined
- [ ] `retrieve_examples(file_category="metrics", engine=<Q5b>)` — see how metrics reference measures

If NO examples found: tell the user, and fall back to the patterns documented in `docs/vulcan-book/`.

**Step 2.5 — Derive quality rules**:

Derive the quality rules yourself from the finalized spec — there is no tool for this. Ground the
rule types and YAML structure in the `dq` and audits pages of `docs/vulcan-book/`, and use
`retrieve_examples(file_category="dq", engine=<Q5b>)` and `retrieve_examples(file_category="audits", engine=<Q5b>)`
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

**Step 2.6 — Draft ai_context for semantic objects**

From the conversation so far (business terms from Q1–Q4, consumer info from Q3, key questions from Q4, confirmed dimension/measure names), draft `ai_context` for each semantic object.

For the **semantic model** (top-level):

- `instructions`: 2–3 sentences on how to interpret this model — what a row represents, which measure to use for which question type. May be a single string OR a YAML list of strings when multiple distinct instructions apply.
- `synonyms`: alternate names consumers or LLMs might use to refer to this data product
- `examples`: 2–3 example queries this data product answers, each as an OBJECT `{description, format, query}` — `description` is the natural-language question (pull verbatim from Q4 where they fit), `format` is e.g. `sql`, `query` is the semantic/SQL query that answers it. Vulcan requires ai_context examples to be objects, NOT bare strings.

For each **dimension**:

- `synonyms`: alternate column names a consumer might say (e.g. `"plan"` for `plan_type`, `"tier"` for `customer_segment`)
- `caveats`: (optional) list of interpretation warnings — add only when the dimension has a meaningful misuse risk (e.g. "do not group by raw timestamp; use the date granularity", "values include soft-deleted records")

For each **measure**:

- `synonyms`: alternate phrasings for this measure (e.g. `"bookings"` for `total_revenue`)
- `examples`: example queries for this measure, each an OBJECT `{description, format, query}` (`description` = the NL question, `query` = the query that uses this measure)
- `caveats`: (optional) list of interpretation warnings — add only when the measure has aggregation-specific pitfalls or misuse risks (e.g. "do not sum ARR across daily rows in a range", "pin start_date to period end", "query numerator and denominator separately when a time grain is present")

For **segments** and **joins**: add `synonyms` and/or `instructions` only where the spec provides enough context to be meaningful. `instructions` may be a string or a list of strings. Skip if there is nothing useful to add.

Present the full draft to the user:

> "Here is the ai_context I've drafted for the semantic layer. Review and edit before I lock it into the spec:
> [show each object with its proposed ai_context fields]
> Does this look right? Any synonyms missing, instructions to tweak, or examples to swap?"

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
```

### Dimensions

- **dimension_name**:
  - `synonyms`: ["..."]
  - `caveats`: ["..."]  (optional — only when the dimension has a misuse risk)

### Measures

- **measure_name**:
  - `synonyms`: ["..."]
  - `examples`: `[{description: "...", format: sql, query: "SELECT ..."}]`
  - `caveats`: ["..."]  (optional — only when aggregation pitfalls or misuse warnings apply)

### Granularities / Segments / Joins

- [only include objects where there is meaningful content]
````

Keep `ai_context` in the plan only — it is consumed by the build workflow, not re-derived.

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
- `behavior.type: ratio` — computed from numerator and denominator measures. Use the formula already captured in Q5 of the Measures recommendation (or the ratio formula probe). For ratio measures, record the `numerator` and `denominator` measure names — these are siblings of `type` under `behavior`, NOT nested under a `ratio:` key, and the measure must NOT have an `expression`. NOTE: some Vulcan CLIs reject the `ratio` behavior (they require a `type: number` measure to carry an `expression`), so ALSO keep the explicit formula here — numerator, denominator, and any row filters — so the build can fall back to filtered `count`/`sum` measures + downstream division if the installed CLI rejects `ratio`.

If a measure's type is genuinely ambiguous (e.g. could be flow or stock without more business context), leave it untyped and surface it as an Open Question.

Present the full draft to the user:

> "Here is the behavior I've drafted — these declare the semantic _type_ of each dimension and measure. Review and edit before I lock it into the spec:
> [show each dimension with its proposed type; each measure with its proposed type and (for ratio) numerator + denominator; flag any items left untyped]
> Does this look right? Any types to flip, or ambiguous ones we should resolve now?"

Wait for confirmation. Incorporate any edits. Only after the user approves: populate **Section 15.6: Behavior** in `data-product-plan.md` using the template under "Artifact Template" below.

Keep `behavior` in the plan only — it is consumed by the build workflow, not re-derived.

---

**Step 3 — Document your verification:**

Create a summary showing you completed the work:

````
## VERIFICATION SUMMARY

### Concepts Verified:
- Grain: [definition from docs/vulcan-book]
- Measures: [list with explanations for each]
- Metrics: [list — each as measure + time dimension, e.g., "revenue_by_segment = total_revenue over order_date"]
- Dimensions: [list with types]
- Model Kind: [chosen kind with rationale from docs/vulcan-book]
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

## 14. Design Specification — YAML Contract

```yaml
name: [product_name]
version: 1.0
engine: [Q5 — e.g., snowflake]

goal: [business goal]
consumers:
  - [consumer 1]
  - [consumer 2]

entities:
  - name: [entity_name]
    grain: [what one row represents]

entity_relationships:
  - left: [orders]
    right: [customers]
    join_key: [customer_id]
    purpose: [customer attributes for segmentation]

measures:
  - name: [measure_name]
    definition: [aggregation logic]
    entity: [tied to which entity]

metrics:
  - name: [metric_name]
    measure: [which measure to track over time]
    time_dimension: [time field, e.g., order_date]
    description: [business question as a time series]

dimensions:
  - name: [dimension_name]
    type: [string/date/number]
    entity: [tied to which entity]

freshness:
  cadence: [daily/hourly/real-time]
  expected_by: [e.g., "6am UTC"]
  backfill: [how far back if needed]

consumption:
  pattern: [dashboard/API/ad-hoc/embedded]
```

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
```

- [mark genuinely ambiguous measures as untyped + add to Open Questions]

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
- [ ] YAML contract parseable and complete
- [ ] Quality rules reviewed and added to spec (Section 15) — format is kind: dq
- [ ] AI context drafted and confirmed (Section 15.5)
- [ ] Semantic types (behavior) drafted and confirmed (Section 15.6) — or genuinely ambiguous ones moved to Open Questions
- [ ] Ready for implementation → proceed to the build-data-product skill
````
