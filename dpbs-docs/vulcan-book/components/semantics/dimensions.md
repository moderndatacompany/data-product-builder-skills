---
description: >-
  Define semantic model dimensions, formatting, granularities, semantic
  behavior, and masking.
---

# Dimensions

You can use the `dimensions` parameter within a [semantic model](README.md) to define dimensions. `dimensions:` is a required, non-empty list. Vulcan rejects a semantic model with no dimensions.

Each item can be a bare string or an object. A bare string is shorthand for `{ name: <value> }` and must match a column in the underlying Vulcan model:

```yaml
dimensions:
  - plan_type
  - status
  - email
```

Every dimension requires [`name`](#name). Use the full object form when you need `description`, `tags`, `terms`, `format`, `granularities`, `behavior`, `ai_context`, `public`, or `mask_expression`:

```yaml
dimensions:
  - name: signup_date
    description: When the user signed up
    tags:
      - temporal
      - acquisition
    terms:
      - customer.signup_date

  - name: plan_type
    behavior:
      type: categorical
```

***

## Parameters

### `name`

The identifier of a dimension, matching a column on the underlying physical model. Must be unique among dimensions within a semantic model and follow the [naming rules](README.md#naming-rules) (`^[a-zA-Z_][a-zA-Z0-9_]{0,63}$`).

```yaml
dimensions:
  - name: plan_type
```

### `description`

Human-readable explanation of what the dimension represents. Optional.

```yaml
dimensions:
  - name: signup_date
    description: When the user signed up (used for cohort time axis)
```

### `tags`

Categorization labels for the dimension. Validated against `^[a-zA-Z0-9.:_-]+$` and normalized to lowercase.

```yaml
dimensions:
  - name: plan_type
    tags:
      - product
      - pricing
```

### `terms`

Business glossary references for the dimension, typically dotted FQNs. Validated against `^[a-zA-Z0-9._-]+$` and normalized to lowercase.

```yaml
dimensions:
  - name: plan_type
    terms:
      - subscription.plan_type
      - product.plan_tier
```

### `ai_context`

Structured hints for AI/LLM consumers on this dimension: `instructions`, `synonyms`, `caveats`, and worked `examples`. See [AI context](ai-context.md) for the full field reference.

```yaml
dimensions:
  - name: plan_type
    ai_context:
      instructions: Segment revenue and churn by commercial tier.
      synonyms:
        - plan tier
        - subscription tier
```

### `public`

Controls whether the dimension is exposed to consumers. Defaults to `true`.

```yaml
dimensions:
  - name: internal_debug_flag
    public: false
```

### `format`

A free-form display hint for how consumers should render the dimension's values, such as `percent` or `currency`. Optional. Vulcan stores this as an opaque string and does not validate or interpret it, formatting is applied by the consuming BI tool or client.

```yaml
dimensions:
  - name: mrr
    format: currency
```

### `behavior`

Semantic classification of the dimension's role.

| `behavior.type` | Use for |
| ---------------- | ------- |
| `identifier` | Primary keys, foreign keys, IDs |
| `categorical` | Enums, status fields, type columns, grouping columns |
| `bucketing` | Numeric range buckets |
| `ordinal` | Ordered categories (rank, tier level) |

```yaml
dimensions:
  - name: user_id
    behavior:
      type: identifier

  - name: plan_type
    behavior:
      type: categorical
```

{% hint style="info" %}
`behaviour` and `semantic_config` are accepted as deprecated aliases for `behavior` on YAML load. Vulcan logs a warning and treats them as `behavior`. Combining `behavior` with either alias, or using both aliases at once, is a validation error. Use `behavior` in new YAML.
{% endhint %}

### `granularities`

For timestamp-like dimensions, attach one or more named time buckets.

```yaml
dimensions:
  - name: session_start
    granularities:
      - name: day
        interval: 1 day
      - name: month
        interval: 1 month
      - name: fiscal_quarter
        interval: 1 quarter
        description: Company fiscal quarter
```

| Field | Required | Description |
| ----- | -------- | ------------ |
| `name` | Yes | Granularity identifier, unique within the dimension; follows the same [naming rules](README.md#naming-rules) as other identifiers. |
| `interval` | Yes | A positive duration matching `\d+ (minute\|hour\|day\|week\|month\|year)s?`, for example `15 minutes`, `1 day`, `1 month`. |
| `offset` | No | Free-form string; not validated against a fixed grammar. |
| `origin` | No | Free-form string; not validated against a fixed grammar. |
| `description` | No | Human-readable explanation of the granularity. |
| `ai_context` | No | AI/LLM hints scoped to this granularity. |

{% hint style="warning" %}
**Cast `DATE` columns to `TIMESTAMP`**

If a column is exposed as a time dimension, used as a metric `ts`, or used with time granularities, cast the underlying `DATE` column to `TIMESTAMP` in the data model.
{% endhint %}

### `mask_expression`

The SQL substituted for this dimension's value when a [policy](policies.md) masks it. Declared on the dimension itself, not on the policy row. Masked dimensions stay selectable: the column isn't hidden, only its value is replaced.

```yaml
dimensions:
  - name: signup_date
    mask_expression: "CAST(NULL AS TIMESTAMP)"

  - name: email
    mask_expression: "CONCAT('***.', SPLIT_PART(email, '.', 2))"

  - name: plan_type
    mask_expression: "'---'"
```

| Input | Meaning |
| ----- | ------- |
| SQL string literal | Constant sentinel, e.g. `'-1'`, `'---'`, `'N/A'` |
| SQL expression | Substitute expression when masked, e.g. `CAST(...)`, `CONCAT(...)` |

{% hint style="warning" %}
`mask_expression` must be valid SQL for the model's dialect. Unquoted tokens such as `---` are rejected. Use a quoted string literal (`'---'`) or an explicit cast (`CAST('---' AS TEXT)`).
{% endhint %}

{% hint style="warning" %}
`mask_expression` must use **bare column names**, not the `{name.column}` reference syntax used elsewhere in measures, segments, and joins. Vulcan rejects brace references here with "mask_expression must use bare column names, not {...} references". Use `email` instead of `{users.email}`.
{% endhint %}

{% hint style="warning" %}
A policy's `mask` list accepts member names only, with no inline expressions or wildcards. Put the substitute SQL on the dimension's `mask_expression`. Authoring it inline on the policy fails validation ("mask entries must be member names only; move mask expressions to dimension mask_expression").
{% endhint %}

***

## Validation

`DimensionSpec` validates dimension definitions during `vulcan plan`. It checks that:

* The `dimensions` list on a semantic model is present and non-empty
* Each `name` is a valid identifier
* Each `granularities[*].interval` matches the positive-duration grammar
* Each `behavior.type` is one of `identifier`, `categorical`, `bucketing`, or `ordinal`
* Dimension names are unique within the semantic model
* Each `granularities[*].name` is unique within its dimension

## Related pages

* [Semantic models](README.md) for how a dimension fits into the full spec
* [Policies](policies.md) for how `mask_expression` is applied at query time
* [AI context](ai-context.md) for adding AI/LLM guidance to a dimension
