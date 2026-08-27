---
name: fix-data-product
description: >-
  Human-invoked workflow for interpreting an existing `vulcan review` report for a
  Vulcan/DataOS data product. Does NOT run `vulcan review` itself — it reads a report
  the user points it to, or the latest one in `.vulcan/reviews/`, summarizes findings by
  severity, tells the user what it intends to do before touching anything, and — only
  after agreement — updates `data-product-plan.md` and proposes fixes for blocker/high
  findings. Use when the user asks to review a data product, interpret a review report,
  check review findings, or address review report items.
disable-model-invocation: true
---

# Review Data Product — Vulcan Review Interpretation Workflow

Interpret an already-generated `vulcan review` report, keep `data-product-plan.md` in sync with it, and — with a human in the loop at every consequential step — fix the findings that matter most. Be precise about severity: only `blocker`/`high` findings are ever fix-eligible; everything else is tracked, not touched. The one exception is AI readiness (descriptions/tags/ai_context coverage) — that gap is always compulsory to close, regardless of severity bucketing, because an incomplete field isn't a judgment call the way a modeling finding is.

**Language note**: Vulcan is anti-pipeline. Never use "pipeline" in output or conversation. Use "model DAG", "data product", or "model layers" instead.

## What this skill does and does not do

- **Does**: locate/read a `vulcan review` report, summarize it, propose a plan update and (for blocker/high, plus AI-readiness gaps) fixes — and waits for explicit agreement before writing anything.
- **Does not run `vulcan review`.** Generating the report is the user's job, run from their own shell (it needs `review.model` in `config.yaml` and a provider API key exported there — see Step 0). This skill only ever *reads* a report that already exists.
- **Does not auto-trigger itself or get triggered by another skill.** Including `build-data-product`, whose post-build stage only reminds the user what's needed — it never runs review and never calls this skill on the user's behalf.

---

## Step 0 — Get the report

