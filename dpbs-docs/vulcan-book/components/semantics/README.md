# Semantics

The semantic layer sits between your raw data and the people who consume it. It maps technical database objects (tables, columns, joins) to business concepts like "revenue," "active users," or "churn rate," so everyone in your organization queries data with the same vocabulary without needing to understand the underlying schema.

***

## What is the Semantic Layer?

The semantic layer bridges the gap between "here's a table with columns" and "here's what this means for the business." It provides a consistent, business-friendly interface to your data that enables self-service analytics while keeping a single source of truth for your business logic.

Without a semantic layer, every time someone wants to analyze revenue, they have to remember which table has it, what the column is called, how to join it with other tables, and how to calculate it correctly. With a semantic layer, they ask for "revenue" and it works.

### Why it matters

**For developers.** Write the calculation for `revenue` once, then reuse it in dashboards, APIs, and reports. Definitions live in code, so PR review covers business logic and `git blame` works on metric changes. No more "which revenue query is canonical?".

**For business users.** Query data without writing SQL. The same `revenue` definition runs in Tableau, Power BI, Python notebooks, and the REST API, so two dashboards never disagree because they wrote slightly different `SUM(...)` expressions.

**For organizations.** One place where `revenue` is defined, instead of scattered across twenty dashboards. Business users answer their own questions instead of queuing on the data team, and the data team can audit and change a definition without hunting down every consumer.

***

## Core Components

The semantic layer has two pieces that build on each other: semantic models first, then metrics on top.

### Semantic Models

Semantic models are wrappers around your Vulcan models. They take your technical tables and expose them in a business-friendly way. For detailed information, check out the [Semantic Models](../model/types/models.md) documentation.

A semantic model does four things:

* **Wraps a Vulcan model** from `models/` and picks which columns become dimensions you can filter and group by.
* **Declares measures**: typed aggregations like `count`, `sum`, or `avg`, optionally with their own `filters`.
* **Names reusable segments** (e.g. "high-value customers", "active users") so the same filter doesn't get rewritten in every query.
* **Defines joins** to other semantic models, so a query can pull dimensions from one model and measures from another.

Here's a simple example:

```yaml
kind: semantic
name: customers
depends_on: analytics.customers

ai_context:
  instructions: >
    Customer analytics semantic model for customer counts, tiers, and signup trends.
    Use CUSTOMER_TIER for segmentation and SIGNUP_DATE for acquisition analysis.
  synonyms:
    - customers
    - accounts
    - users
  examples:
    - description: total customers by tier
      format: sql
      query: |
        SELECT
          customers.CUSTOMER_TIER,
          MEASURE(customers.total_customers)
        FROM customers
        GROUP BY 1;

dimensions:
  - CUSTOMER_ID
  - CUSTOMER_TIER
  - SIGNUP_DATE

measures:
  - name: total_customers
    type: count
    expression: "{customers.CUSTOMER_ID}"
    description: Total registered customers
```

This takes your `analytics.customers` model and exposes a `total_customers` measure that anyone can use. Business users can query "total customers" without knowing which table it comes from or how to write the SQL.

A more complete example with measures, segments, and joins:

```yaml
kind: semantic
name: customers
depends_on: analytics.customers

dimensions:
  - CUSTOMER_ID
  - CUSTOMER_TIER
  - SIGNUP_DATE
  - STATUS
  - PLAN_TYPE

measures:
  - name: total_customers
    type: count
    expression: "{customers.CUSTOMER_ID}"
    description: Total registered customers
    tags:
      - customer
      - count

  - name: active_customers
    type: count
    filters:
      - "{customers.STATUS} = 'active'"
    description: Currently active customers

segments:
  - name: high_value_accounts
    expression: "{customers.PLAN_TYPE} IN ('pro', 'enterprise')"
    description: Paid plan customers
    tags:
      - customer
      - segment

joins:
  - name: orders
    type: one_to_many
    expression: "{customers.CUSTOMER_ID} = {orders.CUSTOMER_ID}"
```

### Business Metrics

Business metrics combine measures with dimensions and time to create complete analytical definitions. They're like pre-built queries that are ready to use. Learn more in the [Business Metrics](business_metrics.md) guide.

Metrics add three things on top of measures:

* A required time column (`ts`) and default granularity, so every metric is a time series by construction.
* A re-queryable granularity (`day`, `week`, `month`, ...) without rewriting the underlying measure.
* A predeclared set of dimensions and segments the metric is allowed to slice by, so clients don't have to know the join graph.

Here's what a metric looks like:

