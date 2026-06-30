# Business metrics

Business metrics are time-series analytical definitions that combine a measure, a time dimension, and optional grouping dimensions into a single queryable unit. They sit on top of [semantic models](../model/types/models.md) and are the primary interface for dashboards, reports, and APIs.

***

## Where these files live

Put each metric in its own file under `models/metrics/`, one metric per file:

```
models/metrics/
├── arr_growth.yml
├── churn_analysis.yml
├── cohort_retention.yml
└── product_engagement.yml
```

**File naming:** the filename does not matter. Vulcan reads every YAML file in `models/metrics/`. Naming files after the metric they define keeps diffs and ownership clean.

***

## Structure

A metric is a single document with `kind: metric` at the top. Reference measures, time columns, dimensions, and segments using `<semantic_name>.<field>` notation, where `<semantic_name>` is the value of the `name:` field at the top of the corresponding semantic model.

```yaml
kind: metric
name: <metric_name>                         # Unique metric name
measure: <semantic_name>.<measure_name>     # Which measure to calculate
ts: <semantic_name>.<column_name>           # Time column for time-series analysis
granularity: <granularity>                  # Default time bucket

dimensions:                                 # Optional list of grouping dimensions
  - <semantic_name>.<column_name>           # Bare reference: name auto-derived from <column_name>
  - name: <slice_name>                      # Named slice: explicit name + ref (+ optional metadata)
    ref: <semantic_name>.<column_name>

segments:                                   # Optional list of predefined filters (strings only)
  - <semantic_name>.<segment_name>          # Auto-derived name: <semantic_name>_<segment_name>

description: "..."                          # Optional
owner: "..."                                # Optional
tags: [...]                                 # Optional
terms: [...]                                # Optional
ai_context: {...}                           # Optional, see models.md#ai-context
```

***

## Required properties

Every metric must define these four fields:

### name

Unique identifier consumers use to reference the metric. Must be unique within the project.

```yaml
name: arr_growth
```

### measure

A reference to a measure defined in a semantic model, in the format `<semantic_name>.<measure_name>`.

```yaml
measure: subscriptions.total_arr
```

`subscriptions` here is the `name:` at the top of the `subscriptions` semantic model file; `total_arr` is one of its measures.

### ts

A reference to a time/date column on a semantic model, in the format `<semantic_name>.<column_name>`. This is the time column used for time-series aggregation.

```yaml
ts: subscriptions.start_date
```

{% hint style="info" %}
**measure and ts cannot be the same**

Vulcan rejects metrics where `measure` and `ts` point to the same reference.
{% endhint %}

### granularity

The default time bucket for aggregation. Must be one of:

| Value     | Bucket     |
| --------- | ---------- |
| `second`  | Per-second |
| `minute`  | Per-minute |
| `hour`    | Hourly     |
| `day`     | Daily      |
| `week`    | Weekly     |
| `month`   | Monthly    |
| `quarter` | Quarterly  |
| `year`    | Yearly     |

```yaml
granularity: month
```

The default granularity is what is used when a consumer queries the metric without specifying one. Consumers can always override it at query time.

***

## Optional properties

