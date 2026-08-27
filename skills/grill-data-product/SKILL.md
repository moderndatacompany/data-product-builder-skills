---
name: grill-data-product
description: >-
  Adaptive, short-form interrogation workflow that fills data-product-plan.md by grilling
  the user with sharp, one-at-a-time questions instead of a scripted questionnaire — pulling
  context from the bundled design-data-product reference, dpbs-docs, and the Data Product MCP
  to decide what to ask next. Produces the same validated data-product-plan.md that
  build-data-product consumes. Use when the user wants to design a Vulcan data product, asks
  to be "grilled" for a data product, or starts a vulcan design session.
disable-model-invocation: true
---

# Grill Data Product

Grill the user relentlessly about every design decision in the data product, until we reach a
shared understanding of what to build. Walk down each branch of the plan's design tree, resolving
dependencies between decisions before moving to the next branch. For each question, provide your
recommended answer. If a question can be answered by exploring `dpbs-docs/` or the Data Product
MCP instead of asking, explore that instead.

Interrogate, don't survey. Fill `data-product-plan.md` by asking exactly what's still missing,
one sharp question at a time — never a fixed list of questions.

**Language note**: Vulcan is anti-pipeline. Never say "pipeline" — say "model DAG", "data
product", or "model layers".

---

## What this is

The requirements-gathering entry point for a Vulcan data product. It replaces the old
scripted 3-batch / 9-question interview with adaptive interrogation, but produces the
**identical** `data-product-plan.md` artifact that `build-data-product` consumes — same
sections, same finalization mechanics, same gate before `Validated`.

## What this is not

Not a new checklist to memorize, and not a standalone design skill in its own right — this is
the only entry point; there is no separate design skill for a user to invoke instead.

---

## Source of truth — `reference/design-data-product.md`, read it, don't duplicate it

This file is bundled inside this skill's own folder (not a separate, independently-invokable
skill) purely as grounding material. Read it for:

- **Artifact Template** (`data-product-plan.md`, sections 1–16) — the exhaustive list of what
  must be resolved before a build can start. Every empty or vague section is a target to grill.
- **Stage 3.5** (quality-rules derivation, `ai_context` drafting, `behavior` typing, verification
  summary) — still mandatory before handoff. Run it as written once the plan is otherwise
  resolved; don't re-ask the fixed Batch 1–3 questions to get there.
- **Table Discovery, Model Kind Classification, Modeling Approach recommendation** (Batch 2 of
  that reference) — reuse this logic and the same MCP calls (`search`, `table_profile`) verbatim
  whenever entities, sources, or joins come up. Don't reinvent it here.
- **Segments, Rollup Candidates, Data Agreement** (Steps 2.8, 2.9, and §10.5 of that reference) —
  don't wait for the user to bring these up. Segments and Rollup Candidates are optional, but
  require actively scanning the drafted spec for repeated patterns before defaulting to `Not
  applicable` (see Rules below). Data Agreement is mandatory, not optional — every plan gets one.
- **Prerequisites Check (Stage 0)** — run this first, before grilling anything.

---

## How to grill

1. **Derive before asking.** Before firing a question, check whether it's already answerable —
   from the conversation so far, from `dpbs-docs/vulcan-docs/` + `dpbs-docs/dataos-philosophy/`,
   or from the Data Product MCP. Never ask the user something you could look up yourself.
2. **One question at a time, MCQ-first.** Pick whichever unresolved plan section matters most
   next (typically: goal → consumers → entities/tables → grain → measures → filters →
   freshness), ask it as multiple-choice per the Question Format below, write the answer
   straight into `data-product-plan.md`, then move to the next gap.
3. **Push past vague answers.** "It tracks engagement" is not a grain, a measure, or a filter.
   Keep pressing a section — exact formula, exact column, exact threshold — until it's concrete
   enough to build from, before moving on.
4. **Verify schema, don't dictate it.** Never invent table or column names from the user's
   description — confirm real ones via `search` / `table_profile`, exactly as the reference's
   Table Discovery step does.