```yaml
# models/metrics/monthly_revenue.yml
kind: metric
name: monthly_revenue
measure: orders.total_revenue
ts: orders.ORDER_DATE
granularity: month

dimensions:
  - customers.CUSTOMER_TIER
  - orders.REGION

description: Monthly revenue by customer tier and region
tags:
  - revenue
  - financial
```

This creates a `monthly_revenue` metric that:

* Uses the `total_revenue` measure from the orders semantic model
* Groups by `ORDER_DATE` (time column) at monthly granularity by default
* Can be grouped by `CUSTOMER_TIER` and `REGION` (business dimensions)
* Includes descriptive metadata via `description` and `tags`

Anyone can query "monthly revenue by customer tier" without writing SQL. They reference the metric name, and Vulcan handles the complexity.

***

## How It Works

The workflow:

1. **Define semantic models.** Create YAML files in `models/semantics/` that reference your Vulcan models.
2. **Add measures and dimensions.** Declare what can be aggregated and what can be filtered or grouped by.
3. **Create joins.** Connect semantic models so a single query can reach across tables.
4. **Define metrics.** Combine a measure with a time column and a dimension list under `models/metrics/`.
5. **Validate.** `vulcan plan` parses every definition and fails the plan if a measure references a column that doesn't exist, a join expression is invalid, or a metric points at a missing measure.
6. **Query.** Hit the REST, GraphQL, or SQL-wire API, or export to a BI tool.

Validation is the part that pays for itself. Catching a typo in a measure expression at plan time is much cheaper than a Tableau dashboard quietly returning zeros.

***

## File Organization

Co-locate semantic models with the SQL models they wrap, and give each metric its own file:

```
project/
├── models/                  # Vulcan data models (.sql files)
│   ├── customers.sql
│   ├── orders.sql
│   ├── events.sql
│   │
│   ├── semantics/           # Semantic models (kind: semantic)
│   │   ├── customers.yml
│   │   └── orders.yml
│   │
│   └── metrics/             # Per-metric files
│       ├── arr_growth.yml
│       ├── churn_analysis.yml
│       └── cohort_retention.yml
│
└── config.yaml
```

**File naming:** The filename doesn't matter. Vulcan automatically merges all YAML files in `models/semantics/` and `models/metrics/`. Organize by domain (`customers.yml`, `orders.yml`) or by function (`revenue_metrics.yml`), whatever helps you find things.

{% hint style="info" %}
**Where to put `semantics/`**

New projects should place semantic models in `models/semantics/`. If you still have a top-level `semantics/` directory next to `models/`, move those files under `models/semantics/` as part of your OSI GA migration.
{% endhint %}

{% hint style="warning" %}
**Auth-backed policies need an auth extension**

If your semantic models use policies or masking based on Heimdall auth, make sure `config.yaml` includes the root-level auth extension hook:

```yaml
after_authorize: "plugins.auth_ext:resolve_user_groups"
```

The hook resolves Heimdall role tags into policy groups. See the [Plugins Auth Extension Guide](plugins_auth_extension.md) for the full setup.
{% endhint %}

***

## Integration with Models

The semantic layer doesn't replace your models. You pick which columns to expose as dimensions, then layer measures, segments, joins, and metrics on top. The underlying SQL models stay exactly as they are.

When you're designing Vulcan models, keep the semantic layer in mind:

```sql
-- Clean column names, business-friendly
MODEL (name analytics.customers);
SELECT
  customer_id,
  customer_tier,      -- Good dimension name (can filter/group by this)
  signup_date,        -- Good time dimension (can analyze trends)
  total_spent         -- Good for measures and segments
FROM raw.customers;
```

Then in your semantic definition, expose those columns and build on them:

```yaml
kind: semantic
name: customers
depends_on: analytics.customers

dimensions:
  - CUSTOMER_ID
  - CUSTOMER_TIER
  - SIGNUP_DATE
  - TOTAL_SPENT

measures:
  - name: high_spenders
    type: count
    filters:
      - "{customers.TOTAL_SPENT} > 10000"
    description: Customers who have spent over $10,000

segments:
  - name: enterprise_tier
    expression: "{customers.CUSTOMER_TIER} = 'enterprise'"
    description: Enterprise-tier customers
```

Your models stay exactly as they are; the semantic layer just makes them more accessible.

***

## Next Steps

* [Semantic Models](../model/types/models.md): how to declare dimensions, measures, segments, and joins.
* [Business Metrics](business_metrics.md): how to wrap a measure with a time column and dimensions.
* [Plugins Auth Extension Guide](plugins_auth_extension.md): how to resolve Heimdall role tags for policies and masking.
* [Transpiling Semantic Queries](../../guides/transpiling_semantics.md): what SQL Vulcan generates for a semantic query.
* The `models/semantics/` and `models/metrics/` folders in your project: working examples to copy from.
