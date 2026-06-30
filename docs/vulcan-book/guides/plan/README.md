---
description: Understand what `vulcan plan` does before you apply changes.
---

# Plan

`vulcan plan` is the deployment step for project changes.

Use it when you changed models, semantics, metadata, tests, checks, or configuration. Vulcan compares your local project with applied state, shows impact, and prepares the next safe version of the data product.

```bash
vulcan plan
```

`vulcan plan` does not just run data. It reviews what changed, classifies the impact, and decides what must be built before the next version is exposed.

## Plan modes

Vulcan supports two planning modes. The right one depends on whether your project uses a virtual layer.

<table data-card-size="large" data-view="cards"><thead><tr><th></th><th data-hidden data-card-target data-type="content-ref"></th></tr></thead><tbody><tr><td><strong>Without a virtual layer</strong><br>Models are written directly with their original names.</td><td><a href="plan_guide.md">plan_guide.md</a></td></tr><tr><td><strong>With a virtual layer</strong><br>Consumer-facing names stay stable while Vulcan manages versioned physical snapshots behind them.</td><td><a href="vulcan_plan_vde_true.md">vulcan_plan_vde_true.md</a></td></tr></tbody></table>

***

## What `vulcan plan` does

When you run `vulcan plan`, Vulcan:

1. Loads your project files and configuration.
2. Builds the dependency graph.
3. Compares local state with applied state.
4. Detects added, removed, direct, indirect, and metadata-only changes.
5. Computes intervals that need backfill or restatement.
6. Shows the plan before anything is applied.

If you apply the plan, Vulcan updates the target state using the selected deployment mode.

***

## When to use `vulcan plan`

Use `vulcan plan` when:

1. You changed SQL or Python model logic.
2. You added or removed models.
3. You changed semantics, metrics, assertions, or checks.
4. You updated model metadata or data product configuration.
5. You need to review blast radius before deployment.

Use [`vulcan run`](../run_and_scheduling.md) when the shape is already applied and you only need to process new data.

Simple rule:

```
Changed the project shape? Use plan.
Refreshing data on an applied shape? Use run.
```

***

## What the plan output tells you

The plan helps you answer a few key questions:

1. Which models changed directly?
2. Which downstream models are affected indirectly?
3. Are the changes breaking, non-breaking, or metadata-only?
4. Which intervals need data to be built?
5. Can Vulcan reuse existing state, or must it compute new data first?

This makes `vulcan plan` the safest way to move local changes into an applied state.

***

## Typical plan flow

Most plans follow this path:

```
1. Read local project
2. Read applied state
3. Compare snapshots and metadata
4. Classify impact
5. Compute backfill or restatement scope
6. Show the plan
7. Apply after confirmation
```

If you apply the plan, Vulcan may also:

1. Materialize changed models.
2. Backfill required intervals.
3. Update consumer-facing objects.
4. Record plan activity and follow-on execution state.

***

## Common plan actions

Create a plan:

```bash
vulcan plan
```

Plan a bounded interval:

```bash
vulcan plan --start 2026-05-01 --end 2026-05-31
```

Restate a historical window:

```bash
vulcan plan --restate-model analytics.orders --start 2026-05-01 --end 2026-05-07
```

Apply without interactive prompts:

```bash
vulcan plan --no-prompts --auto-apply
```

Explain the plan:

```bash
vulcan plan --explain
```

***

## Choosing the right next step

Use `vulcan plan` first when the project changed.

Then use `vulcan run` after the new shape is applied and you want ongoing scheduled execution.

For the broader workflow, see [Data Product Lifecycle](../data-product-lifecycle.md).

{% hint style="info" %}
If you are new to Vulcan, start with [Get Started](../get-started.md), then return here before your first deployment.
{% endhint %}

***

## Related guides

* [Plan without Virtual Layer](plan_guide.md)
* [Plan with Virtual Layer](vulcan_plan_vde_true.md)
* [Run and Scheduling](../run_and_scheduling.md)
* [Data Product Lifecycle](../data-product-lifecycle.md)
