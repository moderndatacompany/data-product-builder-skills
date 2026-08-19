---
description: >-
  Define business-friendly semantic models on top of Vulcan data models.
---

# Semantic models

Semantic models map physical Vulcan models to business-friendly representations. Each semantic model wraps a single physical Vulcan model and declares [dimensions](dimensions.md), [measures](measures.md), [segments](segments.md), [joins](joins.md) to other semantic models, and [rollups](rollups.md).

Semantic models are typically declared in separate files, one semantic model per file, under `models/semantics/`. 

```yaml
kind: semantic
name: users
depends_on: customer.users
description: Core user dimension (semantic layer)

dimensions:
  - name: signup_date
    description: When the user signed up (used for cohort time axis)
  - name: plan_type
    behavior:
      type: categorical
  - name: user_id
    behavior:
      type: identifier

measures:
  - name: total_users
    type: count
    expression: "{users.user_id}"
    description: Total registered users
    behavior:
      type: simple

segments:
  - name: high_value_accounts
    expression: "{users.plan_type} IN ('pro', 'enterprise')"
    description: Paid plan users

joins:
  - name: usage_events
    type: one_to_many
    expression: "{users.user_id} = {usage_events.user_id}"
```

***

## Parameters

### `kind`

Declares the file as a semantic model. Any value other than `semantic` is rejected. The document root also accepts `type:` as a case-insensitive alias, so `type: semantic` loads the same way as `kind: semantic`.

```yaml
kind: semantic
```

{% hint style="warning" %}
**Semantic model YAML is not snake\_cased on load**

Unlike `config.yaml`, semantic model (and metric, dq, policy) YAML files are loaded without key conversion. Keys must already be `snake_case` — camelCase keys such as `dependsOn` or `timeDimension` are silently unrecognized rather than converted. Use `depends_on`, `time_dimension`, etc., as shown throughout this page.
{% endhint %}

### `name`

The identifier consumers reference in `{name.field}` expressions, in queries, and as the target of other semantic models' `joins[*].name`. Must follow the [naming rules](#naming-rules) below.

```yaml
name: users
```

{% hint style="info" %}
`name` does not need to match the physical model name in `depends_on`. `subscriptions` (semantic) can wrap `revenue.subscriptions` (physical), for example.
{% endhint %}

### `depends_on`

The single fully qualified physical Vulcan model this semantic model wraps, in `schema.model_name` form. `vulcan plan` resolves `depends_on` against the loaded project and fails validation if the target model does not exist, is missing, or resolves to more than one model.

```yaml
depends_on: customer.users
```

{% hint style="warning" %}
A semantic model always wraps **exactly one** physical model. To expose columns from a related table, add a [join](joins.md) to another semantic model instead of listing multiple `depends_on` targets.
{% endhint %}

### `description`

Human-readable explanation of what the semantic model represents. Optional; surfaced to catalog and BI consumers.

```yaml
description: Subscription lifecycle and revenue (semantic layer)
```

### `owner`

Free-text owner metadata (team or person responsible for the semantic model). Optional; not validated against any directory or identity system.

```yaml
owner: revenue-team
```

### `tags`

Categorization labels for the semantic model. Each tag is validated, stripped, and lowercased against `^[a-zA-Z0-9.:_-]+$`. The pattern supports plain tags and `key:value` pairs.

```yaml
tags:
  - revenue
  - domain:billing
```

### `terms`

Business glossary references for the semantic model, typically dotted FQNs. Each term is validated, stripped, and lowercased against `^[a-zA-Z0-9._-]+$`.

```yaml
terms:
  - revenue.subscription_domain
```

### `ai_context`

Structured hints for AI/LLM consumers: `instructions` (string or list of strings), `synonyms`, `caveats`, and worked `examples` (each with `description`, `format` (`sql`, `rest`, or `graphql`), and `query`). Optional at the semantic-model level, and also settable per dimension, measure, segment, join, and granularity. See [AI context](ai-context.md) for the full field reference.

```yaml
ai_context:
  instructions: >
    Subscription lifecycle and revenue semantic model (MRR, ARR, churn).
    Filter active rows with status or active_subscriptions segment.
  synonyms:
    - subscriptions
    - recurring revenue
  examples:
    - description: total ARR for active subscriptions
      format: sql
      query: |
        SELECT MEASURE(subscriptions.total_arr)
        FROM subscriptions
        WHERE active_subscriptions IS TRUE;
```

### `dimensions`

The non-empty allow-list of exposed columns. Entries can be a bare column name or an object with `description`, `tags`, `terms`, `format`, `granularities`, `behavior` (`categorical`, `identifier`, `bucketing`, `ordinal`), and `ai_context`. See [Dimensions](dimensions.md) for every sub-field.

```yaml
dimensions:
  - status                      # shorthand: bare column name
  - name: plan_type
    behavior:
      type: categorical
```

{% hint style="warning" %}
`dimensions` is required. Every semantic model must declare at least one dimension. A semantic model with no dimensions fails validation with "semantic model must declare a non-empty 'dimensions' allow-list."
{% endhint %}

### `measures`

