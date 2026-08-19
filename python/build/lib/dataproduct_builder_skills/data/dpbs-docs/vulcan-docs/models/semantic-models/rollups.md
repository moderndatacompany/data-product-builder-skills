---
description: >-
  Define pre-aggregation specs that build rollup tables for a semantic model.
---

# Rollups

Rollups are Vulcan's pre-aggregation mechanism for the semantic layer. A rollup is a small, precomputed summary table, such as totals by month and plan type, that Vulcan builds and manages like any other model.

When a semantic query can be answered from a rollup, Vulcan transparently serves the query from the rollup table instead of scanning the full base table.

***

## Why use rollups

Semantic queries often recompute the same aggregates from raw rows: counts, sums, averages, and other measures by the same dimensions and time buckets. As data grows, those repeated scans become slow and expensive.

A rollup computes the aggregate once, stores it, and lets matching queries read the smaller precomputed table. Consumers still query through the semantic model as usual; Vulcan decides when a rollup can serve the query.

***

## Enable rollups

Rollups are off by default. Turn them on in `config.yaml`:

```yaml
enable_rollup: true
```

Then add a `rollups:` block to a semantic model:

```yaml
# models/semantics/users.yml
rollups:
  signups_01:
    measures: [total_users, active_users, paid_users]
    dimensions: [plan_type, industry]
    time_dimension: signup_date
    granularity: month
```

Run `vulcan plan` and apply the plan as usual. Vulcan generates and materializes a table named `<rollup_schema>.<semantic_model>_<rollup_name>`, for example `rollup.users_signups_01`. `rollup_schema` defaults to `rollup` and is configurable in `config.yaml` (see [Configurations](../../configurations/README.md#semantic-layer)).

Matching queries are routed to the rollup automatically once the table is built — you do not need to change query syntax.

With the flag off (the default), `rollups:` specs still validate during `vulcan plan` but build nothing.

***

## Schema

Fields available under a single entry in a semantic model's `rollups:` block:

| Field | Type | Required | Description |
| ----- | ---- | -------- | ----------- |
| `name` | string | Yes, as the block key | Rollup identifier. Must be lowercase snake case: `^[a-z][a-z0-9_]*$`. |
| `measures` | list of strings | No | Measures to pre-aggregate. Each measure must belong to the owning semantic model. |
| `dimensions` | list of strings | No | Dimensions to group by. Each dimension must belong to the owning semantic model. |
| `time_dimension` | string | No | Time column to bucket by. |
| `granularity` | `second`, `minute`, `hour`, `day`, `week`, `month`, `quarter`, or `year` | No | Time bucket size. Requires `time_dimension`; defaults to `day` when `time_dimension` is set without `granularity`. |
| `date_range` | list of 1-2 values | No | Restricts the rollup build to a date range. Requires `time_dimension`. |
| `segments` | list of strings | Not supported | Always rejected. Segments cannot be pre-aggregated in rollups. |
| `description` | string | No | Free-text metadata. |

At least one of `measures`, `dimensions`, or `time_dimension` must be set.

{% hint style="warning" %}
The combined `<semantic_model>_<rollup_name>` identifier must fit the physical temp-table budget for the target dialect — for example, 32 characters with the default `rollup_schema` on Postgres (reduced from 48 characters in earlier versions; projects relying on the previous limit may need to shorten the semantic model or rollup name). Longer combined names fail validation with a suggestion to shorten one or the other.
{% endhint %}

***

## Example

A rollup creates a physical table managed by Vulcan.

```yaml
rollups:
  arr_monthly:
    measures: [total_arr, subscription_count]
    dimensions: [plan_type, status]
    time_dimension: start_date
    granularity: month
    description: Monthly ARR and subscription counts by plan tier and status
```

***

## Time dimensions

`time_dimension` anchors the rollup's time grain. If `granularity` is set, `time_dimension` must also be set.

The underlying physical column must be `TIMESTAMP`. If the source column is a `DATE`, cast it to `TIMESTAMP` in the physical model before exposing it as a time dimension (see the [Dimensions](dimensions.md) note on casting `DATE` to `TIMESTAMP`).

```yaml
rollups:
  arr_monthly:
    measures: [total_arr]
    time_dimension: start_date
    granularity: month
```

***

## Rollup dimensions and masking

A dimension used as a rollup group-by column may only have a **constant** `column_mask_expressions` entry on its physical model — a fixed expression with no column references, such as `CAST(NULL AS TIMESTAMP)` or a string literal. A value-referencing mask, such as `CONCAT(LEFT(email, 2), '***')`, cannot be safely re-derived from already-aggregated rollup data and is rejected for rollup dimensions. See [Policies](../../policies.md).

***

## Validation

Vulcan validates rollup definitions during `vulcan plan`. It checks that:

* Every rollup references at least one of `measures`, `dimensions`, or `time_dimension`. An empty rollup fails validation
* `granularity` and `date_range` both require `time_dimension`
* `segments` is not supported on a rollup spec — declaring one fails validation
* `measures`, `dimensions`, and `time_dimension` all belong to the owning semantic model and name real members
* `time_dimension`'s underlying physical column is `TIMESTAMP`
* A rollup group-by dimension's physical-model mask, if any, is constant — a value-referencing mask is rejected
* The combined `<semantic_model>_<rollup_name>` table identifier fits the dialect's temp-table length budget (32 characters with the default `rollup_schema` on Postgres)
* Both the semantic model name and the rollup name match the lowercase-only `^[a-z][a-z0-9_]*$` pattern, so the emitted physical table name matches what's authored
* With `enable_rollup: false` (the default), the spec above still validates but no physical table is built

## Related pages

* [Semantic models](README.md) for how rollups fit into the full spec
* [Measures](measures.md) and [Dimensions](dimensions.md) for the fields a rollup can reference
* [Policies](../../policies.md) for the rollup-dimension masking constraint
