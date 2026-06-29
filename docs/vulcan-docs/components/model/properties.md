# Properties

The `MODEL` DDL statement has properties that control how your model behaves. Configure scheduling, storage, validation, and more.

This page is a complete reference for all available properties: what each one does, when to use it, and examples.

***

## Quick reference

| Property              | Description                                                                                                                   |       Type       | Required |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------- | :--------------: | :------: |
| `name`                | Fully qualified model name: `schema.model` or `catalog.schema.model` (catalog required when targeting a non-default database) |       `str`      |     Y    |
| `project`             | Project name for multi-repo deployments                                                                                       |       `str`      |     N    |
| `kind`                | Model kind (VIEW, FULL, INCREMENTAL, etc.)                                                                                    |  `str` \| `dict` |     N    |
| `cron`                | Schedule expression for model refresh                                                                                         |       `str`      |     N    |
| `cron_tz`             | Timezone for the cron schedule                                                                                                |       `str`      |     N    |
| `interval_unit`       | Temporal granularity of data intervals                                                                                        |       `str`      |     N    |
| `start`               | Earliest date/time to process                                                                                                 |  `str` \| `int`  |     N    |
| `end`                 | Latest date/time to process                                                                                                   |  `str` \| `int`  |     N    |
| `grains`              | Column(s) defining row uniqueness                                                                                             | `str` \| `tuple` |     N    |
| `grains`              | Multiple unique key definitions                                                                                               |      `tuple`     |     N    |
| `owner`               | Model owner for governance                                                                                                    |       `str`      |     N    |
| `description`         | Model description (registered as table comment)                                                                               |       `str`      |     N    |
| `tags`                | Labels for organizing and categorizing models                                                                                 |   `tuple[str]`   |     N    |
| `terms`               | Business glossary terms for semantic linking                                                                                  |   `tuple[str]`   |     N    |
| `column_descriptions` | Column-level comments                                                                                                         |      `dict`      |     N    |
| `column_tags`         | Column-level tags for categorization                                                                                          |      `dict`      |     N    |
| `column_terms`        | Column-level business glossary terms                                                                                          |      `dict`      |     N    |
| `columns`             | Explicit column names and types                                                                                               |      `array`     |     N    |
| `dialect`             | SQL dialect of the model                                                                                                      |       `str`      |     N    |
| `assertions`          | Named audits to run after model evaluation (attaching them to this model)                                                     |      `array`     |     N    |
| `depends_on`          | Explicit model dependencies                                                                                                   |   `array[str]`   |     N    |
| `references`          | Non-unique join relationship columns                                                                                          |      `array`     |     N    |
| `partitioned_by`      | Partition key column(s)                                                                                                       | `str` \| `array` |     N    |
| `clustered_by`        | Clustering column(s)                                                                                                          |      `array`     |     N    |
| `table_format`        | Table format (iceberg, hive, delta)                                                                                           |       `str`      |     N    |
| `storage_format`      | Storage format (parquet, orc)                                                                                                 |       `str`      |     N    |
| `physical_properties` | Engine-specific table/view properties                                                                                         |      `dict`      |     N    |
| `virtual_properties`  | Engine-specific view layer properties                                                                                         |      `dict`      |     N    |
| `session_properties`  | Engine session properties                                                                                                     |      `dict`      |     N    |
| `stamp`               | Arbitrary version string                                                                                                      |       `str`      |     N    |

\| `enabled` | Whether model is enabled | `bool` | N |

\| `allow_partials` | Allow partial data intervals | `bool` | N | | `gateway` | Specific gateway for execution | `str` | N |

\| `optimize_query` | Enable query optimization | `bool` | N | | `formatting` | Enable model formatting | `bool` | N |

\| `ignored_rules` | Linter rules to ignore | `str` | `array` | N |

**Note**: required unless [name inference](properties.md#model-naming) is enabled.

***

## General properties

### name

Your model's name is how it's identified in the data warehouse. It needs at least a schema (`schema.model`), and you can include a catalog (`catalog.schema.model`) when targeting a specific database.

**Format**: `schema.model` or `catalog.schema.model`.

This becomes the production table/view name that other models and users reference.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.daily_sales,        -- uses the gateway's default catalog
);

-- Target a specific catalog
MODEL (
  name analytics_db.sales.daily_sales -- writes to analytics_db, not the default
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",  # uses the gateway's default catalog
)
def execute(context, **kwargs):
    ...

# Target a specific catalog
@model(
    "analytics_db.sales.daily_sales",  # writes to analytics_db, not the default
)
```
{% endtab %}
{% endtabs %}

{% hint style="success" %}
**Best practice**

Use the fully qualified `catalog.schema.model` format. Names are unambiguous, gateway-default changes can't silently retarget a model, and multi-catalog projects work without extra config.
{% endhint %}

{% hint style="info" %}
**When do you need the catalog?**

If you omit the catalog, Vulcan writes to the **default catalog** configured in your [gateway connection](../../configurations/README.md) (for example, the `catalog` property in your Databricks or Trino config).

You **must** specify the catalog when:

* Your model targets a **different database** than the gateway default.
* You're working in a **multi-catalog setup** (for example, separate catalogs for raw, staging, and analytics data).

If all your models live in one catalog, `schema.model` is all you need.
{% endhint %}

{% hint style="info" %}
**Environment prefixing**

In non-production environments, Vulcan prefixes your model names. So `sales.daily_sales` becomes `sales__dev.daily_sales` in the dev environment. This keeps your dev and prod data separate automatically.
{% endhint %}

### project

For multiple Vulcan projects in the same repository (multi-repo setup), use `project` to specify which project this model belongs to. This helps Vulcan organize and isolate models from different projects.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.daily_sales,
  project 'analytics_project',
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",
    project="analytics_project",
)
```
{% endtab %}
{% endtabs %}

