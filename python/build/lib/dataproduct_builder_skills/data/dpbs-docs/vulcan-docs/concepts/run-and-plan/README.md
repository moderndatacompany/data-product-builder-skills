---
description: Understand what `vulcan plan` and `vulcan run` do before you use them.
---

# Run and plan

`vulcan plan` and `vulcan run` are the two commands that move a project from local files to fresh, deployed data. They answer different questions, and confusing them is the most common mistake in daily Vulcan use.

```text
Changed the project shape? Use plan.
Refreshing data on an applied shape? Use run.
```

## Plan: apply project changes

Use `vulcan plan` when you changed models, semantics, metadata, tests, checks, or configuration. Vulcan compares your local project with applied state, shows impact, and prepares the next safe version of the data product.

```bash
vulcan plan
```

`vulcan plan` does not just run data. It reviews what changed, classifies the impact, and decides what must be built before the next version is exposed:

1. Loads your project files and configuration.
2. Builds the dependency graph.
3. Compares local state with applied state.
4. Detects added, removed, direct, indirect, and metadata-only changes.
5. Computes intervals that need backfill or restatement.
6. Shows the plan before anything is applied.

Vulcan supports two planning modes, depending on whether your project uses a virtual layer:

* **[Plan without a virtual layer](plan-guide.md)** - models are written directly with their original names.
* **[Plan with a virtual layer](plan-with-vde.md)** - consumer-facing names stay stable while Vulcan manages versioned physical snapshots behind them.

## Run: refresh applied data

Use `vulcan run` when the shape is already applied and you only need to process new or missing data. It does not redesign the data product and does not pick up new local code changes; it only works with the version that has already been applied.

```bash
vulcan run
```

See **[Run and scheduling](run-and-scheduling.md)** for how `vulcan run` finds missing intervals, respects schedules and signals, and runs scheduled refreshes in production.

## Choosing the right command

| Question | Use `vulcan plan` | Use `vulcan run` |
|---|---|---|
| Did the model SQL or Python change? | Yes | No |
| Did a metric, semantic model, check, or metadata change? | Yes | No |
| Do you need Vulcan to review what changed? | Yes | No |
| Do you only need to process new data? | No | Yes |
| Do you want scheduled refreshes? | No | Yes |

Use `vulcan plan` first when the project changed. Then use `vulcan run` after the new shape is applied and you want ongoing scheduled execution.

For the broader workflow, see [Data product lifecycle](../data-product-lifecycle.md).

## Choose a page

* **[Plan without a virtual layer](plan-guide.md)**
* **[Plan with a virtual layer](plan-with-vde.md)**
* **[Run and scheduling](run-and-scheduling.md)**