Named aggregations available on the semantic model (`sum`, `avg`, `min`, `max`, `count`, `count_distinct`, `count_distinct_approx`, `number`, `string`, `time`, `boolean`). Only `count` may omit `expression`; every other type requires one. The name `count` is reserved for the automatic row-count measure and cannot be reused. See [Measures](measures.md) for `filters`, `rolling_window`, and `behavior` (stock/ratio/derived classification).

```yaml
measures:
  - name: total_arr
    type: sum
    expression: "{subscriptions.arr}"
    filters:
      - "{subscriptions.status} = 'active'"
    behavior:
      type: stock
      time_dimension: start_date
      period_treatment: last
      period_grain: day
```

{% hint style="info" %}
Filters are only allowed on `sum`, `avg`, `min`, `max`, `count`, `count_distinct`, and `count_distinct_approx`. A `number` measure cannot combine an `expression` with `filters`.
{% endhint %}

### `segments`

Reusable boolean filter conditions scoped to this semantic model. Each segment needs a `name` and an `expression`; `description`, `tags`, `terms`, and `ai_context` are optional. See [Segments](segments.md).

```yaml
segments:
  - name: active_subscriptions
    expression: "{subscriptions.status} = 'active'"
    description: Currently active subscriptions
```

### `joins`

Relationships from this semantic model to other declared semantic models. Set exactly one of `on` (structured equi-join) or `expression` (raw SQL); setting both, or neither, is an error. `type` is the join cardinality: `one_to_one`, `one_to_many`, or `many_to_one`. `name` must equal the target semantic model's `name` and must not equal this model's own `name`. See [Joins](joins.md) for the full `on` tree syntax (string leaf, pair, `and`/`or` groups).

```yaml
joins:
  - name: subscription_plans
    type: many_to_one
    on: plan_id
  - name: usage_sessions
    type: one_to_many
    expression: "{subscriptions.subscription_id} = {usage_sessions.subscription_id}"
```

### `rollups`

Pre-aggregation specs. A rollup builds a physical warehouse table from this semantic model's measures, dimensions, and optional time grain. Every rollup must reference at least one measure, dimension, or `time_dimension`; `granularity` requires `time_dimension`; `segments` are not supported. Rollups are opt-in: set `enable_rollup: true` in `config.yaml` to materialize them; with the flag off, `rollups:` specs still validate but build nothing. See [Rollups](rollups.md) for setup, schema, and naming-length constraints.

```yaml
rollups:
  arr_monthly:
    measures: [total_arr, subscription_count]
    dimensions: [plan_type, status]
    time_dimension: start_date
    granularity: month
    description: Monthly ARR and active-subscription counts by plan tier and status
```

{% hint style="info" %}
Rollup names, like the model name they materialize into (`<rollup_schema>.<model_name>_<rollup_name>`), must be lowercase (`^[a-z][a-z0-9_]*$`). Uppercase letters in the rollup name would change the emitted table name, breaking the transpiler's naming assumption.
{% endhint %}

***

## Naming rules

Vulcan validates most identifiers against the **same** pattern: the semantic model `name`, and each `measures[*].name`, `segments[*].name`, `joins[*].name`, `dimensions[*].name`, `dimensions[*].granularities[*].name`, and `rollups[*].name`. There is no separate lowercase-only rule for one set of identifiers and a mixed-case rule for another. Rollup table-name components are the exception, called out below.

| Identifier | Pattern | Notes |
| ---------- | ------- | ----- |
| Semantic model `name`, measure `name`, segment `name`, join `name`, dimension `name`, granularity `name`, rollup `name`, metric `name` | `^[a-zA-Z_][a-zA-Z0-9_]{0,63}$` | Starts with a letter or underscore, then letters/digits/underscores, max 64 chars. Mixed case allowed so warehouse identifiers survive. |
| Rollup `name` | `^[a-z][a-z0-9_]*$` | Lowercase only. The transpiler derives the physical table name (`<model_name>_<rollup_name>`) from it verbatim. |
| `tags[*]` | `^[a-zA-Z0-9.:_-]+$` | Alphanumeric, colons, hyphens, underscores. Supports `key:value` patterns. Normalized to lowercase. |
| `terms[*]` | `^[a-zA-Z0-9._-]+$` | Alphanumeric, dots, hyphens, underscores. Typically dotted FQNs. Normalized to lowercase. |

***

## Pages

* [Dimensions](dimensions.md)
* [Measures](measures.md)
* [Segments](segments.md)
* [Joins](joins.md)
* [Rollups](rollups.md)
* [AI context](ai-context.md)

***

## Validation

Vulcan validates semantic definitions during `vulcan plan`. It checks that:

* `depends_on` references an existing model
* Dimensions are non-empty
* Measure and segment references point to real columns
* Joins reference valid semantic models
* Rollups reference real measures and dimensions on the owning semantic model, and do not declare a `segments:` field
* Schema blocks do not contain unknown keys

{% hint style="info" %}
Policies and column masks are authored on physical models. Semantic models inherit them from their `depends_on` model. See [Policies](../../policies.md).
{% endhint %}

## Next steps

* Learn about [Business metrics](../business-metrics.md), which combine measures with time and dimensions
* Explore working examples in your project's `models/semantics/` directory
* See [Models](../README.md) for how data models, semantic models, and business metrics fit together
