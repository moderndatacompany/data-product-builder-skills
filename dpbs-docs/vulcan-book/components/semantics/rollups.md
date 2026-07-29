---
description: >-
  Define pre-aggregation specs that build or join rollup tables for a
  semantic model.
---

# Rollups

Rollups are Vulcan's pre-aggregation mechanism for the semantic layer. You can use the `rollups` parameter within a [semantic model](README.md) to define them.

***

## Why you need it

Querying a semantic model's measures and dimensions straight against the underlying physical model works, but every query re-aggregates from raw rows. A rollup pre-computes a coarser-grained summary, say monthly ARR by plan tier, once, as its own materialized table. Subsequent queries at that grain then read a small pre-aggregated table instead of scanning and re-aggregating the base data every time. Consumers still query through the semantic model as usual; Vulcan decides when a rollup can serve the query.

***

## What it does

Declaring a rollup does one of two things, depending on whether you set the `rollups` sub-field:

* **Materialized rollup** (no `rollups` sub-field): Vulcan builds a physical warehouse table from this semantic model's own `measures`, `dimensions`, `segments`, and optional `time_dimension`/`granularity`. The table is owned and refreshed by Vulcan like any other model.
* **Composite rollup** (`rollups` set to exactly two `{model}.{rollup_name}` refs): Vulcan joins two already-materialized rollups at query/serve time. No new table is built; `measures`/`dimensions`/`segments` on a composite rollup may reference either joined model.

```yaml
rollups:
  - name: arr_monthly
    measures:
      - total_arr
      - subscription_count
    dimensions:
      - plan_type
      - status
    segments:
      - active_subscriptions
    time_dimension: start_date
    granularity: month
    description: Monthly ARR and active-subscription counts by plan tier and status

  # Composite: joins with another semantic model's materialized rollup
  - name: arr_with_user_cohorts
    rollups:
      - subscriptions.arr_monthly
      - users.signups_02
    measures:
      - total_arr
      - users.total_users
    dimensions:
      - plan_type
      - users.signup_channel
    time_dimension: start_date
    granularity: month
```

***

## Parameters

### `name`

The identifier of the rollup. Must be unique within the semantic model and follow the [naming rules](README.md#naming-rules), with one exception: a **materialized** rollup's `name` must additionally match `^[a-z][a-z0-9_]*$` (lowercase only).

```yaml
rollups:
  - name: arr_monthly
    measures:
      - total_arr
```

{% hint style="warning" %}
The transpiler derives the physical table name (`<rollup_schema>.<model_name>_<rollup_name>`) from `name` verbatim, lower-casing and snake-casing it. To keep the emitted table name in lock-step with what you author, both the semantic model's own name and a materialized rollup's `name` must already be lowercase (`^[a-z][a-z0-9_]*$`). Uppercase letters would silently change the table Vulcan creates. This constraint does not apply to composite rollups, which build no table.
{% endhint %}

{% hint style="warning" %}
The combined `<model_name>_<rollup_name>` identifier must fit the physical temp-table budget for the target dialect (`max_materialized_rollup_base_length`, for example 32 characters with the default `rollup_schema` on Postgres). Longer combined names fail validation with a suggestion to shorten the semantic model or rollup name.
{% endhint %}

### `measures`

Measure names to include in the rollup. Optional, but a rollup must reference at least one of `measures`, `dimensions`, or `time_dimension`.

```yaml
rollups:
  - name: arr_monthly
    measures:
      - total_arr
      - subscription_count
    time_dimension: start_date
```

{% hint style="info" %}
On a **materialized** rollup, every `measures` entry must belong to the owning semantic model; cross-model references fail validation. On a **composite** rollup, entries may be qualified as `{model}.{measure}` and reference either of the two joined rollups' models.
{% endhint %}

### `dimensions`

Dimension names to include in the rollup. Same ownership rule as `measures`: bare names on a materialized rollup, optionally qualified `{model}.{dimension}` names on a composite rollup.

```yaml
rollups:
  - name: arr_monthly
    dimensions:
      - plan_type
      - status
    measures:
      - total_arr
```

### `segments`

Segment names to include in the rollup. Same ownership rule as `measures` and `dimensions`.

```yaml
rollups:
  - name: active_subscriptions_arr
    measures:
      - total_arr
    segments:
      - active_subscriptions
```

### `time_dimension`

The dimension that anchors the rollup's time grain. Optional, but required if `granularity` is set. Must belong to the owning semantic model and resolve to a physical column that is strictly `TIMESTAMP`. A `DATE` column here fails validation (see the [Dimensions](dimensions.md) note on casting `DATE` to `TIMESTAMP`).

```yaml
rollups:
  - name: arr_monthly
    measures:
      - total_arr
    time_dimension: start_date
    granularity: month
```

### `granularity`

The time grain the rollup aggregates to. Optional; requires `time_dimension` to also be set. Declaring `granularity` without `time_dimension` fails validation ("'granularity' requires 'time_dimension' to be set").

Must be one of:

| `second` | `minute` | `hour` | `day` | `week` | `month` | `quarter` | `year` |
| -------- | -------- | ------ | ----- | ------ | ------- | --------- | ------ |

```yaml
rollups:
  - name: arr_monthly
    measures:
      - total_arr
    time_dimension: start_date
    granularity: month
```

### `rollups`

Marks this rollup as **composite**: exactly two qualified `{model}.{rollup_name}` references to already-materialized source rollups, joined at query/serve time. Optional. Omit it entirely for a materialized rollup. Setting it to anything other than exactly two valid qualified refs fails validation.

```yaml
rollups:
  - name: arr_with_user_cohorts
    rollups:
      - subscriptions.arr_monthly
      - users.signups_02
    measures:
      - total_arr
      - users.total_users
    time_dimension: start_date
    granularity: month
```

{% hint style="info" %}
Composite rollups build no warehouse table of their own. They read from the two source rollups' tables and join them at serve time. The two source rollups must be materialized (not themselves composite) and reachable via a declared [join](joins.md) between their semantic models.
{% endhint %}

### `description`

Human-readable explanation of what the rollup represents. Optional; defaults to an empty string.

```yaml
rollups:
  - name: arr_monthly
    measures:
      - total_arr
    description: Monthly ARR and active-subscription counts by plan tier and status
```

***

## Validation

Vulcan validates rollup definitions during `vulcan plan`. It checks that:

* Every rollup references at least one of `measures`, `dimensions`, or `time_dimension`. An empty rollup fails validation
* `granularity` requires `time_dimension`
* A composite rollup (`rollups` set) has exactly two qualified `{model}.{rollup_name}` entries
* On a materialized rollup, `measures`, `dimensions`, `segments`, and `time_dimension` all belong to the owning semantic model and name real members
* `time_dimension`'s underlying physical column is `TIMESTAMP`
* On a composite rollup, member references may be qualified to either joined model
* A materialized rollup's combined `<model_name>_<rollup_name>` table identifier fits the dialect's temp-table length budget
* Both the semantic model name and the rollup name match the lowercase-only `^[a-z][a-z0-9_]*$` pattern, so the emitted physical table name matches what's authored

## Related pages

* [Semantic models](README.md) for how rollups fit into the full spec
* [Measures](measures.md) and [Dimensions](dimensions.md) for the fields a rollup can reference
* [Joins](joins.md) for the cardinality a composite rollup relies on