Ask the user (if they haven't already said) whether they have a specific report to point you to, or want you to find the latest one:

1. **User provides a path** → use exactly that file. If it doesn't exist or can't be read, say so and stop — do not silently fall back to auto-discovery instead of the path they gave you.
2. **User has no path / says "use the latest"** → look in `.vulcan/reviews/` for files named `{YYYY-MM-DD-HHMM}[-N]-review.{html|md}` and pick the latest by the filename's embedded timestamp (the `-N` suffix breaks ties within the same minute). Prefer `.md` over `.html` if both exist for that timestamp.
3. **No report found anywhere** (no path given, and `.vulcan/reviews/` is missing or empty) → do not attempt to generate one. Tell the user:
   > "I couldn't find a review report. This skill only reads an existing `vulcan review` report — it doesn't generate one. To create one, run it yourself:
   > ```
   > vulcan review --output .vulcan/reviews
   > ```
   > That needs a `review.model` set in `config.yaml` (e.g. `review: { model: \"openai:gpt-5.6-luna\" }`) and the matching provider API key exported in your shell (e.g. `export OPENAI_API_KEY=...`). Once it's done, tell me the report path, or just say 'use the latest' and I'll find it."
   Stop here.
4. **Located file is unreadable / empty / truncated** → don't silently substitute an older report:
   > "The report at `<path>` looks incomplete or unreadable. [If auto-discovered: falling back to the next most recent report, `<filename>` — let me know if you'd rather regenerate.] [If user-provided: please check the path or regenerate it.]"
   If nothing usable is found, treat it as case 3.

---

## Step 1 — Parse and summarize

From the report (markdown preferred, HTML if that's all that exists), extract:

- **Decision summary**: `status` (`complete`/`partial`), `modeling_verdict`, `cost_verdict`, and the final decision line (`Approved` / `Approved with conditions` / `Redesign required` / `Insufficient evidence`).
- **Findings**, grouped by `FindingPriority`: `blocker` > `high` > `medium` > `low`. Each finding carries a title, target model name (not a file:line — vulcan review findings are prose, not diagnostics), and a narrative body (root cause / consequence / recommendation / evidence).
- **Deterministic/metadata issues** (rule-based, separate from LLM findings) if the report has that section.

Present a compact triage to the user:

```
## Review Summary — <report filename>
Status: complete | partial
Decision: Approved | Approved with conditions | Redesign required | Insufficient evidence

BLOCKER (n): [title] — [model]
HIGH (n): [title] — [model]
MEDIUM (n): [title] — [model]
LOW (n): [title] — [model]
```

---

## Step 1.5 — Build the AI-readiness checklist

The report's "AI readiness" card only gives aggregate counts (e.g. `descriptions 45/46`, `tags 7/46`, `ai_context 0/24`) — it does not name which field is missing what. If any of the three axes is below 100%, build the actual field-level checklist yourself before proposing anything:

1. List every `models/semantics/*.yml` file in the project.
2. For each semantic object — the model itself, and every `dimensions:`/`measures:`/`segments:`/`joins:` entry — check for a non-empty `description`, a non-empty `tags` list, and (per `grill-data-product`'s Step 2.6 rules — the model/dimension/measure gets `instructions`/`synonyms`/`examples`/`caveats` where meaningful) `ai_context`.
3. Record every object missing any of the three as a checklist line: `[model].[object_type].[object_name] — missing: description, tags` (list only what's actually missing for that object).
4. This checklist is **compulsory, not optional** — unlike medium/low findings, it does not get left as "tracked, not touched." Every object on it gets filled, no cherry-picking, regardless of blocker/high severity elsewhere in the report.

---

## Step 2 — Tell the user what you intend to do, then wait

Before writing anything — to the plan or to any model file — state the intended plan explicitly and stop for agreement. Do not update `data-product-plan.md` or touch any code until the user agrees.

> "Here's what I'll do with this:
> 1. **Update the plan** — add/refresh Section 17 of `data-product-plan.md` with all findings above, grouped by severity.
> 2. **Propose fixes** for the `blocker`/`high` items only (medium/low stay as tracked checklist items, no fix attempted):
>    - [title] — `[model]` — [one-line description of the fix you'd make]
>    - [title] — `[model]` — [one-line description of the fix you'd make]
> 3. **Fill every AI-readiness gap** from the Step 1.5 checklist — this is mandatory, the same way the Data Agreement is mandatory in every plan, so all of it gets done, not just the items you pick:
>    - `[model].[object_type].[object_name]` — missing: description, tags
>    - `[model].[object_type].[object_name]` — missing: ai_context
>
> Should I go ahead? You can tell me to skip specific items in (1)/(2) above; the AI-readiness fill-in in (3) isn't a pick-and-choose list."

Wait for explicit agreement. If the user agrees to the plan update but not the fixes (or vice versa), do only what they agreed to. If they ask for changes to the proposed fix list, revise and re-confirm before proceeding. The AI-readiness checklist is mandatory, the same way Data Agreement (§10.5) is mandatory in `grill-data-product` — no exceptions, no silent skip, and no user opt-out. "Should I go ahead" in the prompt above still applies to it (you always wait for the go-ahead before writing), but a "skip that part" answer for the AI-readiness fill-in gets pushed back on once — explain that every semantic field needs a description/tags/ai_context to be agent-ready before re-asking. If the user insists after that, record the refusal explicitly in Section 17 rather than quietly dropping the item.

---

## Step 3 — Update the plan (only after agreement)

Fold the findings into `data-product-plan.md` under a **Section 17: Review Findings** (append it if absent; update in place if a prior review already created it — overwrite with the current report's findings rather than accumulating duplicates across runs):

```markdown
## 17. Review Findings

**Last reviewed**: [timestamp from report filename] — report: `.vulcan/reviews/<filename>`
**Status**: complete | partial — **Decision**: [decision line]

### Blocker
- [ ] [title] — `[model]` — [one-line recommendation]

### High
- [ ] [title] — `[model]` — [one-line recommendation]

### Medium (tracked, not auto-fixed)
- [title] — `[model]` — [one-line recommendation]

### Low (tracked, not auto-fixed)
- [title] — `[model]` — [one-line recommendation]

### AI Readiness (compulsory — from Step 1.5)
**Descriptions**: [n]/[total] — **Tags**: [n]/[total] — **AI context**: [n]/[total]
- [ ] `[model].[object_type].[object_name]` — missing: description, tags
- [ ] `[model].[object_type].[object_name]` — missing: ai_context
```

---

## Step 4 — Fix, with a human in the loop

Only proceed here if the user agreed to fixes in Step 2. Only `blocker` and `high` findings are fix-eligible — `medium`/`low` stay as plan checklist items only, never attempted here even if the fix looks trivial.

For each agreed `blocker`/`high` finding:

1. **Locate the target**: the finding names a model, not a file:line. Find its file yourself (e.g. `models/**/<model_name>.*`, or the semantic/dq/audit file if the finding is about that layer) — grep the project the same way `build-data-product` does when resolving a model reference.
2. **Propose, don't apply**: draft the concrete fix (SQL/YAML edit) grounded in the finding's recommendation, and show it as a diff to the user before writing anything to disk. This is a second, finer-grained confirmation than Step 2's plan-level agreement — Step 2 agreed to attempt the fix, this is agreeing to the actual diff.
3. **Wait for approval** on the diff itself.
4. **After approval**: apply the edit, then re-run `vulcan plan` (using the Standard Error Handling Loop from `build-data-product` if it fails) to confirm the fix doesn't break the model DAG.
5. **Check off the plan item**: mark the corresponding Section 17 checkbox `[x]` once applied and verified.

Never batch-apply fixes without showing each diff first — a review finding is a recommendation, not a guaranteed-correct patch.

**AI-readiness checklist items** (Step 1.5) follow a lighter version of the same loop, since these are additive metadata fills, not behavioral changes:

1. For each checked-in item, draft the missing `description`/`tags`/`ai_context` for that object — ground it in Section 15.5 of `data-product-plan.md` if it already has content for that object; otherwise derive it the same way `build-data-product`'s Step 5 item 5 would (from Section 1's business context and Section 6's definitions), never a placeholder like `"TODO"` or a bare repeat of the field name.
2. Batch these into one diff per semantic YAML file (unlike blocker/high fixes, these don't need one confirmation per field — grouping by file keeps the review manageable) and show it to the user before writing.
3. **Wait for approval**, then apply and re-run `vulcan plan` to confirm the YAML still validates.
4. Check off each item in Section 17's AI Readiness checklist once applied and verified, and update the `n/total` counts at the top of that subsection.

---

## Step 5 — Re-running

Each invocation of this skill re-locates a report (Step 0 — a fresh user-provided path, or re-discovering the latest in `.vulcan/reviews/`) and re-parses it; it never regenerates one. Section 17 gets overwritten with whichever report's findings you just processed, once the user agrees (Step 2) — it does not block on, or require resolution of, items left open from a prior run. If the user wants to know what changed since last time, diff the new findings against the previous Section 17 content (read the file before overwriting) and call out what's new, what's gone, and what's still open.