### kind

The `kind` property determines how your model is computed and stored. Rebuild everything each run, update incrementally, or create a view: decide here.

For details on each kind and when to use them, see the [Model Kinds](model_kinds.md) documentation.

{% tabs %}
{% tab title="SQL" %}
```sql
-- VIEW (default for SQL)
MODEL (
  name sales.daily_sales,
  kind VIEW,
);

-- FULL
MODEL (
  name sales.daily_sales,
  kind FULL,
);

-- Incremental with properties
MODEL (
  name sales.events,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column event_ts,
  ),
);

-- SEED
MODEL (
  name raw.holidays,
  kind SEED (
    path 'seeds/holidays.csv',
  ),
);
```
{% endtab %}

{% tab title="Python" %}
```python
from vulcan import ModelKindName

# FULL (default for Python)
@model(
    "sales.daily_sales",
    kind=dict(name=ModelKindName.FULL),
)

# Incremental
@model(
    "sales.events",
    kind=dict(
        name=ModelKindName.INCREMENTAL_BY_TIME_RANGE,
        time_column="event_ts",
    ),
)

# SCD Type 2
@model(
    "dim.customers",
    kind=dict(
        name=ModelKindName.SCD_TYPE_2_BY_TIME,
        unique_key=["customer_id"],
    ),
)
```
{% endtab %}
{% endtabs %}

### cron

Controls when your model runs. Use standard cron expressions or Vulcan's shortcuts for common schedules.

**Why this matters**: without a schedule, your model only runs when you manually trigger it. Set a cron, and Vulcan processes new data on schedule.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.daily_sales,
  cron '@daily',          -- Daily at midnight UTC
);

MODEL (
  name sales.hourly_metrics,
  cron '@hourly',         -- Every hour
);

MODEL (
  name sales.custom_schedule,
  cron '0 6 * * *',       -- Custom: every day at 6 AM UTC
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",
    cron="@daily",
)

@model(
    "sales.hourly_metrics",
    cron="@hourly",
)

@model(
    "sales.custom_schedule",
    cron="0 6 * * *",  # Every day at 6 AM UTC
)
```
{% endtab %}
{% endtabs %}

**Cron shortcuts**: Vulcan provides shortcuts:

* **`@hourly`**: every hour.
* **`@daily`**: every day at midnight UTC.
* **`@weekly`**: once per week.
* **`@monthly`**: once per month.

These are easier than writing `0 * * * *`.

### cron\_tz

Sets the timezone for your cron schedule. This only affects **when** the model runs, not how time intervals are calculated (those are always UTC).

**Example**: with `cron '@daily'` and `cron_tz 'America/Los_Angeles'`, your model runs at midnight Pacific time, but the time intervals it processes are still in UTC.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.daily_sales,
  cron '@daily',
  cron_tz 'America/Los_Angeles',  -- Runs at midnight Pacific time
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",
    cron="@daily",
    cron_tz="America/Los_Angeles",
)
```
{% endtab %}
{% endtabs %}

### interval\_unit

Controls the granularity of time intervals for incremental models. Vulcan infers this from your `cron` expression by default; override it if needed.

**Supported values**: `year`, `month`, `day`, `hour`, `half_hour`, `quarter_hour`, `five_minute`.

**When to override**: when your cron runs daily but you want to process hourly intervals, set `interval_unit 'hour'`. Use this for finer-grained control over incremental processing.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.hourly_metrics,
  cron '30 7 * * *',      -- Run daily at 7:30 AM
  interval_unit 'hour',   -- Process hourly intervals (not daily)
  );
```
{% endtab %}

{% tab title="Python" %}
```python
from vulcan import IntervalUnit

@model(
    "sales.hourly_metrics",
    cron="30 7 * * *",
    interval_unit=IntervalUnit.HOUR,
)
```
{% endtab %}
{% endtabs %}

### start

Sets the earliest date/time your model should process. Use it to limit backfills or define when your model's data begins.

Formats:

* **Absolute dates**: `'2024-01-01'`.
* **Relative expressions**: `'1 year ago'`.
* **Epoch milliseconds**: `1704067200000`.

{% tabs %}
{% tab title="SQL" %}
```sql
-- Absolute date
MODEL (
  name sales.daily_sales,
  start '2024-01-01',
);

-- Relative expression
MODEL (
  name sales.recent_sales,
  start '1 year ago',
);

-- Epoch milliseconds
MODEL (
  name sales.events,
  start 1704067200000,
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",
    start="2024-01-01",
)

@model(
    "sales.recent_sales",
    start="1 year ago",
)
```
{% endtab %}
{% endtabs %}

### end

Sets the latest date/time your model should process. Uses the same format as `start`. Use it for historical models or to limit processing to a specific time range.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.historical_sales,
  start '2020-01-01',
  end '2023-12-31',
  );
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.historical_sales",
    start="2020-01-01",
    end="2023-12-31",
)
```
{% endtab %}
{% endtabs %}