| Property      | Type                                     | Description                                                                                                                 |
| ------------- | ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `dimensions`  | List                                     | Grouping dimensions (bare reference, or named slice with `name` + `ref`). See [Dimensions](business_metrics.md#dimensions). |
| `segments`    | List of `<semantic_name>.<segment_name>` | Predefined filters from semantic models. **Qualified-ref strings only**; no named form.                                     |
| `description` | String                                   | Human-readable explanation of the metric.                                                                                   |
| `owner`       | String                                   | Team or person responsible for the metric.                                                                                  |
| `tags`        | List of strings                          | Categorization labels for discovery. See [Naming rules](../model/types/models.md#naming-rules) for the allowed pattern.     |
| `terms`       | List of strings                          | Business glossary references (e.g. `glossary.revenue`). See [Naming rules](../model/types/models.md#naming-rules).          |
| `ai_context`  | Object                                   | Hints for AI/LLM consumers (`instructions`, `synonyms`, `examples`). See [AI context](../model/types/models.md#ai-context). |

Example:

```yaml
ai_context:
  instructions: >
    Subscription lifecycle and revenue metric (MRR, ARR, churn).
    Filter active rows with status or active_subscriptions segment.
    Query via SQL API, REST API (JSON), or GraphQL API.
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
```

***

## Dimensions

`dimensions:` is a list. Each item can be either a bare reference to a column, or a named slice that gives the column a different display name.

### Bare reference

The most common form. Point at a column on a semantic model:

```yaml
dimensions:
  - subscriptions.plan_type
  - users.signup_channel
```

The dimension's `name` is **auto-derived** from the field part after the `.` (so `subscriptions.plan_type` becomes `plan_type`, `users.signup_channel` becomes `signup_channel`). The derived name is what consumers use in queries.

{% hint style="warning" %}
**Shorthand name collisions fail validation**

If two shorthand entries derive the **same** name from **different** refs, validation fails. Example:

```yaml
dimensions:
  - users.country         # derives "country"
  - shipping.country      # also derives "country" -> ERROR
```

Switch one (or both) to the [object form](business_metrics.md#named-slice) and give them distinct `name`s:

```yaml
dimensions:
  - name: user_country
    ref: users.country
  - name: shipping_country
    ref: shipping.country
```
{% endhint %}

### Named slice

Use the named form when you want to expose a dimension under a different label than the underlying column, disambiguate two columns that would derive the same shorthand name, or override the semantic-field's documentation/tags/terms/AI hints for this metric:

```yaml
dimensions:
  - name: industry
    ref: users.industry
    description: Customer's reported industry
    tags:
      - customer
      - segmentation
    terms:
      - customer.industry
    ai_context:
      instructions: >
        Use industry when segmenting subscription revenue by customer type.
        Prefer top-N filters for dashboards with many long-tail values.
      synonyms:
        - sector
        - customer vertical
      examples:
        - description: MRR by industry
          format: sql
          query: |
            SELECT
              users.industry,
              MEASURE(subscriptions.avg_mrr_per_account)
            FROM subscriptions
            GROUP BY 1;
```

| Field         | Required | Description                                                                                                                                                                                |
| ------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `name`        | Yes      | The label consumers use in queries. Lowercase identifier (see [Naming rules](../model/types/models.md#naming-rules)). Must be unique across this metric's `dimensions` **and** `segments`. |
| `ref`         | Yes      | The actual semantic reference (`<semantic_name>.<column>`). Both halves must be valid identifiers.                                                                                         |
| `description` | No       | Human-readable explanation. **Overrides** the description on the underlying semantic field for this metric.                                                                                |
| `tags`        | No       | List of categorization labels. **Overrides** the underlying field's tags for this metric.                                                                                                  |
| `terms`       | No       | List of business glossary references. **Overrides** the underlying field's terms for this metric.                                                                                          |
| `ai_context`  | No       | Hints for AI/LLM consumers (`instructions`, `synonyms`, `examples`). **Overrides** the underlying field's `ai_context` for this metric.                                                    |

{% hint style="info" %}
**Override scope**

Overrides apply only to this metric's view of the dimension. Other metrics referencing the same column still see whatever is defined on the semantic model.
{% endhint %}

You can freely mix bare references and named slices in the same `dimensions:` list:

```yaml
dimensions:
  - subscriptions.plan_type
  - users.signup_channel
  - name: industry
    ref: users.industry
```

Dimensions can reference columns from any semantic model, as long as the models are connected through joins.

***

## Segments

Segments apply predefined filters from semantic models to a metric. Reference them using `<semantic_name>.<segment_name>`:

```yaml
segments:
  - subscriptions.active_subscriptions
  - subscriptions.high_value_accounts
```

The segments `active_subscriptions` and `high_value_accounts` must be defined in the `subscriptions` semantic model. When the metric is queried, these filters are applied automatically.

### Segment rules

| Aspect              | Rule                                                                                                                                                                                                       |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Entry type          | **Must** be a qualified-reference string. Dict / object form is rejected by the parser.                                                                                                                    |
| `ref` shape         | `<semantic_name>.<segment_name>`. Both halves must be valid identifiers.                                                                                                                                   |
| Auto-derived `name` | `<semantic_name>_<segment_name>`, lowercased. Must match `^[a-z][a-z0-9_]{0,63}$` and must not collide with any dimension `name` on this metric.                                                           |
| Per-entry metadata  | **Not supported.** Unlike dimensions, segments on a metric cannot carry per-entry `description`, `tags`, `terms`, or `ai_context`. To override segment metadata, edit it on the underlying semantic model. |

Example of how derived names work:

```yaml
segments:
  - usage_sessions.mobile_sessions   # derived name: usage_sessions_mobile_sessions
  - usage_sessions.long_sessions     # derived name: usage_sessions_long_sessions
```

***

## Cross-model metrics

A metric can pull its measure, ts, and dimensions from different semantic models. Vulcan resolves the join paths automatically based on the joins defined in your semantic models.

```yaml
kind: metric
name: cohort_retention
measure: users.active_users
ts: users.signup_date
granularity: month

dimensions:
  - users.signup_channel
  - subscriptions.plan_type

description: User retention by signup cohort and plan type
```

This metric uses the `active_users` measure and `signup_date` time from the `users` model, but groups by `plan_type` from the `subscriptions` model. The `users` semantic model must have a join defined to `subscriptions` for this to work.

{% hint style="warning" %}
**Joins are required for cross-model references**

If a metric references multiple semantic models, those models must be connected through joins. Vulcan validates this and will raise an error if a join path doesn't exist.
{% endhint %}

***

## Time granularity

Define a metric once, query it at any granularity. The `granularity:` value sets the default, but consumers can override it at query time:

* `granularity=day`
* `granularity=week`
* `granularity=month`
* `granularity=quarter`
* `granularity=year`

You do not need separate metric definitions for daily, weekly, and monthly views of the same data.

***

## Examples

### Minimal

The smallest valid metric is the four required fields:

```yaml
# models/metrics/churn_analysis.yml
kind: metric
name: churn_analysis
measure: subscriptions.churn_count
ts: subscriptions.end_date
granularity: month
```

### With dimensions and description

```yaml
# models/metrics/churn_analysis.yml
kind: metric
name: churn_analysis
measure: subscriptions.churn_count
ts: subscriptions.end_date
granularity: month

dimensions:
  - subscriptions.plan_type
  - users.signup_channel

description: Churn patterns by plan and acquisition channel
```

### Cross-model with named slice

```yaml
# models/metrics/cohort_retention.yml
kind: metric
name: cohort_retention
measure: users.active_users
ts: users.signup_date
granularity: month

dimensions:
  - users.signup_channel
  - subscriptions.plan_type

description: User retention by signup cohort and plan type
```

### Full example with segments, tags, terms

```yaml
# models/metrics/arr_growth.yml
kind: metric
name: arr_growth
measure: subscriptions.total_arr
ts: subscriptions.start_date
granularity: month

dimensions:
  - subscriptions.plan_type
  - name: industry
    ref: users.industry

segments:
  - subscriptions.active_subscriptions
  - subscriptions.high_value_accounts

description: Annual Recurring Revenue growth by plan and industry
tags:
  - revenue
  - arr
  - metric
terms:
  - glossary.annual_recurring_revenue
  - glossary.revenue_metric
```

***

## Forbidden legacy keys

Two keys from earlier versions of the metric spec are **explicitly rejected** and will cause validation to fail:

| Legacy key | Use instead  | Notes                                                              |
| ---------- | ------------ | ------------------------------------------------------------------ |
| `time`     | `ts`         | The time-column field was renamed.                                 |
| `slices`   | `dimensions` | The grouping field was renamed and switched from a dict to a list. |

If you are migrating an older project, do a global replace before running `vulcan plan`.

***

## Reserved names

The following names cannot be used as a dimension `name` (object form) or as the auto-derived `name` of a segment on a metric:

* `measure`
* `time`
* `ts`

They are reserved as adjunct keys on the metric envelope. Pick a different name (for example, `plan_type` instead of `time`). For segments, this means you cannot reference a segment whose `<semantic_name>_<segment_name>` derivation collides with one of the reserved names.

***

## Validation

Vulcan validates metric definitions automatically when you create a plan. It checks that:

* `measure` references a valid measure on a semantic model
* `ts` references a valid time/date column
* `granularity` is a recognized granularity value (see [granularity table](business_metrics.md#granularity))
* Every qualified reference (`measure`, `ts`, and each dimension/segment `ref`) is a valid `<semantic_name>.<field>` where both halves are valid identifiers
* **All qualified refs used by the metric are unique.** You cannot use the same `<semantic_name>.<field>` as both `measure` and `ts`, or as two dimensions, and so on.
* **All names are unique across `dimensions` and `segments`** (dimension `name`s plus auto-derived segment `name`s, considered as one combined set)
* Dimension references point to real columns
* Named slices include both `name` and `ref`
* Segment entries are qualified-reference strings (not objects) and their auto-derived `<semantic_name>_<segment_name>` matches the lowercase identifier pattern
* Cross-model references have valid join paths between the involved models
* Forbidden legacy keys (`time`, `slices`) are not present
* Reserved names (`measure`, `time`, `ts`) are not used as a dimension or auto-derived segment `name`
* All identifier names match the [naming rules](../model/types/models.md#naming-rules)
* No unknown keys appear inside `ai_context` (Pydantic `extra="forbid"`)

***

## Next steps

* Learn about [Semantic Models](../model/types/models.md): the source of measures, segments, and joins that metrics build on.
* See the [Semantics Overview](./) for the complete picture
* Explore metric definitions in your project's `models/metrics/` directory
