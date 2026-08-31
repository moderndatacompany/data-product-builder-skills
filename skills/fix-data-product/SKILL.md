---
name: fix-data-product
description: >-
  Human-invoked workflow for interpreting an existing `vulcan review` report for a
  Vulcan/DataOS data product. Does NOT run `vulcan review` itself — it reads a report
  the user points it to, or the latest one in `.vulcan/reviews/`, summarizes findings by
  severity, tells the user what it intends to do before touching anything, and — only
  after agreement — updates `data-product-plan.md` and fixes blocker/high findings plus
  the compulsory AI-readiness gaps. Use when the user asks to interpret a review report,
  check review findings, address review report items, or fix what `vulcan review` flagged.
disable-model-invocation: true
---

# Fix Review Findings — Vulcan Review Interpretation Workflow

Interpret an already-generated `vulcan review` report, keep `data-product-plan.md` in sync with it, and — with a human in the loop at every consequential step — fix the findings that matter most. Be precise about severity: only `blocker`/`high` findings (LLM or deterministic) are ever fix-eligible; medium/low are tracked, not touched. The one exception is AI readiness on the compulsory scope (see Step 1.5) — that gap is always compulsory to close, regardless of severity bucketing, because an incomplete field isn't a judgment call the way a modeling finding is.

**Language note**: Vulcan is anti-pipeline. Never use "pipeline" in output or conversation. Use "model DAG", "data product", or "model layers" instead.

## What this skill does and does not do

- **Does**: locate/read a `vulcan review` report, summarize it, propose a plan update and (for blocker/high, plus AI-readiness gaps) fixes — and waits for explicit agreement before writing anything.
- **Does not run `vulcan review`.** Generating the report is the user's job, run from their own shell — it needs `pip install 'vulcan[review]'`, a `review.model` set in `config.yaml`, and a provider API key exported there (see Step 0). This skill only ever *reads* a report that already exists.
- **Does not auto-trigger itself or get triggered by another skill.** Including `build-data-product`, whose post-build stage only reminds the user what's needed — it never runs review and never calls this skill on the user's behalf.

---

## Step 0 — Get the report