### grain / grains

In Vulcan, this acts as the primary key. It identifies a single row in your table and defines the column(s) that make each row unique.

**Why this matters**: tools like `table_diff` use grains to compare tables. It also helps Vulcan understand your data structure for better optimization and validation.

Specify a single grain or multiple grains using tuple syntax with parentheses.

{% tabs %}
{% tab title="SQL" %}
```sql
-- Single column grain
MODEL (
  name sales.daily_sales,
  grains (order_date),
);

-- Composite grain
MODEL (
  name sales.customer_daily,
  grains (customer_id, order_date),
);

-- Multiple grains
MODEL (
  name sales.orders,
  grains (
    order_id,
    (customer_id, order_date)
  ),
);
```
{% endtab %}

{% tab title="Python" %}
```python
# Single grain
@model(
    "sales.daily_sales",
    grains=["order_date"],
)

# Composite grain
@model(
    "sales.customer_daily",
    grains=[("customer_id", "order_date")],
)

# Multiple grains
@model(
    "sales.orders",
    grains=[
        "order_id",
        ("customer_id", "order_date"),
    ],
)
```
{% endtab %}
{% endtabs %}

### owner

Sets the owner of the model, usually a team name or individual. Used for governance, notifications, and knowing who to contact when something breaks.

**Example**: `owner 'analytics_team'` or `owner 'data_engineers'`.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.daily_sales,
  owner 'analytics_team',
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",
    owner="analytics_team",
)
```
{% endtab %}
{% endtabs %}

### description

A human-readable description of what your model does. Vulcan registers this as a table comment in your SQL engine (where supported), so it shows up in BI tools and data catalogs.

**Tip**: write descriptions that explain the business purpose, not just the technical details.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.daily_sales,
  description 'Aggregated daily sales metrics including total orders and revenue',
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",
    description="Aggregated daily sales metrics including total orders and revenue",
)
```
{% endtab %}
{% endtabs %}

### column\_descriptions

Document your columns. Add descriptions for each column; they're registered as column comments in your database.

**Why document columns?** When someone queries your table in a BI tool, they see what each column means. It's inline documentation that travels with your data.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.daily_sales,
  column_descriptions (
    order_date = 'The date of sales transactions',
    total_orders = 'Count of orders placed on this date',
    total_revenue = 'Sum of all order amounts',
  )
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",
    columns={
        "order_date": "timestamp",
        "total_orders": "int",
        "total_revenue": "decimal(18,2)",
    },
    column_descriptions={
        "order_date": "The date of sales transactions",
        "total_orders": "Count of orders placed on this date",
        "total_revenue": "Sum of all order amounts",
    },
)
```
{% endtab %}
{% endtabs %}

{% hint style="warning" %}
**Priority**

If `column_descriptions` is present, [inline column comments](./#column-descriptions) are not registered.
{% endhint %}

### column\_tags

Assign tags to individual columns for categorization, governance, and discovery. Column tags classify columns by role, sensitivity, or purpose.

**Common column tag categories:**

* **Role tags**: `primary_key`, `identifier`, `grain`, `dimension`, `measure`.
* **Sensitivity tags**: `pii`, `confidential`, `contact`.
* **Domain tags**: `financial`, `metric`, `score`, `label`.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name gold_v1.rfm_customer_segmentation,
  column_tags (
    customer_id = (
      'primary_key',
      'identifier',
      'grain'
    ),
    customer_name = ('dimension', 'label', 'pii'),
    email = ('dimension', 'pii', 'contact'),
    region_name = ('dimension', 'label'),
    monetary_value = (
      'measure',
      'financial',
      'rfm_component'
    ),
    rfm_score = (
      'measure',
      'score',
      'composite'
    ),
    rfm_segment = (
      'dimension',
      'classification',
      'label'
    )
  )
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "gold_v1.rfm_customer_segmentation",
    column_tags={
        "customer_id": ["primary_key", "identifier", "grain"],
        "customer_name": ["dimension", "label", "pii"],
        "email": ["dimension", "pii", "contact"],
        "region_name": ["dimension", "label"],
        "monetary_value": ["measure", "financial", "rfm_component"],
        "rfm_score": ["measure", "score", "composite"],
        "rfm_segment": ["dimension", "classification", "label"],
    },
)
```
{% endtab %}
{% endtabs %}

{% hint style="success" %}
**PII tracking**

Use the `pii` tag on columns containing personally identifiable information (PII). This helps with data governance, compliance assertions, and access control policies.
{% endhint %}

### column\_terms

Link individual columns to business glossary terms. Column terms connect technical column names to business vocabulary for better discovery and semantic understanding.

