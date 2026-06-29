# Vulcan run guide

Use `vulcan run` to refresh data after a plan is applied.

First, decide what the data product should look like with `vulcan plan`. After that shape is approved and applied, `vulcan run` keeps the data fresh.

```bash
vulcan run
```

`vulcan run` does not redesign the data product. It does not pick up new local code changes. It only works with the version that has already been applied.

If you changed a model, metric, semantic definition, check, or project setting, run `vulcan plan` first. If the shape is already applied and you only want to process new or missing data, use `vulcan run`.

---

## The simple story

A store publishes a daily sales report.

The report design says:

1. Which tables exist.
2. Which calculations are used.
3. Which checks must pass.
4. How often data should be refreshed.

That design is applied with `vulcan plan`.

Every day after that, new sales arrive. The report does not need to be redesigned. It only needs the next day of data.

That is what `vulcan run` does.

```text
vulcan plan
  -> approves the shape of the data product

vulcan run
  -> keeps that approved shape filled with fresh data
```

---

## Plan vs run

Use `vulcan plan` when the design changes.

Use `vulcan run` when the design is already applied and the data needs to catch up.

| Question | Use `vulcan plan` | Use `vulcan run` |
| --- | --- | --- |
| Did the model SQL or Python change? | Yes | No |
| Did a metric, semantic model, check, or metadata change? | Yes | No |
| Do you need Vulcan to review what changed? | Yes | No |
| Do you only need to process new data? | No | Yes |
| Do you want scheduled refreshes? | No | Yes |

A simple rule:

```text
Changed the shape? Use plan.
Refreshing data? Use run.
```

---

## What `vulcan run` looks for

When you run `vulcan run`, Vulcan asks:

1. What data product shape is already applied?
2. Which models are part of that applied shape?
3. Which dates or time windows have already been processed?
4. Which dates or time windows are missing?
5. Which missing windows are ready to run now?
6. Which checks, assertions, or quality rules should run after data is processed?

Vulcan does not ask, “What local files changed?” That question belongs to `vulcan plan`.

---

## What `vulcan run` does

`vulcan run` processes data for the models that are already applied.

It can:

1. Process new daily, hourly, weekly, or monthly data.
2. Catch up after a failed or delayed run.
3. Run one selected model and the data it depends on.
4. Respect model schedules.
5. Wait for signals that say source data is ready.
6. Run assertions and assertions.
7. Run data quality checks after successful model execution.
8. Record what happened so teams can review it later.

It does not:

1. Apply local code changes.
2. Decide whether a model change is breaking or non-breaking.
3. Promote new versions of models.
4. Replace `vulcan plan`.

---

## The run journey

A typical run follows this journey:

```text
1. Read the applied state
2. Find models that belong to that state
3. Check which time intervals are missing
4. Check schedules and signals
5. Decide what is ready to run
6. Run models in the right order
7. Run audits and quality checks
8. Mark intervals as processed
9. Record success, failure, or nothing to do
```

If there is nothing ready, that is not a failure. It usually means the data is already up to date, or the next scheduled window is not ready yet.

---

## Applied state

Applied state is the version of the data product Vulcan is allowed to run.

Think of it like an approved blueprint.

If a developer changes a local file, that local change is not automatically part of the blueprint. The change must go through `vulcan plan` first.

Example:

```text
Applied state:
  sales.orders uses approved version A

Local file:
  sales.orders was edited and now represents version B

vulcan run:
  still runs version A

vulcan plan:
  reviews and applies version B
```

This protects teams from accidentally running unapproved changes.

---

## Missing intervals

A missing interval is a time window that should have data but does not yet.

Example:

```text
Daily orders model

Already processed:
  May 1
  May 2

Missing:
  May 3
```

When you run `vulcan run`, Vulcan finds these missing windows and decides whether they are ready to process.

It does not blindly run everything. It checks schedules, signals, dependencies, and the selected date range.

---

## Start and end dates

You can ask Vulcan to run a specific time window:

```bash
vulcan run --start 2026-05-01 --end 2026-05-07
```

Use this when:

1. You want to catch up a known date range.
2. You want to rerun a small window during testing.
3. You do not want Vulcan to look beyond a specific date range.

If you do not provide a date range, Vulcan uses the applied model settings, stored interval history, schedules, and current execution time to decide what is missing.

---

## Schedules

Some models should run hourly. Some should run daily. Some should run weekly.

A schedule tells Vulcan when a missing interval is allowed to run.

Example:

```text
A daily model has missing data for May 3.

If May 3 is not ready yet:
  Vulcan waits.

If May 3 is ready:
  Vulcan can run it.
```

By default, `vulcan run` respects schedules.

If you intentionally want to ignore schedules during a manual catch-up, use:

```bash
vulcan run --ignore-cron
```

Use this carefully. It can make Vulcan run data earlier than the normal schedule.

---

## Signals

A signal is a readiness check.

It can answer questions like:

1. Has the source file arrived?
2. Is the upstream table updated?
3. Is the required partition available?
4. Has another business process finished?

If a signal says the data is not ready, Vulcan skips that interval for now.

```text
Missing interval
  -> schedule ready?
  -> source data ready?
  -> upstream process done?
  -> run only when all checks say yes
```