Ask the user (if they haven't already said) whether they have a specific report to point you to, or want you to find the latest one:

1. **User provides a path** → use exactly that file. If it doesn't exist or can't be read, say so and stop — do not silently fall back to auto-discovery instead of the path they gave you.
2. **User has no path / says "use the latest"** → look in `.vulcan/reviews/` for files named `{YYYY-MM-DD-HHMM}[-N]-review.html` and pick the latest by the filename's embedded timestamp (the `-N` suffix breaks ties within the same minute). **The report is HTML only** — `vulcan review --help` confirms `--type` accepts only `html`; do not look for or expect a `.md` variant.
3. **No report found anywhere** (no path given, and `.vulcan/reviews/` is missing or empty) → do not attempt to generate one. Tell the user:
   > "I couldn't find a review report. This skill only reads an existing `vulcan review` report — it doesn't generate one. To create one, run it yourself:
   > ```
   > pip install 'vulcan[review]'
   > vulcan review -e <environment> --output .vulcan/reviews
   > ```
   > That needs a `review.model` set in `config.yaml` and the matching provider API key exported in your shell. `-e/--environment` is the environment to compare the working tree against for live metadata and plan state — which environment you pick can change what the review finds (e.g. a model authored locally but not yet deployed reads differently than one deployed but no longer matching the authored source), so ask the user which environment they reviewed against if it isn't obvious, and record it in Section 17. Once it's done, tell me the report path, or just say 'use the latest' and I'll find it."
   Stop here.
4. **Located file is unreadable / empty / truncated** → don't silently substitute an older report:
   > "The report at `<path>` looks incomplete or unreadable. [If auto-discovered: falling back to the next most recent report, `<filename>` — let me know if you'd rather regenerate.] [If user-provided: please check the path or regenerate it.]"
   If nothing usable is found, treat it as case 3.
5. **Blocked-run report** — check for this BEFORE case 4, because it looks exactly like a truncated/corrupt file otherwise: the file still has a `.html` extension, but its content is plain markdown — `# Architecture review: <project>`, `**Review run:** PARTIAL`, then a bullet list of reasons. This happens whenever synthesis couldn't produce a full report, not only for a missing-intent project — the reasons list might say no models exist, no declared intent (no `description` in `config.yaml`, no `usage.yaml`, no README), a business-context step failed, an evidence packet is missing, or some other dimension never completed. Read the actual reasons and respond to what they say — don't assume it's always the missing-intent case and don't tell the user to regenerate (it'll fail identically). If the reason is missing intent, tell the user to add a business-facing `usage.yaml` or README first. If the reason is "no models", tell them there's nothing to review until models exist. For any other reason, quote it back to the user and ask how they want to proceed.

---

## Step 1 — Parse and summarize

From the report, extract:

- **Status badges**: `Review run` (complete/partial), `Modeling readiness` (e.g. `changes_required`), `Cost posture` (`appropriate` | `watch` | `risk` | `unknown`). These are three **independent** signals — there is no single fixed-enum "Decision" line (`Approved`/`Redesign required`/etc.) anywhere in the report; don't invent one, and don't infer an overall verdict from the finding count (a blocker existing doesn't make the run `partial` — `Review run` status is reported independently of findings). Cost posture never carries a currency figure anywhere in the report — it's a qualitative posture, not a bill; don't ask the user for or invent a dollar amount. Its four values need different responses, and mixing them up wastes a fix cycle:
  - `risk` — an actual `physical_cost`-category finding exists at blocker/high; fix it exactly like any other finding in Step 4 (it'll already be in the findings list, no special-casing needed).
  - `watch` — a cost finding exists, but below blocker/high; tracked, not fixed (same as any medium/low). Requires at least one cost finding to exist — don't use this label for "no finding, but evidence is thin," that's `unknown`.
  - `unknown` — has two distinct causes, and they need different responses:
    - **Run complete, but no cost finding and workload evidence wasn't available** (no real run history / `-e` wasn't pointed at an environment with `nominal_runs` or `missing_intervals` data). Not a code problem — nothing about the models is provably wrong yet. The fix is re-running `vulcan review -e <environment-with-run-history>`, not proposing a model change.
    - **Run itself was partial** (missing coverage/dimensions, or findings didn't parse). Re-running with `-e` won't fix this — fix whatever made the run partial first (see Step 0 case 5), then re-review.
    Check `Review run` status before reacting to `unknown` — don't default to "just add `-e`" if the run was partial.
  - `appropriate` — no action needed.
- **AI readiness**: the tier badge (e.g. `NOT AGENT-READY`) plus the three raw fractions — `descriptions n/total`, `tags n/total`, `ai_context n/total`. **The denominators differ on purpose, don't try to reconcile them**: the implicit `count` measure is excluded from BOTH denominators, not just one. The actual divergence comes from metric-model columns — they count toward the description/tags denominator but have no dimension/measure kind, so they're never counted toward `ai_context` at all. Also note: the `ai_context` fraction counts a field only when it's fully **passing** (all mandatory sub-fields present per Step 1.5's rules) — a half-filled `ai_context` (e.g. `instructions` present, `synonyms` missing) still reads as 0 on the card, not partial credit. If the report shows this card as "unavailable", the project didn't parse — skip Step 1.5 entirely rather than guessing a checklist.
- **Findings**, grouped by `FindingPriority`: `blocker` > `high` > `medium` > `low`. Blocker and high share one list (ordered by priority then blast radius); only the **first five case blocks total** are inline in the HTML — **the rest are inside a collapsed `<details class="more-findings">` block** — parse its contents too, don't stop at the visible cards. Medium/low findings additionally live in a separate "Additional findings" `<table>`, not as `.case` divs — check both shapes or you'll silently drop findings from your triage. Each finding carries: a title, an **evidence citation** in `path/to/file.sql:12-20` form, required action, validation criterion, residual risk, and affected needs. A single finding can name multiple models/fields (a repeated root cause grouped as one entry) — don't assume one finding maps to exactly one model.
- **Deterministic/metadata issues** (rule-based, separate from LLM findings) if the report has that section — these fold into the same case blocks / additional-findings table as LLM findings, with no guaranteed separate `rule_id` slot in the HTML. Identify them by their prescribed action reading as fixed-vocabulary and field-level (naming a specific config/policy target) rather than prose narrative. Key on title + target; treat `rule_id` as a bonus if it happens to be visible, never a requirement. These carry through to Steps 2-4 exactly like LLM findings when `blocker`/`high`, see Step 4.

Present a compact triage to the user:

```
## Review Summary — <report filename>
Review run: complete | partial   Modeling readiness: <value>   Cost posture: <value>
AI readiness: <tier>  —  descriptions n/total, tags n/total, ai_context n/total

BLOCKER (n): [title] — [model(s)]
HIGH (n): [title] — [model(s)]
MEDIUM (n): [title] — [model(s)]
LOW (n): [title] — [model(s)]
DETERMINISTIC (n, blocker/high only): [title] — [target] [rule_id if visible]
```

---

## Step 1.5 — Build the AI-readiness checklist

**Compulsory scope only**: public `dimensions:`/`measures:` on each **semantic** model — `ai_context` scoring only applies where a dimension/measure kind actually exists, which metric-model columns don't have. Segments, joins, and model-level (top-of-file) `ai_context`/`tags` are a separate **optional, "quality improvement"** bucket — the review's own counting only scores dimensions and measures, so don't inflate the mandatory list with objects it doesn't count. Skip the implicit `count` measure entirely (it's deliberately excluded from scoring; filling it is pure noise). Within the compulsory scope, treat `private` (non-public) members' `tags` as **recommended, not mandatory** — the review doctrine doesn't expect every internal field to carry the same metadata weight as a published one; `description`/`ai_context` on a public member is still compulsory.

**Target is the next tier, not 100%.** Private members still count toward the report's denominators even though their `tags` aren't mandatory here — so the fraction on the card will never reach `n/n` from filling the compulsory (public) scope alone. Don't imply otherwise to the user in Step 2/3; the goal is crossing into the next readiness tier, with private-member gaps as an expected, non-blocking residual.

**Authoring rules — get these into the plan/YAML exactly, they are the actual scoring risk**:

- On every compulsory object: `instructions`, `synonyms`, and `examples` are **all mandatory** — not "where meaningful". `caveats` is the only optional field.
- `examples` is a list of OBJECTS: each needs a non-empty `description` (the natural-language question) and a non-empty `query`, `format` is optional. A bare string entry is invalid, not just a style issue.
- **Two banned shapes** — both read as a genuine fill but score as if nothing was written, because they're exactly what an LLM defaults to when bulk-filling 24+ fields on autopilot:
  - (a) `instructions` starting with a template like *"Use `<field>` to filter or group `<model>` results."*, paired with `examples` that are all `COUNT(*) ... GROUP BY <field>` — this says nothing an AI agent couldn't already infer from the column name and type.
  - (b) `instructions` that's a copy or lightly-reworded restatement of the object's `description` — adds zero new information.
  If a draft matches either shape, treat it as a failed fill and rewrite it, not a pass.
- **Good vs bad**, for a `region_id` dimension:
  ```yaml
  # BAD — banned shape (a): generic filter/group template, COUNT(*) example
  ai_context:
    instructions: "Use region_id to filter or group results by region."
    examples:
      - description: "Count rows by region"
        format: sql
        query: "SELECT region_id, COUNT(*) FROM ... GROUP BY region_id"

  # GOOD — grounded in what actually goes wrong when this field is misused
  ai_context:
    instructions: |
      Stable region key from raw_regions; join target for region_name/geo/segment_owner.
      Do not confuse with geo (theater-level) — region_id is the finer grain used by the WBR.
    synonyms: ["region code", "region key"]
    examples:
      - description: "Which region missed its new-ARR target most this month?"
        format: sql
        query: "SELECT region_id, m_new_arr_vs_target FROM ... WHERE month = '2026-07-01' ORDER BY m_new_arr_vs_target ASC"
  ```
- **Ground the content in what the object actually is**, not a template: for a **measure**, cover its numerator/denominator (if a ratio), any `filters` that change its meaning, non-additivity (stock/flow), and time behavior. For a **dimension**, cover coded/enum values, what `NULL` means for it, and whether it's derived vs. raw. For a **segment** (optional bucket), cover overlap with other segments and what it excludes. `design-data-product`'s Step 2.6 uses the same grounding — reuse its guidance rather than re-deriving it.
- **Missing metadata is never a finding; misleading metadata is.** An accurate absence is safer than a confident lie — a description/`ai_context` that gets the object's actual meaning wrong (the canonical failure: naming the wrong source column, e.g. calling a physical `order_date` column `shipping_date` in the description) becomes a real semantic finding, potentially blocker/high, in the NEXT review — worse than leaving it empty. Before writing any draft, check it against the object's actual `expression`, `filters`, and `behavior` in the YAML. If you can't establish what the field actually means with confidence, leave it unfilled and flag it to the user as an open question — do not guess to hit 100% coverage. This is the one legitimate exception to Step 1.5's "compulsory, no opt-out" framing: an honest gap beats a wrong answer.

**Compute the tier gap, don't just report raw fractions.** The tier is driven by the `ai_context` passing ratio, with cutoffs at 34% and 75% (below 34% → `NOT AGENT-READY`, 34-75% → the middle tier, above 75% → agent-ready). The report shows the tier label and the fractions, not these cutoffs — do the arithmetic yourself: how many more `ai_context` fields need to go from failing to fully passing to cross 34% or 75% of the `ai_context` denominator. Lead with that number in Step 2 — "fill these N objects and you cross into `<next tier>`" is far more actionable than "45/46". If a future report version changes these cutoffs, this line goes stale — sanity-check the math against the report's own tier label before presenting it, and flag a mismatch rather than presenting a wrong number confidently.

Record every compulsory object missing any piece as a checklist line: `[model].[dimension|measure].[name] — missing: description, tags, ai_context` (list only what's actually missing). List optional-bucket gaps (segments/joins/model-level, private tags) separately and mark them non-blocking.

---

## Step 2 — Tell the user what you intend to do, then wait

Before writing anything — to the plan or to any model file — state the intended plan explicitly and stop for agreement. Do not update `data-product-plan.md` or touch any code until the user agrees.

Order proposed fixes the way the report's own change-plan does (see Step 4) — dependency order, not discovery order. Within the AI-readiness checklist, order **measures first, then public dimensions, then anything in the optional bucket** — if the fill has to happen in batches, this ordering front-loads the objects that move the tier the most.

> "Here's what I'll do with this:
> 1. **Update the plan** — add/refresh Section 17 of `data-product-plan.md` with all findings above, in the report's own dependency order.
> 2. **Propose fixes** for the `blocker`/`high` items (LLM and deterministic) only (medium/low stay as tracked checklist items, no fix attempted):
>    - [title] — `[model(s)]` — [one-line description of the fix you'd make, grounded in the finding's own required action]
> 3. **Fill the compulsory AI-readiness checklist** (measures → public dimensions → optional bucket) — this is mandatory, so all of the compulsory scope gets done, not just the items you pick:
>    - `[model].[object_type].[object_name]` — missing: description, tags
>    - Filling [N] of these crosses you from `[current tier]` to `[next tier]`.
>
> Should I go ahead? You can tell me to skip specific items in (1)/(2) above; the compulsory part of (3) isn't a pick-and-choose list — the optional-bucket items in (3) are."

Wait for explicit agreement. If the user agrees to the plan update but not the fixes (or vice versa), do only what they agreed to. If they ask for changes to the proposed fix list, revise and re-confirm before proceeding. A "skip that part" answer for the compulsory AI-readiness fill-in gets pushed back on once — explain why it's compulsory before re-asking. If the user still declines after that, don't silently drop it — record the explicit refusal in Section 17 (see Step 5's symmetric rejection handling).

---

## Step 3 — Update the plan (only after agreement)

Fold the findings into `data-product-plan.md` under a **Section 17: Review Findings** (append it if absent; update in place if a prior review already created it — see Step 5 for how to preserve checkbox state rather than blindly overwriting):

```markdown
## 17. Review Findings

**Last reviewed**: [timestamp from report filename] — report: `.vulcan/reviews/<filename>` — environment: `[-e value, if known]`
**Review run**: complete | partial — **Modeling readiness**: [value] — **Cost posture**: [value] [if `unknown`: — needs re-review with workload evidence, not a code fix]
**AI readiness**: [tier] — descriptions [n]/[total], tags [n]/[total], ai_context [n]/[total]

### Blocker
- [ ] [title] — `[model(s)]` — [one-line recommendation] — [evidence path:line]

### High
- [ ] [title] — `[model(s)]` — [one-line recommendation] — [evidence path:line]

### Deterministic (blocker/high — keyed by title + target, rule_id if visible)
- [ ] [title] — [target] — [prescribed action] [`rule_id` if visible]

### Medium (tracked, not auto-fixed)
- [title] — `[model(s)]` — [one-line recommendation]

### Low (tracked, not auto-fixed)
- [title] — `[model(s)]` — [one-line recommendation]

### AI Readiness — compulsory (from Step 1.5)
- [ ] `[model].[dimension|measure].[name]` — missing: description, tags

### AI Readiness — optional bucket (segments/joins/model-level, private tags)
- `[model].[object_type].[object_name]` — missing: [field]

### Rejected / Declined (see Step 5)
- [title or checklist item] — reason: [user's stated reason] — [date]
```

---

## Step 4 — Fix, with a human in the loop

Only proceed here if the user agreed to fixes in Step 2. `blocker`/`high` findings (LLM and deterministic) are fix-eligible; `medium`/`low` stay as plan checklist items only, never attempted here even if the fix looks trivial.

**Fix in the report's own change-plan order, not your own.** The report's change-plan section is already dependency-ordered, and each of its items carries an acceptance criterion meant to be executable or objectively observable — use that order and that criterion rather than re-deriving either. Fixing a downstream model before an upstream one it depends on is wasted work.

For each agreed `blocker`/`high` finding:

1. **Locate the target from the evidence citation first**: findings carry a `path/to/file:line-range` citation — verify that path actually exists before editing (citations can be stale), then read that exact location. Only fall back to grepping for the model name (the way `build-data-product` does) if the citation is missing or doesn't resolve. If a finding names multiple models/fields (a grouped root cause), fix every named instance, not just the first.
2. **Deterministic findings**: some are product-scoped rather than model-scoped — e.g. an access-policy blocker doesn't name a model at all; its fix lives in a `policies/` file or a model-level `policy:` block. Don't force the "locate the model" flow onto these; resolve the target from the rule's own description instead.
3. **Propose, don't apply**: draft the concrete fix (SQL/YAML edit) grounded in the finding's required action, and show it as a diff to the user before writing anything to disk. This is a second, finer-grained confirmation than Step 2's plan-level agreement.
4. **Wait for approval** on the diff itself.
5. **After approval, verify against the finding's own criterion, not a generic re-plan**: build the specific acceptance check the finding's `validation` describes (e.g. a duplicate-check query, an interval-overlap check) rather than treating "`vulcan plan` didn't error" as sufficient. Use the Standard Error Handling Loop from `build-data-product` if `vulcan plan` itself fails.
6. **Check off the plan item**: mark the corresponding Section 17 checkbox `[x]` once applied and the finding's own validation criterion is met — `[x]` means "applied and verified," not "review agreed with the approach." The verdict only actually changes when the user re-runs `vulcan review` fresh.

Never batch-apply fixes without showing each diff first — a review finding is a recommendation, not a guaranteed-correct patch.

**AI-readiness checklist items** (Step 1.5, compulsory scope) follow a lighter version of the same loop, since these are additive metadata fills, not behavioral changes:

1. For each checked-in item, draft the missing `description`/`tags`/`ai_context` for that object per Step 1.5's authoring rules — ground it in Section 15.5 of `data-product-plan.md` if it already has content for that object; otherwise derive it the same way `build-data-product`'s Step 5 item 5 would (from Section 1's business context and Section 6's definitions). Never a placeholder like `"TODO"`, and never one of Step 1.5's banned shapes.
2. Batch these into one diff per semantic YAML file and show it to the user before writing.
3. **These fields are metadata-only** (description/tags/terms/ai_context never enter the data hash, only the metadata hash) — the fill should never touch an `expression`, `filters`, or anything data-affecting. If a proposed diff for this section touches an expression, stop and re-check — that's scope creep from an AI-readiness fill into a behavioral change. To validate, a full `vulcan plan` is more than you need for a metadata-only change — `vulcan info --skip-connection` loads and validates the models/YAML without connecting to the warehouse, which is the cheaper check; fall back to `vulcan plan` only if that's unavailable in the installed CLI version.
4. **Wait for approval**, then apply and validate.
5. Check off each item in Section 17's AI Readiness checklist once applied and verified, and update the tier/fraction line at the top of Section 17.

**Before any of the above touches disk**: check `git status` and show the user any pre-existing uncommitted changes before applying fixes — don't let a fix land on top of unrelated in-progress work unnoticed. Never commit on the user's behalf.

---

## Step 5 — Re-running

Each invocation of this skill re-locates a report (Step 0 — a fresh user-provided path, or re-discovering the latest in `.vulcan/reviews/`) and re-parses it; it never regenerates one.

- **Preserve checkbox state across runs.** Don't blindly overwrite Section 17 — match findings by title + model against the previous version (read it before overwriting) and carry forward `[x]` state for anything still present. Call out explicitly what's newly found vs. still open vs. resolved since last time.
- **Log every run**: append a one-line entry (date, report file, blocker/high count, AI-readiness tier) so the user can see the trend across runs, not just the current snapshot.
- **Record rejections symmetrically.** Step 2 already records a declined AI-readiness fill; do the same for any declined finding — note the user's stated reason in Section 17's "Rejected / Declined" list. Without this, a rejected finding has no memory and will resurface identically next run with no context on why it wasn't fixed.
- **Check staleness before proposing fixes.** A report is a snapshot. If any model file the report's findings reference has changed since the report's own timestamp, warn the user that the finding may already be stale or resolved before proposing a fix for it — don't fix against a target that's moved.
