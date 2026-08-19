---
description: >-
  Semantic models, dimensions, measures, segments, joins, policies, masking,
  and AI context.
---

# Semantic models

Semantic models map your physical Vulcan models to business-friendly representations. They define what consumers can do with each model: which columns you expose as dimensions, what aggregations are available as measures, which reusable filters exist as segments, and how models relate to each other through joins.

***

## Structure

A semantic model wraps a single Vulcan model. Use `kind: semantic` and put **1 model per file** in `models/semantics/`:

```yaml
kind: semantic
name: users                  # Business-friendly name used in queries
depends_on: b2b_saas.users   # Fully qualified Vulcan model this wraps
description: Core user dimension (semantic layer)

dimensions: [...]            # Columns consumers can group by and filter on
measures: [...]              # Aggregated calculations
segments: [...]              # Reusable filter conditions
joins: [...]                 # Relationships to other semantic models
```

**Top-level fields:**

| Field            | Required | Description                                                                                                                                                                                                       |
| ---------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kind: semantic` | Yes      | Declares the file as a semantic model.                                                                                                                                                                            |
| `name`           | Yes      | Business-friendly identifier consumers reference (e.g. `users`). Lowercase identifier (see [Naming rules](#naming-rules)). This is the identifier you use in `{name.column}` references everywhere else. |
| `depends_on`     | Yes      | The fully qualified Vulcan model this wraps (e.g. `b2b_saas.users`). Must match a model defined in your `models/` directory.                                                                                      |
| `dimensions`     | **Yes**  | List of dimensions. Must be non-empty. See [Dimensions](#dimensions).                                                                                                                                    |
| `description`    | No       | Human-readable explanation of the semantic model.                                                                                                                                                                 |
| `owner`          | No       | Team or person responsible. Free-form string.                                                                                                                                                                     |
| `tags`           | No       | List of tags. See [Naming rules](#naming-rules) for the allowed pattern.                                                                                                                                 |
| `terms`          | No       | List of business glossary references (e.g. `revenue.subscription`). See [Naming rules](#naming-rules).                                                                                                   |
| `ai_context`     | No       | Hints for AI/LLM consumers. See [AI context](#ai-context).                                                                                                                                               |
| `measures`       | No       | List of named aggregations.                                                                                                                                                                                       |
| `segments`       | No       | List of reusable filter conditions.                                                                                                                                                                               |
| `joins`          | No       | List of relationships to other semantic models.                                                                                                                                                                   |
| `policies`       | No       | Row and column access policies. See [Policies, masking, and auth context](#policies-masking-and-auth-context).                                                                                           |

{% hint style="success" %}
**Snowflake and other case-sensitive engines**

Snowflake stores unquoted identifiers in uppercase by default. When targeting Snowflake, use uppercase column names in your dimension lists, expressions, and filters to match the warehouse schema. Lowercase examples in this guide assume a case-insensitive engine like DuckDB or Postgres.
{% endhint %}

***

## Naming rules

Vulcan validates every identifier in a semantic model. Use this section as a quick reference if validation fails:

| Identifier                                                                                            | Pattern                         | Notes                                                               |
| ----------------------------------------------------------------------------------------------------- | ------------------------------- | ------------------------------------------------------------------- |
| Semantic model `name`, measure `name`, segment `name`, join `name`, granularity `name`, metric `name` | `^[a-z][a-z0-9_]{0,63}$`        | Lowercase, starts with a letter, underscores allowed, max 64 chars. |
| Dimension `name` (i.e. a column reference)                                                            | `^[a-zA-Z_][a-zA-Z0-9_]{0,63}$` | Mixed case allowed so warehouse identifiers like `CUSTKEY` survive. |
| `tags[*]`                                                                                             | `^[a-zA-Z0-9.:_-]+$`            | Supports `key:value` patterns, e.g. `classification:PII`.           |
| `terms[*]`                                                                                            | `^[a-zA-Z0-9._-]+$`             | Typically dotted FQNs, e.g. `revenue.subscription`.                 |

{% hint style="warning" %}
**Unknown keys fail validation**

The wire-level schemas (`ai_context`, `behavior`, `rolling_window`, `granularities`) use Pydantic's `extra="forbid"`. Any unknown key inside these blocks causes validation to fail. Stick to the documented fields.
{% endhint %}

***

## Dimensions

`dimensions:` is a **required, non-empty list**. Each item can be either a bare column name (shorthand) or a full dictionary with metadata, granularities, semantic typing, masking, and formatting.

{% hint style="warning" %}
**Cast `DATE` columns to `TIMESTAMP`**

If a column is semantically exposed as a time dimension, or will be used as a metric `ts`, or a dimension with time granularities, cast the underlying `DATE` column to `TIMESTAMP` in the data model. Otherwise Vulcan will classify it as `string`.
{% endhint %}

### Shorthand: a bare column name

To expose a column, write it as a string:

```yaml
dimensions:
  - plan_type
  - status
  - email
  - industry
  - user_id
