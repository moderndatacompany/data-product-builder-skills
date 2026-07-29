---
description: >-
  Add AI and LLM guidance to semantic models, dimensions, measures, segments,
  joins, and granularities.
---

# AI context

The `ai_context` block lets you attach business context to a semantic model object for AI and LLM consumers: the meaning, assumptions, and usage guidance that can't be inferred from the object's structure alone. A dimension's `name` and `behavior` tell an AI *what* the field is. `ai_context` tells it *how to think about* the field: what it means, when to use it, what to avoid, and what else people call it.

Adding `ai_context` improves natural-language querying and helps AI systems generate more accurate SQL, GraphQL, or REST requests against your semantic model. It gives the same benefit you'd get from briefing a new analyst before they start writing queries.

All fields within `ai_context` are optional, and unknown keys fail validation. You can attach `ai_context` to:

* semantic models
* dimensions
* granularities
* measures
* segments
* joins

Rollups and policies do not accept `ai_context`.

Take a `total_arr` measure: a `sum` of the `arr` column, filtered to active subscriptions, with `behavior.type: stock`. Nothing in that definition tells an AI agent that "ARR" is what people mean when they ask about revenue. Nor does it show that summing this measure's values across several days produces a nonsense number, since ARR is a point-in-time balance, not a flow (see [Measures](measures.md#behavior)). `ai_context` closes that gap:

```yaml
measures:
  - name: total_arr
    type: sum
    expression: "{subscriptions.arr}"
    filters:
      - "{subscriptions.status} = 'active'"
    description: Total Annual Recurring Revenue
    behavior:
      type: stock
      time_dimension: start_date
      period_treatment: last
      period_grain: day
    ai_context:
      instructions: Primary ARR KPI; active-status filter is baked into the measure.
      synonyms:
        - ARR
        - annual recurring revenue
      caveats:
        - Pin start_date to period end; do not sum ARR across daily rows in a range.
      examples:
        - description: total ARR for enterprise plan type
          format: sql
          query: |
            SELECT MEASURE(subscriptions.total_arr)
            FROM subscriptions
            WHERE enterprise_subscriptions IS TRUE;
        - description: total ARR for enterprise (REST API)
          format: rest
          query: |
            {
              "measures": ["subscriptions.total_arr"],
              "segments": ["subscriptions.enterprise_subscriptions"]
            }
```

With this in place, an agent asked "what's our ARR from enterprise accounts?" has everything it needs to answer correctly on the first try instead of guessing:

* `synonyms` tells it "ARR" resolves to `total_arr` rather than some other revenue field
* `instructions` tells it the active-status filter is already baked in, so it shouldn't add its own `status = 'active'` filter on top
* `caveats` stops it from doing the single most common wrong thing with a stock measure: summing `total_arr` across a date range instead of reading it at a single point in time
* The worked `examples` show the exact shape of a correct query in each API the agent might call, including how to reach for the `enterprise_subscriptions` segment instead of hand-rolling a `plan_type = 'enterprise'` filter

A `ratio` measure benefits the same way. `churn_rate` is defined as `churn_count / subscription_count`, but an agent that doesn't know that only sees a number:

```yaml
measures:
  - name: churn_rate
    type: number
    behavior:
      type: ratio
      numerator: churn_count
      denominator: subscription_count
    ai_context:
      instructions: Query numerator and denominator separately when a time grain is present.
      caveats:
        - Do not average pre-computed ratio values across buckets.
```

Without the `caveats` entry, an agent asked for "average monthly churn rate over the last quarter" will often average three months of `churn_rate` values. That's mathematically wrong whenever monthly subscription counts differ. The `instructions` entry steers it toward the correct approach instead: query `churn_count` and `subscription_count` separately at the monthly grain, then divide the totals.

***

## Parameters

### `instructions`

Free-form guidance on how to interpret or use the object: its business meaning, when to reach for it, preferred query patterns, or business rules that should apply. Optional; accepts either a single string or a list of strings.

```yaml
ai_context:
  instructions:
    - Revenue includes completed orders only.
    - Use this measure for financial reporting, not operational dashboards.
```

```yaml
ai_context:
  instructions: Group customers by this dimension when analyzing geographic performance.
```

### `caveats`

A list of limitations, assumptions, or warnings an AI should weigh before using the object: the kind of thing that's easy to get wrong, such as aggregation limits, time-grain sensitivity, ratio semantics, point-in-time snapshots, or required filters. Optional.

```yaml
ai_context:
  caveats:
    - Do not sum ARR across multiple dates.
    - Exclude cancelled orders when calculating revenue.
```

### `synonyms`

A list of alternate names people or AI assistants might use for this object. Natural-language questions rarely match a semantic model's exact field names, so synonyms map business vocabulary ("sales," "revenue," "income," "turnover") back to the one measure they all mean. Optional.

```yaml
ai_context:
  synonyms:
    - revenue
    - sales
    - turnover
    - income
```

### `examples`

A list of representative queries that demonstrate how the object is meant to be used, helping an AI recognize common query patterns for it. Optional.

```yaml
ai_context:
  examples:
    - description: Revenue by month
      format: sql
      query: |
        SELECT
          order_month,
          MEASURE(total_revenue)
        FROM sales
```

Each entry accepts:

| Field | Required | Description |
| ----- | -------- | ------------ |
| `description` | Yes | Short explanation of what the example demonstrates. |
| `query` | Yes | The example query text. |
| `format` | No | One of `sql`, `graphql`, or `rest`. Defaults to `sql`. |

{% hint style="warning" %}
`format` only accepts `sql`, `graphql`, or `rest`. There is no `natural_language` value. Use `description` to add plain-language framing around a `query` written in one of the three supported formats.
{% endhint %}

***

## Best practices

Keep `ai_context` focused on business semantics that the schema can't express on its own (definitions, assumptions, and preferred usage), rather than restating implementation details already visible in `name`, `type`, or `expression`. Use `instructions` for guidance, `caveats` for warnings, `synonyms` for alternate business terminology, and `examples` for representative queries. Short, specific entries are generally more useful than long descriptive paragraphs. Revisit `ai_context` as business definitions evolve so AI consumers keep interpreting the semantic model correctly.

***

## Validation

Vulcan validates `ai_context` blocks during `vulcan plan`. It checks that:

* No unknown keys are present
* `instructions` is a string or a list of strings
* `caveats` and `synonyms` are lists of strings
* `examples` is a list of objects, each requiring a non-empty `description` and `query`
* Each example's `format` is restricted to `sql`, `graphql`, or `rest` (defaulting to `sql`)

## Related pages

* [Semantic models](README.md) for how `ai_context` fits into the full spec
* [Measures](measures.md) for the `behavior` types `ai_context` most often clarifies
* [Business metrics](../business-metrics.md) for adding `ai_context` at the metric level
