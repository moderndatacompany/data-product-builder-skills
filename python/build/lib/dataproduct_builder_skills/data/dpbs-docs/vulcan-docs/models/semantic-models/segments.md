---
description: >-
  Define reusable semantic model filters for common business subsets.
---

# Segments

Segments are predefined, reusable filters that package a boolean SQL-like predicate for use in queries and tooling. Instead of writing the same `WHERE` condition in every query, define it once as a segment and reference it by name. You can use the `segments` parameter within a [semantic model](README.md) to define segments.

For example, high-value accounts can be treated as a segment:

```yaml
segments:
  - name: high_value_accounts
    expression: "{users.plan_type} IN ('pro', 'enterprise')"
    description: Paid plan users
```

Or use a segment to implement cross-column `OR` logic:

```yaml
segments:
  - name: at_risk_users
    expression: "{users.status} = 'active' AND {users.plan_type} = 'free'"
    description: Free users who might churn
```

***

## Parameters

### `name`

The identifier of a segment. Must be unique among measures and segments within a semantic model and follow the [naming rules](README.md#naming-rules) (`^[a-zA-Z_][a-zA-Z0-9_]{0,63}$`).

```yaml
segments:
  - name: high_value_accounts
    expression: "{users.plan_type} IN ('pro', 'enterprise')"
```

### `expression`

A boolean SQL-like predicate, written with `{name.column}` references, that defines the subset of rows the segment matches. Required.

```yaml
segments:
  - name: recent_signups
    expression: "{users.signup_date} >= CURRENT_DATE - INTERVAL '7 days'"
```

{% hint style="warning" %}
`expression` must reference columns on the **current** semantic model only. A segment is a boolean filter scoped to the semantic model that declares it. Vulcan validates these references during `vulcan plan`.
{% endhint %}

{% hint style="warning" %}
**Expression shape is validated**

Column references must use the canonical form: `{model}.column` or bare `column`. Subqueries, CTEs, lateral joins, and column aliases are rejected. By default (`strict_semantic_validation: false` in `config.yaml`), shape violations are logged as warnings rather than blocking the plan; set `strict_semantic_validation: true` to hard-fail instead.
{% endhint %}

### `description`

Human-readable explanation of what the segment represents. Optional; defaults to an empty string.

```yaml
segments:
  - name: high_value_accounts
    expression: "{users.plan_type} IN ('pro', 'enterprise')"
    description: Paid plan users
```

### `public`

Controls whether the segment is exposed to consumers. Defaults to `true`.

```yaml
segments:
  - name: internal_qa_accounts
    expression: "{users.email} LIKE '%@internal-qa.test'"
    public: false
```

### `tags`

Categorization labels for the segment. Validated against `^[a-zA-Z0-9.:_-]+$` and normalized to lowercase.

```yaml
segments:
  - name: high_value_accounts
    expression: "{users.plan_type} IN ('pro', 'enterprise')"
    tags:
      - customer
      - segment
      - revenue
```

### `terms`

Business glossary references for the segment, typically dotted FQNs. Validated against `^[a-zA-Z0-9._-]+$` and normalized to lowercase.

```yaml
segments:
  - name: high_value_accounts
    expression: "{users.plan_type} IN ('pro', 'enterprise')"
    terms:
      - customer.high_value
      - revenue.premium_accounts
```

### `ai_context`

Structured hints for AI/LLM consumers on this segment: `instructions`, `synonyms`, `caveats`, and worked `examples`. See [AI context](ai-context.md) for the full field reference.

```yaml
segments:
  - name: high_value_accounts
    expression: "{users.plan_type} IN ('pro', 'enterprise')"
    ai_context:
      instructions: Use to scope revenue and churn queries to paid tiers only.
      synonyms:
        - paid accounts
        - premium accounts
```

***

## Segments vs. dimension filters

Since segments are just predefined filters, it can be difficult to decide when to use a segment instead of filtering on a dimension directly. A filter on a dimension works better when the filter value changes a lot between queries, for example filtering `users.plan_type = 'enterprise'` ad hoc. A segment earns its keep when it packages a complex, reusable predicate that many queries share, such as the `AND`/`OR` combination in `at_risk_users` above.

***

## Validation

`SegmentSpec` validates segment definitions during `vulcan plan`. It checks that:

* `name` and `expression` are both present
* `name` is unique among measures and segments within the semantic model
* `expression` references only columns on the current semantic model
* Column references use the canonical `{model}.column` or bare `column` form, and the expression doesn't contain a subquery, CTE, lateral join, or column alias (logged as a warning by default; hard-fails when `strict_semantic_validation: true`)

## Related pages

* [Semantic models](README.md) for how a segment fits into the full spec
* [Measures](measures.md) for the aggregations segments commonly filter
* [Business metrics](../business-metrics.md) for applying segments to a metric
