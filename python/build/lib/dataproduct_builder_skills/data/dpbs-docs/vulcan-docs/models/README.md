---
description: >-
  How Vulcan models fit together: physical data models, the semantic layer on
  top of them, and business metrics on top of that.
---

# Models

Vulcan projects build up in 3 layers. Each layer wraps the one below it and adds a different kind of consumer-facing meaning.

## What this section covers

Use this section when you need to:

* define the SQL/Python transformations that produce your tables and views
* expose those tables as business-friendly dimensions and measures
* define reusable, time-series metrics on top of those measures

## Choose a starting point

<table data-view="cards"><thead><tr><th></th><th data-card-target data-type="content-ref"></th></tr></thead><tbody><tr><td><strong>Data Models</strong><br>The MODEL block, the SELECT query, conventions, and the day-to-day workflow for adding, editing, and deleting models.</td><td><a href="data-models/">data-models</a></td></tr><tr><td><strong>Semantic models</strong><br>Wrap a Vulcan model with business-friendly dimensions, measures, segments, and joins.</td><td><a href="semantic-models/">semantic-models</a></td></tr><tr><td><strong>Business metrics</strong><br>Time-series metrics built on top of semantic model measures, for dashboards, reports, and APIs.</td><td><a href="business-metrics.md">business-metrics.md</a></td></tr></tbody></table>

## How the layers relate

1. **Data Models** transform raw data into tables and views with SQL or Python. Every model has a `MODEL` block (DDL) and a query (DML). See [Data Models](data-models/).
2. **Semantic models** wrap a data model and expose it in business-friendly terms: dimensions to filter and group by, measures to aggregate, segments as reusable filters, and joins to other semantic models. See [Semantic models](semantic-models/).
3. **Business metrics** sit on top of semantic models. They combine a measure, a time dimension, and optional grouping dimensions into a single queryable metric for dashboards, reports, and APIs. See [Business metrics](business-metrics.md).

The underlying data models don't change when you add semantic models or metrics on top. Each layer is additive.

## Why layer semantic models and metrics on top

Without a semantic layer, every consumer of your data has to remember which table holds a number, what the column is called, how to join it, and how to calculate it correctly. With semantic models and metrics, they ask for "revenue" and it works the same way everywhere.

**For developers.** Write the calculation once, then reuse it in dashboards, APIs, and reports. Definitions live in code, so PR review covers business logic and `git blame` works on metric changes.

**For business users.** Query data without writing SQL. The same definition runs in BI tools, notebooks, and the REST/GraphQL/SQL-wire APIs, so two dashboards never disagree because they wrote slightly different aggregations.

**For organizations.** One place where a metric is defined, instead of scattered across dashboards. The data team can audit and change a definition without hunting down every consumer.

## How it works end to end

1. **Define data models.** Write `.sql` or `.py` files in `models/` with clean, business-friendly column names.
2. **Define semantic models.** Create YAML files in `models/semantics/` that wrap a data model and declare dimensions, measures, segments, and joins.
3. **Define metrics.** Combine a measure with a time column and a dimension list under `models/metrics/`.
4. **Validate.** `vulcan plan` parses every definition and fails the plan if a measure references a missing column, a join expression is invalid, or a metric points at a missing measure.
5. **Query.** Hit the REST, GraphQL, or SQL-wire API, or export to a BI tool.

## File organization

Co-locate semantic models with the data models they wrap, and give each metric its own file:

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

The filename doesn't matter. Vulcan automatically merges all YAML files in `models/semantics/` and `models/metrics/`. Organize by domain (`customers.yml`, `orders.yml`) or by function (`revenue_metrics.yml`), whatever helps you find things.

{% hint style="warning" %}
**Policies attach to physical models**

If your data product uses row filtering or column masking, author policy files under `policies/access/` and attach each policy to a physical model. Semantic and metric models inherit those rules. See [Policies](../policies.md).
{% endhint %}