```

Each string is the name of a column in the underlying Vulcan model.

### Full form: a dict with metadata

When you want to add documentation, tags, glossary terms, granularities, semantic type, masking, or a display format, write the dimension as a dict:

```yaml
dimensions:
  - name: signup_date
    description: When the user signed up (used for cohort time axis)
    tags:
      - temporal
      - acquisition
      - cohort
    terms:
      - customer.signup_date
      - temporal.signup_timestamp

  - name: signup_channel
    description: How the user signed up (organic, paid, referral, etc.)
    tags:
      - acquisition
      - channel
    terms:
      - customer.signup_channel
```

You can freely mix shorthand and full-form entries in the same list.

### Semantic dimension types

Dimensions that need semantic meaning should use expanded syntax with `behavior.type`. Bare string dimensions still work when no semantic type is needed.

```yaml
dimensions:
  - name: user_id
    behavior:
      type: identifier

  - name: plan_type
    behavior:
      type: categorical

  - status
  - billing_cycle
```

| Type          | Use for                                              |
| ------------- | ---------------------------------------------------- |
| `identifier`  | Primary keys, foreign keys, IDs                      |
| `categorical` | Enums, status fields, type columns, grouping columns |

### Granularities

For time-like dimensions, attach a `granularities:` list inline on the dimension. Each granularity has a `name` and an `interval`:

```yaml
dimensions:
  - name: session_start
    granularities:
      - name: hour
        interval: 1 hour
      - name: day
        interval: 1 day
      - name: week
        interval: 1 week
      - name: month
        interval: 1 month
```

**Interval grammar:** any positive quantity of `minute`, `hour`, `day`, `week`, `month`, or `year` (for example, `15 minutes`, `3 months`, `1 year`).

**Granularity fields:**

| Field         | Required | Description                                                                                             |
| ------------- | -------- | ------------------------------------------------------------------------------------------------------- |
| `name`        | Yes      | Lowercase identifier (see [Naming rules](#naming-rules)). Must be unique within the dimension. |
| `interval`    | Yes      | Duration string like `1 hour`, `30 minutes`, `1 month`.                                                 |
| `description` | No       | Human-readable explanation.                                                                             |
| `ai_context`  | No       | Hints for AI/LLM consumers. See [AI context](#ai-context).                                     |


### Display format

For dimensions whose values benefit from a presentation hint, set `format:` inline:

```yaml
dimensions:
  - name: pages_viewed
    format: percent
  - name: avg_order_value
    format: currency
