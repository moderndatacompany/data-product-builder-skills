---
description: >-
  Define semantic model aggregations, measure types, filters, semantic behavior,
  and rolling windows.
---

# Measures

You can use the `measures` parameter within a [semantic model](README.md) to define measures. Each measure is an aggregation over a column of the underlying physical model, referenced with `{name.column}` syntax, where `name` is the semantic model name.

Every measure requires [`name`](#name) and [`type`](#type). Every type except `count` also requires [`expression`](#expression).

```yaml
measures:
  - name: total_users
    type: count
    expression: "{users.user_id}"
    description: Total registered users

  - name: active_users
    type: count
    filters:
      - "{users.status} = 'active'"

  - name: avg_mrr_per_account
    type: avg
    expression: "{subscriptions.mrr}"
    filters:
      - "{subscriptions.status} = 'active'"
    behavior:
      type: stock
      time_dimension: start_date
      period_treatment: avg
      period_grain: day
```

***

## Parameters

### `name`

The identifier of a measure. Must be unique among measures within a semantic model and follow the [naming rules](README.md#naming-rules) (`^[a-zA-Z_][a-zA-Z0-9_]{0,63}$`).

```yaml
measures:
  - name: total_arr
    type: sum
    expression: "{subscriptions.arr}"
```

{% hint style="warning" %}
**Reserved name**

`count` is reserved. Vulcan implies an automatic row-count measure, and declaring a measure literally named `count` fails validation with "Measure name 'count' is reserved (automatic count is implied)." Use names such as `row_count`, `total_users`, or `subscription_count` instead.
{% endhint %}

{% hint style="info" %}
**Snowflake casing convention**

Vulcan doesn't enforce a casing rule on `name`. Mixed case passes validation on every dialect. In practice, when the underlying engine is Snowflake, use uppercase measure names (Snowflake's own convention for unquoted identifiers). For every other engine, use lowercase.
{% endhint %}

### `description`

Human-readable explanation of what the measure represents. Optional; defaults to an empty string.

```yaml
measures:
  - name: total_arr
    type: sum
    expression: "{subscriptions.arr}"
    description: Total Annual Recurring Revenue
```

### `public`

Controls whether the measure is exposed to consumers. Defaults to `true`.

```yaml
measures:
  - name: internal_helper_sum
    type: sum
    expression: "{orders.amount}"
    public: false
```

### `tags`

Categorization labels for the measure. Validated against `^[a-zA-Z0-9.:_-]+$` and normalized to lowercase.

```yaml
measures:
  - name: total_arr
    type: sum
    expression: "{subscriptions.arr}"
    tags:
      - revenue
      - financial
      - arr
```

### `terms`

Business glossary references for the measure, typically dotted FQNs. Validated against `^[a-zA-Z0-9._-]+$` and normalized to lowercase.

```yaml
measures:
  - name: total_arr
    type: sum
    expression: "{subscriptions.arr}"
    terms:
      - revenue.total_arr
      - finance.annual_recurring_revenue
```

### `ai_context`

Structured hints for AI/LLM consumers on this measure: `instructions`, `synonyms`, `caveats`, and worked `examples`. See [AI context](ai-context.md) for the full field reference.

```yaml
measures:
  - name: total_arr
    type: sum
    expression: "{subscriptions.arr}"
    ai_context:
      instructions: Primary ARR KPI; active-status filter is baked into the measure.
      synonyms:
        - ARR
        - annual recurring revenue
      caveats:
        - Pin start_date to period end; do not sum ARR across daily rows in a range.
```

### `expression`

A SQL-ish definition of the measure, written with `{name.column}` references. Required for every type except `count`; declaring a non-`count` measure with an empty `expression` fails validation ("requires a non-empty expression").

```yaml
measures:
  - name: total_seats
    type: sum
    expression: "{subscriptions.seats}"
```

`expression` is not limited to a single `{name.column}` reference. `type: number`, `string`, `time`, and `boolean` measures accept an arbitrary SQL-ish expression combining multiple references:

```yaml
measures:
  - name: avg_order_value
    type: number
    expression: "sum(revenue)/count(order_id)"
```

{% hint style="warning" %}
**Expression shape is validated**

Column references inside `expression` (and `filters`) must use the canonical form: `{model}.column` or bare `column`. Subqueries, CTEs, lateral joins, and column aliases are rejected. For `type: string`, `time`, and `boolean` measures specifically, the `expression` body must contain an aggregate function — a bare column reference or scalar expression is not enough.

By default (`strict_semantic_validation: false` in `config.yaml`), shape violations are logged as warnings rather than blocking the plan. Set `strict_semantic_validation: true` to hard-fail instead.
{% endhint %}

### `type`

The aggregation kind. Required; must be one of the values below (normalized to lowercase on load). A measure has exactly one `type`.

| Type | Description | `expression` required? |
| ---- | ----------- | ----------------------- |
| `count` | Row count | No. Omit it, or set it explicitly (e.g. `"*"` or a `{name.column}` ref to count non-null values) |
| `count_distinct` | Distinct count | Yes |
| `count_distinct_approx` | Approximate distinct count | Yes |
| `sum` | Sum aggregation | Yes |
| `avg` | Average aggregation | Yes |
| `min` | Minimum value | Yes |
| `max` | Maximum value | Yes |
| `number` | Custom numeric expression | Yes |
| `string` | Custom string expression | Yes |
| `time` | Custom time expression | Yes |
| `boolean` | Custom boolean expression | Yes |

```yaml
measures:
  - name: row_count
    type: count

  - name: total_rows
    type: count
    expression: "*"

  - name: users_with_email
    type: count
    expression: "{users.email}"

  - name: unique_users
    type: count_distinct
    expression: "{subscriptions.user_id}"
```

### `filters`

A list of predicate strings, written with `{name.column}` references, applied when computing the measure. Optional; every entry must be non-empty.

```yaml
measures:
  - name: active_users
    type: count
    filters:
      - "{users.status} = 'active'"

  - name: churn_count
    type: count
    filters:
      - "{subscriptions.status} = 'cancelled'"
      - "{subscriptions.end_date} >= CURRENT_DATE - INTERVAL '30 days'"
```

{% hint style="warning" %}
`filters` is only allowed on `sum`, `avg`, `min`, `max`, `count`, `count_distinct`, and `count_distinct_approx` measures. A `number` measure specifically cannot combine `expression` with `filters`. Declaring both fails validation ("type 'number' cannot be combined with filters"). `string`, `time`, and `boolean` measures reject `filters` too.
{% endhint %}

### `behavior`

Semantic classification of how the measure should be queried and aggregated. Optional. When set, `behavior.type` selects which sibling fields apply. `is_additive` is always computed from `type`; never author it.

| `behavior.type` | Meaning | Additive? | Required siblings | Forbidden siblings |
| ---------------- | ------- | --------- | ------------------ | ------------------- |
| `simple` | Standard additive measure (counts, sums); safe to group and aggregate freely | Yes | None | `time_dimension`, `period_treatment`, `period_grain`, `numerator`, `denominator`, `measure_refs` |
| `flow` | In-period total (signups, orders); additive like `simple` | Yes | None | Same as `simple` |
| `stock` | Point-in-time level (MRR, active customers, headcount); do not sum across time | No | `time_dimension`, `period_treatment`, `period_grain` | `numerator`, `denominator`, `measure_refs` |
| `ratio` | Numerator ÷ denominator at the query grain | No | `numerator`, `denominator` | `time_dimension`, `period_treatment`, `period_grain` |
| `derived` | Composed from other measures listed in `measure_refs` | No | `measure_refs` | `time_dimension`, `period_treatment`, `period_grain`, `numerator`, `denominator` |

`period_treatment` (for `stock`) is one of `last` (end-of-period snapshot), `avg` (average over the period), or `first` (start-of-period snapshot). `period_grain` is a time granularity such as `day`, `week`, `month`, or `year`. `time_dimension` must name a dimension declared on the same semantic model.

```yaml
measures:
  - name: total_arr
    type: sum
    expression: "{subscriptions.arr}"
    behavior:
      type: stock
      time_dimension: start_date
      period_treatment: last
      period_grain: day

  - name: churn_rate
    type: number
    expression: "{subscriptions.churn_count} / {subscriptions.subscription_count}"
    behavior:
      type: ratio
      numerator: churn_count
      denominator: subscription_count
```

{% hint style="info" %}
For `ratio`, any authored `measure_refs` are ignored. Vulcan fills it automatically as `[numerator, denominator]`. Query the two parts separately at the target grain and divide; averaging a pre-computed ratio across buckets produces the wrong answer.
{% endhint %}

{% hint style="info" %}
`behaviour` and `semantic_config` are accepted as deprecated aliases for `behavior` on YAML load. Vulcan logs a warning and treats them as `behavior`. Combining `behavior` with either alias, or using both aliases at once, is a validation error. Use `behavior` in new YAML.
{% endhint %}

### `rolling_window`

Computes the measure over a sliding time window instead of the query's own grain, for example a trailing 7 days or a trailing 1 month.

```yaml
measures:
  - name: trailing_7d_revenue
    type: sum
    expression: "{subscriptions.mrr}"
    rolling_window:
      trailing: 7 days
      offset: end
```

All three sub-fields are optional.

#### `offset`

Sets the anchor point of the window: `start` or `end`. Defaults to `end`.

#### `trailing` and `leading`

`trailing` sizes the part of the window before the `offset` point, and `leading` sizes the part after it. Both default to unset (zero-width) and share the same grammar: `unbounded`, or a duration matching `-?\d+ (minute|hour|day|week|month|year)s?`, for example `1 day`, `30 days`, `-7 days`. Use `trailing` alone for look-backs, `leading` alone for look-aheads, and both together for centered windows.

Here's an `unbounded` window used for a cumulative count:

```yaml
measures:
  - name: cumulative_subscription_count
    type: count
    rolling_window:
      trailing: unbounded
```

***

## Validation

Vulcan rejects a measure YAML block when:

* `name` is not a valid identifier, or is the reserved word `count`
* `type` is unrecognized
* `type` is not `count` and `expression` is empty
* `filters` is set on a type that doesn't allow it, or `type: number` is combined with `filters`
* Any `filters` entry is empty
* A column reference in `expression`/`filters` isn't the canonical `{model}.column` or bare `column` form, or the expression contains a subquery, CTE, lateral join, or column alias (logged as a warning by default; hard-fails when `strict_semantic_validation: true`)
* `type` is `string`, `time`, or `boolean` and the `expression` body doesn't contain an aggregate function (same warn-by-default / hard-fail-when-strict behavior)
* `behavior` sets required or forbidden fields incorrectly for its declared `type`
* `name` is not unique within the semantic model

## Related pages

* [Semantic models](README.md) for how a measure fits into the full spec
* [Segments](segments.md) for reusable filters that pair with measures
* [AI context](ai-context.md) for adding AI/LLM guidance to a measure