**Format**: use dot notation for hierarchical terms like `domain.concept` (for example, `customer.customer_id`, `analytics.rfm_score`).

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name gold_v1.rfm_customer_segmentation,
  column_terms (
    customer_id = (
      'customer.customer_id',
      'identity.customer_id'
    ),
    rfm_score = (
      'analytics.rfm_score',
      'segmentation.rfm_composite'
    ),
    rfm_segment = (
      'customer.segment',
      'analytics.customer_classification'
    ),
    monetary_value = (
      'customer.ltv',
      'finance.customer_lifetime_value'
    )
  )
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "gold_v1.rfm_customer_segmentation",
    column_terms={
        "customer_id": ["customer.customer_id", "identity.customer_id"],
        "rfm_score": ["analytics.rfm_score", "segmentation.rfm_composite"],
        "rfm_segment": ["customer.segment", "analytics.customer_classification"],
        "monetary_value": ["customer.ltv", "finance.customer_lifetime_value"],
    },
)
```
{% endtab %}
{% endtabs %}

### columns

Explicitly defines your model's column names and data types. With this, Vulcan doesn't infer types from your query; it uses exactly what you specify.

**When to use:**

* Python models (required; Vulcan can't infer types from Python code).
* Seed models (define the CSV schema).
* When you want strict type control.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.national_holidays,
  kind SEED (path 'holidays.csv'),
  columns (
    holiday_name VARCHAR,
    holiday_date DATE
  )
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",
    columns={
        "order_date": "timestamp",
        "total_orders": "int",
        "total_revenue": "decimal(18,2)",
        "last_order_id": "string",
    },
)
def execute(context, **kwargs) -> pd.DataFrame:
    ...
```
{% endtab %}
{% endtabs %}

{% hint style="info" %}
**Python models**
{% endhint %}

Required for [Python models](types/python_models.md). Vulcan can't infer column types from Python code; define your schema explicitly.

### dialect

Specifies the SQL dialect your model uses. Defaults to whatever you set in `model_defaults`.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.daily_sales,
  dialect 'snowflake',
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",
    dialect="snowflake",
)
```
{% endtab %}
{% endtabs %}

### tags

Labels for organizing, filtering, and categorizing models. Tags group related models for filtering in CLI commands and organizing your project.

**Common tag categories:**

* **Layer tags**: `gold`, `silver`, `bronze` for data lake layers.
* **Domain tags**: `analytics`, `customer`, `sales`, `finance`.
* **Purpose tags**: `reporting`, `segmentation`, `aggregation`.
* **Sensitivity tags**: `pii`, `confidential`, `public`.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name gold_v1.rfm_customer_segmentation,
  tags (
    'gold',
    'analytics',
    'customer',
    'rfm',
    'segmentation'
  )
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "gold_v1.rfm_customer_segmentation",
    tags=["gold", "analytics", "customer", "rfm", "segmentation"],
)
```
{% endtab %}
{% endtabs %}

### terms

Business glossary terms link your model to semantic definitions. Terms bridge technical model names and business vocabulary, making models easier to discover and understand.

**Format**: use dot notation for hierarchical terms like `domain.concept` (for example, `customer.rfm_analysis`, `analytics.customer_segmentation`).

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name gold_v1.rfm_customer_segmentation,
  terms (
    'customer.rfm_analysis',
    'analytics.customer_segmentation'
  )
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "gold_v1.rfm_customer_segmentation",
    terms=["customer.rfm_analysis", "analytics.customer_segmentation"],
)
```
{% endtab %}
{% endtabs %}

### assertions

Attach [assertions](.././assertions.md) directly to your model. These validations run after each model evaluation and block models if they fail.

**Why use assertions?** They catch bad data before it flows downstream. If revenue can't be negative, assert it. If customer IDs must be unique, assert it. Fail fast, fix fast.

Assertions are "this data must be true" validations that run automatically.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.daily_sales,
  assertions (
    not_null(columns := (order_date, customer_id)),
    unique_values(columns := (order_id)),
    accepted_range(column := price, min_v := 0, max_v := 1000),
    forall(criteria := (price > 0, quantity >= 1))
  )
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",
    assertions=[
        ("not_null", {"columns": ["order_date", "customer_id"]}),
        ("unique_values", {"columns": ["order_id"]}),
        ("accepted_range", {"column": "price", "min_v": 0, "max_v": 1000}),
    ],
)
```
{% endtab %}
{% endtabs %}

### depends\_on

Explicitly declare model dependencies. Vulcan infers dependencies from SQL queries, but sometimes you need to add extra ones.

**When to use:**

* Python models (required; Vulcan can't parse Python to find dependencies).
* Hidden dependencies (like a macro that references another model).
* External dependencies that aren't in your SQL.

**Note**: dependencies you declare here are added to the ones Vulcan infers; they don't replace them.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.summary,
  depends_on ['sales.daily_sales', 'sales.products'],
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.summary",
    depends_on=["sales.daily_sales", "sales.products"],
)
```
{% endtab %}
{% endtabs %}

{% hint style="info" %}
**Python models**

Python models **require** `depends_on`. Vulcan can't infer dependencies from Python code; declare them explicitly.
{% endhint %}

### references

Declare non-unique join relationships to other models. These help Vulcan understand how models relate to each other for better lineage and optimization.

**Example**: if your `orders` table has a `customer_id` that joins to `customers.customer_id`, add `customer_id` to references. This tells Vulcan about the relationship even though `customer_id` isn't unique in the orders table.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.orders,
  references (
    customer_id,
    guest_id AS account_id,  -- Alias for joining to account_id grain
  ),
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.orders",
    references=[
        "customer_id",
        ("guest_id", "account_id"),  # Alias
    ],
)
```
{% endtab %}
{% endtabs %}

***

## Storage properties

These properties control how your data is physically stored in the database. They're engine-specific; check your engine's documentation for what's supported.