```

**`format`** is a free-form string passed through to downstream consumers (BI tools, APIs). Vulcan does not validate the value against a fixed list. Common values include `percent` and `currency`. Use whatever the consumer at the other end understands.

### Dimension properties (full form)

| Property          | Required | Description                                                                                                                     |
| ----------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `name`            | Yes      | Column name in the underlying Vulcan model. Mixed case allowed (see [Naming rules](#naming-rules)).                    |
| `description`     | No       | Human-readable explanation.                                                                                                     |
| `tags`            | No       | List of categorization labels.                                                                                                  |
| `terms`           | No       | List of business glossary references.                                                                                           |
| `granularities`   | No       | List of time buckets. Only meaningful on `TIMESTAMP`/`DATETIME` columns. Granularity names must be unique within the dimension. |
| `format`          | No       | Free-form display hint (e.g. `percent`, `currency`).                                                                            |
| `behavior` | No       | Semantic meaning for the dimension. Supported `type` values are `identifier` and `categorical`.                                 |
| `mask_expression` | No       | SQL expression returned for this dimension when a policy masks it.                                                              |
| `ai_context`      | No       | Hints for AI/LLM consumers. See [AI context](#ai-context).                                                             |
| `public`          | No       | Whether the dimension is visible to consumers (default: `true`).                                                                |

***

## Measures

`measures:` is a **list**. Each item is a dict that defines a named aggregation. Reference columns from the underlying model using `{name.column}` syntax, where `name` is the semantic model's `name:`.

```yaml
measures:
  - name: total_users
    type: count
    expression: "{users.user_id}"
    description: Total registered users
    tags:
      - user
      - count
      - metric
    terms:
      - customer.total_users
      - metric.user_count

  - name: active_users
    type: count
    filters:
      - "{users.status} = 'active'"
    description: Currently active users
    tags:
      - user
      - active
    terms:
      - customer.active_users

  - name: avg_mrr_per_account
    type: avg
    expression: "{subscriptions.mrr}"
    filters:
      - "{subscriptions.status} = 'active'"
    description: Average MRR per active subscription
    tags:
      - revenue
      - financial
    terms:
      - revenue.avg_mrr
```

### Measure types

| Type                    | Description                | Expression required? |
| ----------------------- | -------------------------- | -------------------- |
| `count`                 | Row count                  | No (see below)       |
| `count_distinct`        | Distinct count             | Yes                  |
| `count_distinct_approx` | Approximate distinct count | Yes                  |
| `sum`                   | Sum aggregation            | Yes                  |
| `avg`                   | Average aggregation        | Yes                  |
| `min`                   | Minimum value              | Yes                  |
| `max`                   | Maximum value              | Yes                  |
| `number`                | Custom numeric expression  | Yes                  |
| `string`                | Custom string expression   | Yes                  |
| `time`                  | Custom time expression     | Yes                  |
| `boolean`               | Custom boolean expression  | Yes                  |

### `count` measures and `expression`

`count` is the only type where `expression:` is optional. 3 forms all work:

```yaml
measures:
  - name: row_count
    type: count
    # No expression: counts every row (equivalent to COUNT(*))

  - name: total_users
    type: count
    expression: "*"
    # Same as above, written explicitly

  - name: users_with_email
    type: count
    expression: "{users.email}"
    # Counts non-NULL values of users.email