5. **Ground every Vulcan concept** (grain, measure, metric, model kind, behavior type) in
   `dpbs-docs/` before using it in a question or writing it to the plan.
6. **Don't stall forever.** Anything genuinely unresolved after one real attempt goes to
   `[Assumption]` (§11) or Open Questions (§12) — not silence, not "we'll figure it out later."

---

## Question Format — MCQ-first

There is no such thing as a pure open-ended question in this skill. Every question — including
fuzzy, narrative ones like "what's the pain point" or "what should this unlock" — gets asked as
lettered options. The free-text path is never the whole question; it's option D.

**The rule this replaces**: don't reach for "the answer space can't be enumerated" as a reason to
ask pure free text. That's exactly backwards — vague, business-y questions are the ones that most
need options, because a blank page is what makes them hard to answer. If you genuinely can't
propose plausible options (a specific number, an exact column name to confirm via MCP), that's the
rare exception — say so explicitly rather than defaulting to open text out of laziness.

**How to MCQ-ify a narrative/discovery question**:
- Never ask the user to compose a sentence, definition, or description from a blank page. Draft
  your own best guess first — from what they've already told you, common patterns for this kind
  of business/domain, or docs — then ask them to confirm or correct it.
- Turn "what's the pain point?" into 2–3 concrete, plausible pain patterns (scattered sources /
  manual + stale reporting / conflicting definitions across teams) plus D) something else.
- Turn "finish this sentence" into a draft sentence you already wrote, with options to accept it,
  correct one specific part of it, or reject it outright — not a fill-in-the-blank homework
  assignment.

**Mechanics for every question**:
- Offer 2–4 concrete, mutually exclusive options, lettered (A/B/C/D).
- Ground every option in something real — prior answers, `table_profile` output, `dpbs-docs`
  conventions, or common patterns for this kind of entity — never invent options with no basis.
- Mark the option you'd recommend and say why in a few words, e.g.
  `B) Daily (recommended — matches the freshness note you gave earlier)`.
- Always include a final escape hatch, e.g. `D) Something else — tell me in your own words`, so
  the user can still go free-text when your guesses miss — but that's their choice to opt into,
  not the default shape of the question.

---

## Flow

1. Run the Prerequisites Check from `reference/design-data-product.md` Stage 0.
2. Create `data-product-plan.md` from that file's Artifact Template as soon as Section 1
   (problem / use case / consumers / key questions) is answerable.
3. Work through the template's sections in whatever order the conversation naturally surfaces
   them, one grilling question per turn, updating the file as each answer lands. Skip anything
   the user has already stated unprompted — never ask what you already know.
4. Once every section is resolved (grain not `UNKNOWN`, no un-typed measure/dimension left
   unflagged), run the reference's Stage 3.5 verbatim: derive quality rules, draft `ai_context`,
   draft `behavior`, produce the verification summary.
5. Mark `Status: Validated` only when Section 16's checklist is fully checked.
6. Hand off to `build-data-product` (which reads `data-product-plan.md`).

---

## Rules

- Never dump more than one question in a turn.
- Prefer MCQ over open-ended questions; free text is the exception, not the default.
- Never show the Artifact Template's section list to the user as a survey — it's your internal
  checklist, not their homework.
- Never invent a number, table, or column — measure or verify it, or mark it `[Assumption]` /
  Open Question.
- `data-product-plan.md` is the only source of truth.
- Never default Segments (§15.7) or Rollup Candidates (§15.8) to `Not applicable` just because
  the user didn't mention them. Actively re-scan drafted examples/filters/metrics for a repeated
  pattern first (Steps 2.8/2.9), propose it as MCQ if found, and only mark `Not applicable` after
  actually looking and asking — not by default.
- Data Agreement (§10.5) is mandatory for every plan, no exceptions and no silent skip — this is
  a house policy stricter than Vulcan's own optional guidance for `agreement.md`. Draft it
  tailored to the specific product, never boilerplate.