### partitioned\_by

Defines the partition key for your table. Partitioning splits your table into chunks based on column values, which makes queries faster (the engine can skip irrelevant partitions).

**Supported engines**: Spark, BigQuery, Databricks, and others that support table partitioning.

**Why partition?** If you query the last 7 days and your table is partitioned by date, the engine scans 7 partitions instead of the entire table.

{% tabs %}
{% tab title="SQL" %}
```sql
-- Single column partition
MODEL (
  name sales.events,
  partitioned_by event_date,
);

-- Partition with transformation (BigQuery)
MODEL (
  name sales.events,
  partitioned_by TIMESTAMP_TRUNC(event_ts, DAY),
);

-- Multi-column partition
MODEL (
  name sales.events,
  partitioned_by (year, month, day),
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.events",
    partitioned_by=["event_date"],
)

# Multi-column
@model(
    "sales.events",
    partitioned_by=["year", "month", "day"],
)
```
{% endtab %}
{% endtabs %}

### clustered\_by

Sets clustering columns for engines that support it (like BigQuery). Clustering organizes data within partitions based on column values, making range queries and filters faster.

**How it works**: data is physically stored sorted by the clustering columns. When you filter on those columns, the engine skips reading irrelevant data blocks.

**Example**: cluster by `customer_id`, and queries filtering by customer run faster because related data is stored together.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.events,
  partitioned_by event_date,
  clustered_by (customer_id, product_id),
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.events",
    partitioned_by=["event_date"],
    clustered_by=["customer_id", "product_id"],
)
```
{% endtab %}
{% endtabs %}

### table\_format

Specifies the table format for engines that support multiple formats. Different formats have different features and performance characteristics.

**Supported formats**: `iceberg`, `hive`, `delta`.

**When to use**: choose based on your needs:

* **Iceberg**: time travel and schema evolution.
* **Delta**: ACID transactions and time travel.
* **Hive**: traditional format, widely supported.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.events,
  table_format 'iceberg',
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.events",
    table_format="iceberg",
)
```
{% endtab %}
{% endtabs %}

### storage\_format

Sets the physical file format for your table's data files. This affects compression, query performance, and storage costs.

**Common formats**: `parquet`, `orc`.

**Parquet** is usually the best choice: columnar (good for analytics), good compression, and widely supported. **ORC** is another option, especially with Hive.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.events,
  storage_format 'parquet',
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.events",
    storage_format="parquet",
)
```
{% endtab %}
{% endtabs %}

***

## Engine properties

These properties pass engine-specific settings to Vulcan. Each engine has different capabilities, so these properties vary by engine.

### physical\_properties

Pass engine-specific properties directly to the physical table/view creation. Set things like retention policies, labels, or other engine-specific features.

**Use cases:**

* Set table retention (BigQuery: `partition_expiration_days`).
* Add labels or tags (BigQuery, Snowflake).
* Configure table type (Snowflake: `TRANSIENT` tables).
* Any other engine-specific table settings.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.daily_sales,
  physical_properties (
    partition_expiration_days = 7,
    require_partition_filter = true,
    creatable_type = TRANSIENT,  -- Creates TRANSIENT TABLE
  )
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",
    physical_properties={
        "partition_expiration_days": 7,
        "require_partition_filter": True,
        "creatable_type": "TRANSIENT",
    },
)
```
{% endtab %}
{% endtabs %}

### virtual\_properties

Pass engine-specific properties to the virtual layer view. Use this for view-level security, labels, or other view-specific settings.

**Use cases:**

* Create secure views (Snowflake: `SECURE` views).
* Add labels to views.
* Set view-level permissions.
* Configure view-specific engine features.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.daily_sales,
  virtual_properties (
    creatable_type = SECURE,  -- Creates SECURE VIEW
    labels = [('team', 'analytics')]
  )
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",
    virtual_properties={
        "creatable_type": "SECURE",
        "labels": [("team", "analytics")],
    },
)
```
{% endtab %}
{% endtabs %}

### session\_properties

Set session-level properties that apply when Vulcan executes your model. These affect how queries run but don't change the table structure.

**Use cases:**

* Set query timeouts.
* Configure parallelism.
* Adjust memory limits.
* Set engine-specific session variables.

**Example**: for a large query that needs more time, set `query_timeout: 3600` to give it an hour instead of the default.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.large_query,
  session_properties (
    query_timeout = 3600,
    max_parallel_workers = 8,
  )
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.large_query",
    session_properties={
        "query_timeout": 3600,
        "max_parallel_workers": 8,
    },
)
```
{% endtab %}
{% endtabs %}

### gateway

Specifies which gateway to use for executing this model. Useful when you have multiple database connections and want to route specific models to specific databases.

**When to use**: multi-warehouse setups, isolated environments, or when certain models need to run on a different database than the default.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.daily_sales,
  gateway 'warehouse_gateway',
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",
    gateway="warehouse_gateway",
)
```
{% endtab %}
{% endtabs %}

***

## Behavior properties

These properties control how Vulcan behaves when processing your model.

### stamp

Force a new model version without changing the definition. Use it as a version tag for tracking deployments or forcing a refresh.

**When to use**: when you want a new version for tracking, or to force downstream models to rebuild even though this model's definition hasn't changed.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.daily_sales,
  stamp 'v2.1.0',  -- Force new version
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.daily_sales",
    stamp="v2.1.0",
)
```
{% endtab %}
{% endtabs %}