```

Pick the form that best describes intent: omit or `"*"` to count rows, or a `{name.column}` reference to count non-null values in a column.

### Measure properties

| Property          | Required      | Description                                                                                                                                                                                                                        |
| ----------------- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`            | Yes           | Lowercase identifier (see [Naming rules](#naming-rules)). Must be unique among measures and segments in this semantic model.                                                                                              |
| `type`            | Yes           | Aggregation type (see table above). Normalized to lowercase.                                                                                                                                                                       |
| `expression`      | Conditionally | Column reference (`{name.column}`) or SQL expression. Required for every type except `count`.                                                                                                                                      |
| `filters`         | No            | List of SQL conditions that restrict which rows are aggregated. **Only allowed on** `count`, `count_distinct`, `count_distinct_approx`, `sum`, `avg`, `min`, `max`. **Never allowed on** `number`. Use `{name.column}` references. |
| `description`     | No            | Human-readable explanation.                                                                                                                                                                                                        |
| `tags`            | No            | List of categorization labels.                                                                                                                                                                                                     |
| `terms`           | No            | List of business glossary references.                                                                                                                                                                                              |
| `rolling_window`  | No            | Window configuration. See [Rolling windows](#rolling-windows).                                                                                                                                                            |
| `behavior` | No            | Semantic behavior for the measure. Supported `type` values are `simple`, `flow`, `stock`, and `ratio`.                                                                                                                             |
| `ai_context`      | No            | Hints for AI/LLM consumers. See [AI context](#ai-context).                                                                                                                                                                |
| `public`          | No            | Whether the measure is visible to consumers (default: `true`).                                                                                                                                                                     |

{% hint style="warning" %}
**Reserved name**

`count` is a reserved measure name. Vulcan adds an implicit `count` measure automatically. Use a different name such as `total_users`, `row_count`, or `subscription_count`.
{% endhint %}

### Semantic measure types

Measures should declare their semantic behavior using `behavior.type`.

| Type     | Description                                                   |
| -------- | ------------------------------------------------------------- |
| `simple` | Additive count or sum with no special time behavior           |
| `flow`   | Accumulates over time, such as events or transactions         |
| `stock`  | Point-in-time value, such as ARR, MRR, seats, or active users |
| `ratio`  | Computed from numerator and denominator measures              |

```yaml
measures:
  - name: total_users
    type: count
    expression: "{users.user_id}"
    behavior:
      type: simple

  - name: churn_count
    type: count
    filters:
      - "{subscriptions.status} = 'cancelled'"
    behavior:
      type: flow

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

  - name: churn_rate
    type: number
    behavior:
      type: ratio
      numerator: churn_count
      denominator: subscription_count
```

### Rolling windows

Attach a `rolling_window:` to a measure to compute it over a sliding time window relative to the query period.

```yaml
measures:
  - name: trailing_7d_revenue
    type: sum
    expression: "{subscriptions.mrr}"
    rolling_window:
      trailing: 7 days
      offset: end
```

| Field      | Required | Allowed values                                                                                               |
| ---------- | -------- | ------------------------------------------------------------------------------------------------------------ |
| `trailing` | No       | `unbounded`, or a signed duration like `1 day`, `30 days`, `-7 days`. Same grammar as granularity intervals. |
| `leading`  | No       | Same grammar as `trailing`.                                                                                  |
| `offset`   | No       | `start` or `end` (default `end`). Controls whether the window is anchored to the start or end of the bucket. |

Use `trailing` for look-backs (rolling averages, trailing totals), `leading` for look-aheads, and combine them for centered windows. `unbounded` removes the bound on that side.

{% hint style="info" %}
**Pydantic `extra="forbid"`**

Any key other than `trailing`, `leading`, `offset` inside `rolling_window:` fails validation.
{% endhint %}

***

## Segments

Segments are reusable filter conditions that define meaningful subsets of your data. Instead of writing `WHERE status = 'active'` in every query, define it once as a segment.

`segments:` is a **list** of dicts:

```yaml
segments:
  - name: high_value_accounts
    expression: "{users.plan_type} IN ('pro', 'enterprise')"
    description: Paid plan users
    tags:
      - customer
      - segment
      - revenue
    terms:
      - customer.high_value
      - segment.premium

  - name: recent_signups
    expression: "{users.signup_date} >= CURRENT_DATE - INTERVAL '7 days'"
    description: Users signed up in last 7 days
    tags:
      - acquisition
      - temporal
      - growth

  - name: at_risk_users
    expression: "{users.status} = 'active' AND {users.plan_type} = 'free'"
    description: Free users who might churn
    tags:
      - churn
      - risk
```

### Segment properties

| Property      | Required | Description                                                                                                                                                                                 |
| ------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`        | Yes      | Lowercase identifier (see [Naming rules](#naming-rules)).                                                                                                                          |
| `expression`  | Yes      | SQL boolean condition. **Must reference columns of the current semantic model only** (e.g. `{usage_sessions.device_type} = 'mobile'`). Cross-model filters belong on a metric or a measure. |
| `description` | No       | Human-readable explanation.                                                                                                                                                                 |
| `tags`        | No       | List of categorization labels.                                                                                                                                                              |
| `terms`       | No       | List of business glossary references.                                                                                                                                                       |
| `ai_context`  | No       | Hints for AI/LLM consumers. See [AI context](#ai-context).                                                                                                                         |
| `public`      | No       | Visibility to consumers (default: `true`).                                                                                                                                                  |

{% hint style="info" %}
**Uniqueness constraint**

Measure and segment names must be unique within a single semantic model. A measure and a segment cannot share the same name.
{% endhint %}

***

## Joins

Joins define relationships between semantic models so you can analyze across tables. `joins:` is a **list** of dicts. The `name:` of each join entry must match the `name:` of another semantic model in the project.

```yaml
joins:
  - name: subscriptions
    type: one_to_many
    expression: "{users.user_id} = {subscriptions.user_id}"

  - name: usage_events
    type: one_to_many
    expression: "{users.user_id} = {usage_events.user_id}"
```

### Join properties

| Property     | Required | Description                                                                                                                                                                                    |
| ------------ | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`       | Yes      | Lowercase identifier (see [Naming rules](#naming-rules)). **Must match the `name:` of an existing semantic model** in the project. **Must not equal the current model's own `name`.** |
| `type`       | Yes      | One of `one_to_one`, `one_to_many`, `many_to_one`. Normalized to lowercase.                                                                                                                    |
| `expression` | Yes      | SQL-like join predicate referencing both sides as `{model_a.col} = {model_b.col}`.                                                                                                             |
| `ai_context` | No       | Hints for AI/LLM consumers. See [AI context](#ai-context).                                                                                                                            |
| `fqn`        | No       | Fully-qualified name of the join target. Engine-set; rarely authored by hand.                                                                                                                  |

{% hint style="warning" %}
**Joins do not accept metadata**

Joins do **not** support `description`, `tags`, `terms`, or `public`. Only the fields above are allowed; extra keys fail validation.
{% endhint %}

### Join types

| Type          | Cardinality               | Example                              |
| ------------- | ------------------------- | ------------------------------------ |
| `one_to_one`  | One row matches one row   | user to user\_profile                |
| `one_to_many` | One row matches many rows | user to subscriptions                |
| `many_to_one` | Many rows match one row   | subscriptions to subscription\_plans |

`many_to_many` is **not supported**. Model many-to-many relationships through an intermediate join model (a semantic model wrapping the bridge table) and chain two joins.

The join `expression:` uses `{name.column}` syntax on both sides. The cardinality helps Vulcan handle aggregations correctly and prevents double-counting.

### Cross-model references

Once you define joins, you can reference columns from joined models in measure filters:

```yaml
measures:
  - name: enterprise_revenue
    type: sum
    expression: "{subscriptions.arr}"
    filters:
      - "{users.plan_type} = 'enterprise'"
    description: ARR from enterprise plan users
```

Here `enterprise_revenue` is defined on the subscriptions semantic model but filters by `users.plan_type` from the joined users model. Vulcan resolves the join path automatically.

***

## Policies, masking, and auth context

Semantic files can define row and column access policies close to the model they protect. Policies match against the user's resolved security context, which a root-level `afterAuthorize` hook in `config.yaml` usually populates after DataOS authorization. See the [Plugins Auth Extension Guide](../plugins-and-auth.md) for the full plugin setup.

{% hint style="warning" %}
**Configure the auth extension first**

If you are working with auth-backed semantic policies or masking, make sure `config.yaml` includes:

```yaml
afterAuthorize: "plugins.auth_ext:resolve_user_groups"
```
{% endhint %}

```yaml
afterAuthorize: "plugins.auth_ext:resolve_user_groups"
```

The hook should live in a project-level plugin package:

```
plugins/
├── __init__.py
└── auth_ext.py
```

```python
from __future__ import annotations

from schema.auth import AuthExtensionContext, SecurityContext

ROLE_ID_TAG_PREFIX = "roles:id:"
GROUP_DELIMITER = ","
POLICY_GROUP_PRIORITY = ("operator", "developer")


async def resolve_user_groups(ctx: AuthExtensionContext) -> SecurityContext:
    """Derive policy groups from DataOS role tags."""

    groups = [
        tag.replace(ROLE_ID_TAG_PREFIX, "", 1)
        for tag in ctx.user_tags
        if tag.startswith(ROLE_ID_TAG_PREFIX)
    ]

    group = next(
        (policy_group for policy_group in POLICY_GROUP_PRIORITY if policy_group in groups),
        groups[0] if groups else "",
    )
    return SecurityContext(group=group, groups=GROUP_DELIMITER.join(groups))
```

The returned `SecurityContext.group` is the primary group used for policy matching. `SecurityContext.groups` contains all resolved groups as a comma-separated string.

```yaml
policies:
  - group: developer

  - group: operator
    mask:
      - email
      - customer_name
    filter:
      - member: customer_segment
        operator: notEquals
        values:
          - Churned
```

In this example, `developer` has full access. `operator` can query the model, but cannot see raw `email` or `customer_name`, and cannot see rows where `customer_segment = Churned`.

Masked dimensions should define a `mask_expression` so Vulcan knows what restricted users see instead of the original value:

```yaml
dimensions:
  - name: customer_name
    mask_expression: "CAST(NULL AS TEXT)"

  - name: email
    mask_expression: "'***'"
```

### Policy example

```yaml
kind: semantic
name: customer_profile
depends_on: silver.dim_customer_profile
description: Customer profile and lifetime purchase behavior.

dimensions:
  - name: customer_id
    behavior:
      type: identifier

  - name: customer_name
    mask_expression: "CAST(NULL AS TEXT)"

  - name: email
    mask_expression: "CAST(NULL AS TEXT)"

  - name: customer_segment
    behavior:
      type: categorical

  - total_orders
  - total_revenue

measures:
  - name: total_customers
    type: count_distinct
    expression: "{customer_profile.customer_id}"
    behavior:
      type: simple

  - name: total_customer_revenue
    type: sum
    expression: "{customer_profile.total_revenue}"
    behavior:
      type: simple

policies:
  - group: developer

  - group: operator
    mask:
      - email
      - customer_name
    filter:
      - member: customer_segment
        operator: notEquals
        values:
          - Churned
```

***

## Complete example

A B2B SaaS subscriptions semantic model with dimensions, measures, segments, and joins:

```yaml
kind: semantic
name: subscriptions
depends_on: hello.subscriptions
description: Subscription lifecycle and revenue (semantic layer)

dimensions:
  - name: subscription_id
    behavior:
      type: identifier
  - name: user_id
    behavior:
      type: identifier
  - plan_id
  - start_date
  - end_date
  - name: plan_type
    description: Subscription plan tier (free, pro, enterprise, etc.)
    tags:
      - product
      - pricing
      - segment
    terms:
      - subscription.plan_type
      - product.plan_tier
    behavior:
      type: categorical
  - status
  - billing_cycle
  - revenue_category
  - mrr
  - seats
  - arr

measures:
  - name: total_arr
    type: sum
    expression: "{subscriptions.arr}"
    filters:
      - "{subscriptions.status} = 'active'"
    description: Total Annual Recurring Revenue
    tags:
      - revenue
      - financial
      - arr
    terms:
      - revenue.total_arr
      - finance.annual_recurring_revenue
    behavior:
      type: stock
      time_dimension: start_date
      period_treatment: last
      period_grain: day
    ai_context:
      instructions: Primary ARR KPI; active-status filter is baked into the measure.
      caveats:
        - Pin start_date to period end.
        - Do not sum ARR across daily rows in a range.

  - name: subscription_count
    type: count
    filters:
      - "{subscriptions.status} = 'active'"
    description: Total active subscriptions
    tags:
      - subscription
      - count
      - metric
    behavior:
      type: simple

  - name: churn_count
    type: count
    filters:
      - "{subscriptions.status} = 'cancelled'"
      - "{subscriptions.end_date} >= CURRENT_DATE - INTERVAL '30 days'"
    description: Subscriptions churned in last 30 days
    tags:
      - churn
      - retention
    behavior:
      type: flow

segments:
  - name: active_subscriptions
    expression: "{subscriptions.status} = 'active'"
    description: Currently active subscriptions

  - name: high_value_accounts
    expression: "{subscriptions.mrr} >= 1000"
    description: High-value accounts (>= $1000 MRR)
    tags:
      - revenue
      - high_value

  - name: enterprise_subscriptions
    expression: "{subscriptions.plan_type} = 'enterprise'"
    description: Enterprise plan subscriptions

joins:
  - name: subscription_plans
    type: many_to_one
    expression: "{subscriptions.plan_id} = {subscription_plans.plan_id}"

  - name: usage_sessions
    type: one_to_many
    expression: "{subscriptions.subscription_id} = {usage_sessions.subscription_id}"
```

***

## AI context

Most spec objects (the semantic model itself, dimensions, granularities, measures, segments, joins) accept an optional `ai_context:` block to help AI/LLM consumers understand the object. Measures can also carry `ai_context` directly, which is useful for ARR, MRR, active users, churn rate, retention rate, conversion rate, and other business metrics with interpretation rules. All fields are optional, and unknown keys fail validation.

```yaml
kind: semantic
name: subscriptions
depends_on: hello.subscriptions

ai_context:
  instructions:
    - Subscription lifecycle and revenue semantic model (MRR, ARR, churn).
    - Filter active rows with status or active_subscriptions segment.
    - Query via SQL API, REST API (JSON), or GraphQL API.
  caveats:
    - ARR and MRR measures are point-in-time values; do not sum them across dates.
  synonyms:
    - subscriptions
    - billing accounts
    - recurring revenue
  examples:
    - description: total ARR for active subscriptions
      format: sql
      query: |
        SELECT MEASURE(subscriptions.total_arr)
        FROM subscriptions
        WHERE active_subscriptions IS TRUE;
    - description: MRR by plan type
      format: sql
      query: |
        SELECT
          subscriptions.plan_type,
          MEASURE(subscriptions.avg_mrr_per_account)
        FROM subscriptions
        WHERE subscriptions.status = 'active'
        GROUP BY 1;
    - description: total ARR for active subscriptions (REST API)
      format: rest
      query: |
        {
          "measures": ["subscriptions.total_arr"],
          "segments": ["subscriptions.active_subscriptions"]
        }
    - description: MRR by plan type (GraphQL API)
      format: graphql
      query: |
        {
          vulcan {
            subscriptions(where: { status: { equals: "active" } }) {
              plan_type
              avg_mrr_per_account
            }
          }
        }

dimensions:
  - name: plan_type
    ai_context:
      instructions:
        - Use for pricing-tier segmentation.
      synonyms:
        - "plan"
        - "tier"
        - "subscription_level"

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

| Field          | Type                      | Description                                                                                                             |
| -------------- | ------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `instructions` | String or list of strings | Free-form guidance for how to think about this object. Use a list when multiple instructions apply.                     |
| `caveats`      | List of strings           | Warnings about aggregation, time-grain behavior, business assumptions, or ways the field or measure can be misused.     |
| `synonyms`     | List of strings           | Alternate names consumers/LLMs might use.                                                                               |
| `examples`     | List of objects           | Example SQL, REST, GraphQL, or natural-language prompts. Each example can include `description`, `format`, and `query`. |

***

## Validation

Vulcan validates semantic model definitions automatically when you create a plan. It checks that:

* `depends_on` references an existing Vulcan model
* All identifier names match the patterns in [Naming rules](#naming-rules)
* `dimensions` is non-empty
* Column references in measures and segments point to real columns
* Segment expressions reference only columns of the current semantic model
* Filters on measures are only used with allowed measure types
* Join `name`s reference existing semantic models and are not equal to the current model's `name`
* Join `type` is one of `one_to_one`, `one_to_many`, `many_to_one`
* Cross-model references have valid join paths
* Dimension `behavior.type` is one of `identifier` or `categorical`
* Measure `behavior.type` is one of `simple`, `flow`, `stock`, or `ratio`
* Policy groups, masks, and filters reference valid semantic fields
* No duplicate names exist among measures, among segments, among joins, or among granularities within a single dimension
* `count` is not used as an explicit measure name
* No unknown keys appear inside `ai_context`, `behavior`, `rolling_window`, or `granularities` (Pydantic `extra="forbid"`)

Validation runs before Vulcan materializes anything, so it catches errors early.

***

## Next steps

* Learn about [Business Metrics](business-metrics.md) that combine measures with time and dimensions
* Explore working examples in your project's `models/semantics/` directory
* See [Models](README.md) for how data models, semantic models, and business metrics fit together