This helps prevent incomplete data from being processed too early.

---

## Running in the right order

Data models often depend on one another.

Example:

```text
raw orders
  -> cleaned orders
    -> customer revenue
```

Vulcan runs upstream models before downstream models.

If you ask Vulcan to run `customer revenue`, it normally includes the upstream models too. This helps prevent the final model from using stale or missing parent data.

---

## Running only one part of the data product

You can select one model:

```bash
vulcan run --select-model analytics.customer_revenue
```

By default, Vulcan also includes upstream dependencies.

If you do not want that, use:

```bash
vulcan run --select-model analytics.customer_revenue --no-auto-upstream
```

Use `--no-auto-upstream` carefully. If upstream data is missing, the selected model may run with incomplete inputs.

---

## Batches

Sometimes Vulcan has many missing intervals to process.

Instead of running each one separately, Vulcan can group ready intervals into batches.

Example:

```text
Ready intervals:
  May 1
  May 2
  May 3

Batch size: 2

Batches:
  Batch 1: May 1 to May 2
  Batch 2: May 3
```

Batching helps Vulcan run efficiently while still respecting dependencies and gaps in data readiness.

---

## Assertions and quality checks

After data runs, Vulcan can check whether the result looks trustworthy.

Assertions and assertions can answer questions like:

1. Are there null IDs?
2. Are there negative amounts?
3. Is the row count too low?
4. Are key values unique?

Data quality checks can record quality posture after successful execution.

The simple difference:

```text
Audits and assertions:
  run during model evaluation and may block a bad result

Data quality checks:
  run after successful execution and record quality status
```

Both help teams trust the data after it is refreshed.

---

## What happens if nothing runs

Sometimes `vulcan run` finishes and says there is nothing to do.

That can happen when:

1. All data is already processed.
2. The next scheduled interval is not ready yet.
3. A signal says source data is not ready.
4. The selected model has no missing work.
5. The date range you requested has no missing intervals.

This is usually a successful result. Vulcan checked the applied state and found no ready work.

---

## Run activity

At the end of a run, Vulcan records what happened.

Run activity can include:

1. When the run started and ended.
2. Which models ran.
3. Which intervals were processed.
4. Which models were skipped.
5. Which assertions or checks passed or failed.
6. What errors happened, if any.
7. Whether the run succeeded, failed, or had nothing to do.

This activity helps teams debug issues, monitor freshness, and explain what happened during a scheduled refresh.

---

## With and without a virtual layer

`vulcan run` behaves mostly the same with or without a virtual layer because it works from applied state.

The main difference is where data lives and how consumers reach it.

With a virtual layer:

```text
consumer-facing object
  -> virtual-layer view
  -> versioned physical snapshot table
```

Without a virtual layer:

```text
consumer-facing object
  -> original materialized object
```

In both modes, `vulcan run` still:

1. Finds missing intervals.
2. Respects schedules and signals.
3. Runs the DAG in order.
4. Records intervals and run activity.

The virtual layer does not make `vulcan run` detect code changes. Code-change detection belongs to `vulcan plan`.

---

## Useful commands

Run the applied shape:

```bash
vulcan run
```

Run a specific date window:

```bash
vulcan run --start 2026-05-01 --end 2026-05-07
```

Ignore schedules during a manual catch-up:

```bash
vulcan run --ignore-cron
```

Run one model and its upstream dependencies:

```bash
vulcan run --select-model analytics.customer_revenue
```

Run only the selected model:

```bash
vulcan run --select-model analytics.customer_revenue --no-auto-upstream
```

Skip cleanup:

```bash
vulcan run --skip-janitor
```

Exit with a specific code if applied state changes while the run is active:

```bash
vulcan run --exit-on-env-update 75
```

---

## When to use `vulcan run`

Use `vulcan run` when:

1. The data product shape is already applied.
2. You need to process new data.
3. You need to catch up missing data.
4. You want scheduled execution to keep data fresh.
5. You want to run a selected part of the DAG.
6. You want assertions, quality checks, and run history for processed intervals.

Use `vulcan plan` instead when:

1. You changed model SQL or Python.
2. You changed model metadata.
3. You added or removed models.
4. You changed semantics, metrics, checks, hooks, or dependencies.
5. You need Vulcan to review and classify changes before applying them.

---

## Common misunderstandings

**"`vulcan run` deploys local code changes."**

No. `vulcan run` executes applied snapshots. Use `vulcan plan` to apply local project changes.

**"Missing intervals always run immediately."**

No. Schedules, signals, dependencies, and selected model filters can delay or skip a missing interval.

**"`--select-model` only runs that one model."**

Not by default. Vulcan includes upstream dependencies unless `--no-auto-upstream` is used.

**"Nothing to do means failure."**

No. It usually means no intervals are currently ready to execute.

**"Quality checks are the same as assertions."**

No. Assertions and assertions run during model evaluation and can block execution depending on configuration. Data quality checks run after successful execution and record quality posture.

**"The virtual layer changes how run detects code changes."**

No. The virtual layer affects object exposure and physical naming. Run still works from applied state. Plan handles code-change detection.