### enabled

Control whether the model is active. Set to `false` to disable a model without deleting it.

**When to use:**

* Temporarily disable a model while debugging.
* Deprecate a model but keep it for reference.
* Skip models during development.

**Default**: `true` (models are enabled by default).

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.deprecated_model,
  enabled false,  -- Model will be ignored
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.deprecated_model",
    enabled=False,
)
```
{% endtab %}
{% endtabs %}

### allow\_partials

Allow processing of incomplete data intervals. By default, Vulcan waits for complete intervals before processing (keeps data quality high). Set this to `true` to process partial intervals.

**When to use:**

* Real-time or near-real-time models.
* When you need data ASAP, even if it's incomplete.
* Streaming data scenarios.

**Trade-off**: you lose the ability to distinguish between "missing data" (model issue) and "partial interval" (expected). Use with caution.

**Default**: `false` (wait for complete intervals).

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.realtime_events,
  allow_partials true,  -- Enable partial intervals
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.realtime_events",
    allow_partials=True,
)
```
{% endtab %}
{% endtabs %}

### optimize\_query

Turn query optimization on or off. Vulcan optimizes queries by default (rewrites them for better performance); sometimes you want to disable this.

**When to disable:**

* The optimizer breaks your query.
* You have engine-specific optimizations to preserve.
* Debugging query issues.

**Default**: `true` (optimize queries).

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.complex_query,
  optimize_query false,  -- Disable optimization
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.complex_query",
    optimize_query=False,
)
```
{% endtab %}
{% endtabs %}

### formatting

Control whether Vulcan formats this model when you run `vulcan format`. Set to `false` to preserve custom formatting.

**When to disable:**

* Legacy models with specific formatting requirements.
* Models where formatting breaks something.
* When you prefer manual formatting control.

**Default**: `true` (format models automatically).

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.legacy_model,
  formatting false,  -- Skip formatting
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.legacy_model",
    formatting=False,
)
```
{% endtab %}
{% endtabs %}

### ignored\_rules

Tell Vulcan's linter to ignore specific rules for this model. Useful when you have a legitimate reason to break a rule, or when a rule doesn't apply.

Ignore specific rules (`['rule_name', 'another_rule']`) or all rules (`'ALL'`).

**Use sparingly**: if you're ignoring lots of rules, the rules may need updating or the model may need refactoring.

{% tabs %}
{% tab title="SQL" %}
```sql
-- Ignore specific rules
MODEL (
  name sales.legacy_model,
  ignored_rules ['rule_name', 'another_rule'],
);

-- Ignore all rules
MODEL (
  name sales.legacy_model,
  ignored_rules 'ALL',
);
```
{% endtab %}

{% tab title="Python" %}
```python
# Ignore specific rules
@model(
    "sales.legacy_model",
    ignored_rules=["rule_name", "another_rule"],
)

# Ignore all rules
@model(
    "sales.legacy_model",
    ignored_rules="ALL",
)
```
{% endtab %}
{% endtabs %}

***

## Incremental model properties

These properties go inside the `kind` definition for incremental models. They control how incremental models behave: schema changes, restatements, and batch processing.

For the full picture on incremental models, see the [Model Kinds](model_kinds.md) documentation.

### Common incremental properties

These properties work with every incremental model kind. They control how Vulcan picks intervals, handles schema changes, and writes results:

| Property                | Description                                                                                   |  Type  | Default |
| ----------------------- | --------------------------------------------------------------------------------------------- | :----: | :-----: |
| `forward_only`          | All changes should be [forward-only](../../guides/incremental_by_time.md#forward-only-models) | `bool` | `false` |
| `on_destructive_change` | Behavior for destructive schema changes                                                       |  `str` | `error` |
| `on_additive_change`    | Behavior for additive schema changes                                                          |  `str` | `allow` |
| `disable_restatement`   | Disable [data restatement](../../guides/plan/plan_guide.md#restatement-plans-restate-model)   | `bool` | `false` |
| `auto_restatement_cron` | Cron expression for automatic restatement                                                     |  `str` |    -    |

**Values for `on_destructive_change` / `on_additive_change`:**

* **`allow`**: let the change happen (default for additive).
* **`warn`**: allow but warn about it.
* **`error`**: block the change (default for destructive).
* **`ignore`**: pretend it didn't happen.

**Why this matters**: schema changes can break downstream models. These settings control how strict Vulcan is when your schema evolves.

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.events,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column event_ts,
    forward_only true,
    on_destructive_change 'warn',
    on_additive_change 'allow',
    disable_restatement false,
  )
);
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.events",
    kind=dict(
        name=ModelKindName.INCREMENTAL_BY_TIME_RANGE,
        time_column="event_ts",
        forward_only=True,
        on_destructive_change="warn",
        on_additive_change="allow",
        disable_restatement=False,
    ),
)
```
{% endtab %}
{% endtabs %}

***

### INCREMENTAL\_BY\_TIME\_RANGE

Properties for models that update incrementally based on a time column. These control how time-based incremental processing works.

For the full guide on `INCREMENTAL_BY_TIME_RANGE` models, see the [Model Kinds documentation](model_kinds.md#incremental_by_time_range).

| Property                     | Description                                            |  Type | Required |
| ---------------------------- | ------------------------------------------------------ | :---: | :------: |
| **`time_column`**            | Column containing each row's timestamp (should be UTC) | `str` |   **Y**  |
| `format`                     | Format of the time column's data                       | `str` |     N    |
| `batch_size`                 | Maximum intervals per backfill task                    | `int` |     N    |
| `batch_concurrency`          | Maximum concurrent batches                             | `int` |     N    |
| `lookback`                   | Prior intervals to include for late-arriving data      | `int` |     N    |
| `auto_restatement_intervals` | Number of last intervals to auto-restate               | `int` |     N    |

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.events,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column event_ts,
    time_column (event_ts, '%Y-%m-%d'),  -- With format
    batch_size 12,
    batch_concurrency 4,
    lookback 7,
    auto_restatement_cron '@weekly',
    auto_restatement_intervals 7,
  )
);

SELECT
  event_ts::TIMESTAMP AS event_ts,
  event_type::VARCHAR AS event_type,
  user_id::INTEGER AS user_id
FROM raw.events
WHERE event_ts BETWEEN @start_ts AND @end_ts;
```
{% endtab %}

{% tab title="Python" %}
```python
from vulcan import ModelKindName

@model(
    "sales.events",
    columns={
        "event_ts": "timestamp",
        "event_type": "varchar",
        "user_id": "int",
    },
    kind=dict(
        name=ModelKindName.INCREMENTAL_BY_TIME_RANGE,
        time_column="event_ts",
        batch_size=12,
        batch_concurrency=4,
        lookback=7,
    ),
    depends_on=["raw.events"],
)
def execute(context, start, end, **kwargs) -> pd.DataFrame:
    query = f"""
    SELECT event_ts, event_type, user_id
    FROM raw.events
    WHERE event_ts BETWEEN '{start}' AND '{end}'
    """
    return context.fetchdf(query)
```
{% endtab %}
{% endtabs %}

{% hint style="info" %}
**Important: UTC timezone**

Your `time_column` should be in UTC. This ensures Vulcan's scheduler and time macros work correctly.
{% endhint %}

***

### INCREMENTAL\_BY\_UNIQUE\_KEY

Properties for models that update based on unique keys (upsert operations). These control MERGE behavior and key handling.

For details on `INCREMENTAL_BY_UNIQUE_KEY` models, see the [Model Kinds documentation](model_kinds.md#incremental_by_unique_key).

| Property         | Description                                               |       Type       | Required |
| ---------------- | --------------------------------------------------------- | :--------------: | :------: |
| **`unique_key`** | Column(s) containing each row's unique key                | `str` \| `array` |   **Y**  |
| `when_matched`   | SQL logic to update columns on match (MERGE engines only) |       `str`      |     N    |
| `merge_filter`   | Predicates for ON clause of MERGE operation               |       `str`      |     N    |
| `batch_size`     | Maximum intervals per backfill task                       |       `int`      |     N    |
| `lookback`       | Prior intervals to include for late-arriving data         |       `int`      |     N    |

{% tabs %}
{% tab title="SQL" %}
```sql
-- Single unique key
MODEL (
  name sales.customers,
  kind INCREMENTAL_BY_UNIQUE_KEY (
    unique_key customer_id,
  )
);

-- Composite unique key
MODEL (
  name sales.order_items,
  kind INCREMENTAL_BY_UNIQUE_KEY (
    unique_key (order_id, item_id),
  )
);

-- With MERGE options
MODEL (
  name sales.customers,
  kind INCREMENTAL_BY_UNIQUE_KEY (
    unique_key customer_id,
    when_matched WHEN MATCHED THEN UPDATE SET 
      name = source.name,
      updated_at = source.updated_at,
    auto_restatement_cron '@weekly',
  )
);
```
{% endtab %}

{% tab title="Python" %}
```python
# Single unique key
@model(
    "sales.customers",
    columns={
        "customer_id": "int",
        "name": "varchar",
        "email": "varchar",
    },
    kind=dict(
        name=ModelKindName.INCREMENTAL_BY_UNIQUE_KEY,
        unique_key="customer_id",
    ),
    depends_on=["raw.customers"],
)

# Composite unique key
@model(
    "sales.order_items",
    kind=dict(
        name=ModelKindName.INCREMENTAL_BY_UNIQUE_KEY,
        unique_key=["order_id", "item_id"],
    ),
)
```
{% endtab %}
{% endtabs %}

{% hint style="info" %}
**Batch concurrency**

`batch_concurrency` isn't supported for this kind because MERGE operations can't safely run in parallel. Vulcan processes these models sequentially to avoid conflicts.
{% endhint %}

***

### INCREMENTAL\_BY\_PARTITION

Properties for models that update by partition. This kind uses the `partitioned_by` property (from the General Properties section) as its partition key.

**Note**: there are no additional kind-specific properties; use `partitioned_by` to define your partition columns.

For details on `INCREMENTAL_BY_PARTITION` models, see the [Model Kinds documentation](model_kinds.md#incremental_by_partition).

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name sales.events,
  kind INCREMENTAL_BY_PARTITION,
  partitioned_by event_date,
);

SELECT
  event_date::DATE AS event_date,
  event_type::VARCHAR AS event_type,
  COUNT(*)::INTEGER AS event_count
FROM raw.events
GROUP BY event_date, event_type;
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "sales.events",
    columns={
        "event_date": "date",
        "event_type": "varchar",
        "event_count": "int",
    },
    kind=dict(name=ModelKindName.INCREMENTAL_BY_PARTITION),
    partitioned_by=["event_date"],
    depends_on=["raw.events"],
)
```
{% endtab %}
{% endtabs %}

***

### SCD\_TYPE\_2

Properties for Slowly Changing Dimension Type 2 models, which track historical changes to your data.

For the complete guide on SCD Type 2 models, see the [Model Kinds documentation](model_kinds.md#scd-type-2).

#### Common SCD Type 2 properties

| Property                  | Description                                |   Type  |          Required         |
| ------------------------- | ------------------------------------------ | :-----: | :-----------------------: |
| **`unique_key`**          | Column(s) containing each row's unique key | `array` |           **Y**           |
| `valid_from_name`         | Column for valid from date                 |  `str`  | N (default: `valid_from`) |
| `valid_to_name`           | Column for valid to date                   |  `str`  |  N (default: `valid_to`)  |
| `invalidate_hard_deletes` | Mark missing records as invalid            |  `bool` |    N (default: `true`)    |

#### SCD\_TYPE\_2\_BY\_TIME

Properties for SCD Type 2 models that detect changes using an `updated_at` timestamp column. This is the recommended approach when your source table has update timestamps.

| Property                   | Description                                         |  Type  |          Required         |
| -------------------------- | --------------------------------------------------- | :----: | :-----------------------: |
| `updated_at_name`          | Column containing updated at date                   |  `str` | N (default: `updated_at`) |
| `updated_at_as_valid_from` | Use `updated_at` value as `valid_from` for new rows | `bool` |    N (default: `false`)   |

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name dim.customers,
  kind SCD_TYPE_2_BY_TIME (
    unique_key customer_id,
    updated_at_name last_modified,
    valid_from_name effective_from,
    valid_to_name effective_to,
    invalidate_hard_deletes false,
    updated_at_as_valid_from true,
  )
);

SELECT
  customer_id::INTEGER AS customer_id,
  name::VARCHAR AS name,
  email::VARCHAR AS email,
  last_modified::TIMESTAMP AS last_modified
FROM raw.customers;
```
{% endtab %}

{% tab title="Python" %}
```python
@model(
    "dim.customers",
    columns={
        "customer_id": "int",
        "name": "varchar",
        "email": "varchar",
        "last_modified": "timestamp",
    },
    kind=dict(
        name=ModelKindName.SCD_TYPE_2_BY_TIME,
        unique_key=["customer_id"],
        updated_at_name="last_modified",
        valid_from_name="effective_from",
        valid_to_name="effective_to",
        invalidate_hard_deletes=False,
    ),
    depends_on=["raw.customers"],
)
```
{% endtab %}
{% endtabs %}

#### SCD\_TYPE\_2\_BY\_COLUMN

Properties for SCD Type 2 models that detect changes by comparing column values. Use this when your source table doesn't have an `updated_at` column.

| Property                       | Description                                     |       Type       |       Required       |
| ------------------------------ | ----------------------------------------------- | :--------------: | :------------------: |
| **`columns`**                  | Columns to check for changes (`*` for all)      | `str` \| `array` |         **Y**        |
| `execution_time_as_valid_from` | Use execution time as `valid_from` for new rows |      `bool`      | N (default: `false`) |

{% tabs %}
{% tab title="SQL" %}
```sql
-- Track specific columns
MODEL (
  name dim.products,
  kind SCD_TYPE_2_BY_COLUMN (
    unique_key product_id,
    columns (name, price, category),
    execution_time_as_valid_from true,
  )
);

-- Track all columns
MODEL (
  name dim.products,
  kind SCD_TYPE_2_BY_COLUMN (
    unique_key product_id,
    columns '*',
  )
);
```
{% endtab %}

{% tab title="Python" %}
```python
# Track specific columns
@model(
    "dim.products",
    columns={
        "product_id": "int",
        "name": "varchar",
        "price": "decimal(10,2)",
        "category": "varchar",
    },
    kind=dict(
        name=ModelKindName.SCD_TYPE_2_BY_COLUMN,
        unique_key=["product_id"],
        columns=["name", "price", "category"],
        execution_time_as_valid_from=True,
    ),
    depends_on=["raw.products"],
)

# Track all columns
@model(
    "dim.products",
    kind=dict(
        name=ModelKindName.SCD_TYPE_2_BY_COLUMN,
        unique_key=["product_id"],
        columns="*",
    ),
)
```
{% endtab %}
{% endtabs %}

***

## Model naming

By default, you specify the `name` property in every model. If you organize your models in a directory structure that matches your schema names, you can turn on automatic name inference.

**How it works**: with `infer_names: true`, a model at `models/sales/daily_sales.sql` automatically gets the name `sales.daily_sales`. The directory structure becomes your schema, and the filename becomes your model name.

Turn it on in your config:

```yaml
model_defaults:
  dialect: snowflake
  
# Enable name inference
infer_names: true
```

**When to use**: when your project structure matches your schema structure, this saves you from typing `name` in every model.

Learn more in the [configuration guide](../../configurations/README.md#model-defaults).
