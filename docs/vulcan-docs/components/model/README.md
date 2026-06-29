# Model

Models transform raw data into tables and views. Define what you want (the metadata) and how to make it (the SQL query), and Vulcan handles the rest.

Models live in `.sql` and `.py` files in the `models/` directory of your project. Vulcan automatically figures out how your models relate to each other by parsing your SQL, so you don't have to manually configure dependencies. Write your SQL, and Vulcan handles the lineage.

Every model has two parts:

* **DDL (Data Definition Language)** - The `MODEL` block that tells Vulcan what this model is (name, schedule, how to materialize it, etc.)
* **DML (Data Manipulation Language)** - The `SELECT` query that does the actual transformation work

The DDL defines the model metadata. The DML contains the transformation logic.

## Model Structure

You can write models in SQL or Python. Both work the same way conceptually; they just look different. Let's see both:

{% tabs %}
{% tab title="SQL Model" %}
```sql
MODEL (
  name sales.daily_sales,
  kind FULL,
  cron '@daily',
  grains (order_date),
  tags ('silver', 'sales', 'aggregation'),
  terms ('sales.daily_metrics', 'analytics.sales_summary'),
  description 'Daily sales summary with order counts and revenue',
  column_descriptions (
    order_date = 'Date of the sales transactions',
    total_orders = 'Total number of orders for the day',
    total_revenue = 'Total revenue for the day',
    last_order_id = 'Last order ID processed for the day'
  ),
  column_tags (
    order_date = ('dimension', 'grain', 'date'),
    total_orders = ('measure', 'count'),
    total_revenue = ('measure', 'financial'),
    last_order_id = ('dimension', 'identifier')
  )
);

SELECT
  CAST(order_date AS TIMESTAMP)::TIMESTAMP AS order_date,
  COUNT(order_id)::INTEGER AS total_orders,
  SUM(total_amount)::FLOAT AS total_revenue,
  MAX(order_id)::VARCHAR AS last_order_id
FROM raw.raw_orders
GROUP BY order_date
ORDER BY order_date
```

**Breaking it down:**

* **Lines 1-21**: The DDL (`MODEL` block) - tells Vulcan this is a daily sales model with metadata, tags, and column documentation
* **Lines 23-31**: The DML (`SELECT` query) - the actual transformation that aggregates orders by date
{% endtab %}

{% tab title="Python Model" %}
```python
import typing as t
import pandas as pd
from datetime import datetime
from vulcan import ExecutionContext, model
from vulcan import ModelKindName

@model(
  "sales.daily_sales_py",
  columns={
    "order_date": "timestamp",
    "total_orders": "int",
    "total_revenue": "decimal(18,2)",
    "last_order_id": "string",
  },
  kind=dict(name=ModelKindName.FULL),
  grains=["order_date"],
  depends_on=["raw.raw_orders"],
  cron='@daily',
  tags=["silver", "sales", "aggregation"],
  terms=["sales.daily_metrics", "analytics.sales_summary"],
  description="Daily sales summary with order counts and revenue",
  column_descriptions={
    "order_date": "Date of the sales transactions",
    "total_orders": "Total number of orders for the day",
    "total_revenue": "Total revenue for the day",
    "last_order_id": "Last order ID processed for the day",
  },
  column_tags={
    "order_date": ["dimension", "grain", "date"],
    "total_orders": ["measure", "count"],
    "total_revenue": ["measure", "financial"],
    "last_order_id": ["dimension", "identifier"],
  },
)
def execute(
  context: ExecutionContext,
  start: datetime,
  end: datetime,
  execution_time: datetime,
  **kwargs: t.Any,
) -> pd.DataFrame:

  query = """
  SELECT
    CAST(order_date AS TIMESTAMP) AS order_date,
    COUNT(order_id)::INTEGER AS total_orders,
    SUM(total_amount)::NUMERIC(18,2) AS total_revenue,
    MAX(order_id)::VARCHAR AS last_order_id
  FROM raw.raw_orders
  GROUP BY order_date
  ORDER BY order_date
  """

  return context.fetchdf(query)
```

**Breaking it down:**

* **Lines 7-34**: The DDL (`@model` decorator) - same metadata as SQL with tags, terms, and column documentation
* **Lines 35-54**: The DML (function body) - runs the SQL and returns a DataFrame
{% endtab %}
{% endtabs %}

Both formats do the same thing. Choose the one you prefer.

## DDL: The MODEL Block

The `MODEL` block is where you tell Vulcan about your model. It's the first thing in your file (after any comments) and uses a simple, declarative syntax.

### Basic Syntax

Here's what a `MODEL` block looks like:

```sql
MODEL (
  name sales.daily_sales,
  kind FULL,
  cron '@daily',
  grains (order_date),
  tags ('silver', 'sales'),
  terms ('sales.daily_metrics'),
  description 'Daily sales summary'
);
```

This tells Vulcan:

* **`name`** - What to call this model (`schema.table` or `catalog.schema.table` if targeting a non-default database)
* **`kind`** - How to materialize it (FULL rebuilds everything, INCREMENTAL only updates changes, etc.)
* **`cron`** - When to run it (`@daily` means every day)
* **`grains`** - What makes each row unique (uses tuple syntax with parentheses)
* **`tags`** - Labels for categorization (uses tuple syntax)
* **`terms`** - Business glossary terms using dot notation
* **`description`** - Human-readable description of the model

### Common Properties

Here are the properties you'll use most often:

| Property      | What It Does                                                          | Example                                       |
| ------------- | --------------------------------------------------------------------- | --------------------------------------------- |
| `name`        | Fully qualified model name (`schema.table` or `catalog.schema.table`) | `sales.daily_sales`                           |
| `kind`        | Materialization strategy                                              | `FULL`, `INCREMENTAL`, `VIEW`                 |
| `cron`        | When to run (scheduling)                                              | `'@daily'`, `'0 0 * * *'`                     |
| `grains`      | Column(s) that make rows unique                                       | `(order_date)` or `(customer_id, order_date)` |
| `owner`       | Who owns this model (for governance)                                  | `analytics_team`                              |
| `description` | Human-readable description                                            | `'Daily sales aggregates'`                    |
| `tags`        | Labels for organizing models                                          | `('gold', 'analytics', 'customer')`           |
| `terms`       | Business glossary terms                                               | `('customer.rfm_analysis')`                   |

{% hint style="info" %}
**More DDL Properties**

There are more properties available beyond these common ones, including `column_descriptions`, `column_tags`, and `column_terms` for column-level metadata. Check out the [Model Properties](properties.md) reference for the complete list of all available model properties and their configurations.
{% endhint %}

## DML: The SELECT Query

The `SELECT` is the transformation. Vulcan wraps it with the right DDL and DML for the model kind (`CREATE OR REPLACE`, `INSERT`, `MERGE`, and so on), but the shape of the output is entirely whatever this query returns.

```sql
SELECT
  CAST(order_date AS TIMESTAMP)::TIMESTAMP AS order_date,
  COUNT(order_id)::INTEGER AS total_orders,
  SUM(total_amount)::FLOAT AS total_revenue,
  MAX(order_id)::VARCHAR AS last_order_id
FROM raw.raw_orders
GROUP BY order_date
ORDER BY order_date
```

This query:

* Reads from `raw.raw_orders`
* Groups by `order_date`
* Counts orders, sums revenue, finds the latest order ID
* Returns the results ordered by date

Pretty standard SQL! Vulcan will automatically figure out that this model depends on `raw.raw_orders` and build the dependency graph for you.

## Conventions

Vulcan tries to be smart and infer as much as possible from your SQL. This means you don't have to write a bunch of YAML config files, just write SQL and Vulcan figures it out. But to do this, your SQL needs to follow some conventions.

### SQL Model Conventions

#### Unique Column Names

Your final `SELECT` needs unique column names. No duplicates allowed!

```sql
-- Good: Each column has a unique name
SELECT
  order_date::TIMESTAMP AS order_date,
  COUNT(order_id)::INTEGER AS total_orders,
  SUM(total_amount)::FLOAT AS total_revenue
FROM raw.raw_orders
GROUP BY order_date
```

If you have duplicate column names, Vulcan won't know which one you mean, and that causes problems.

#### Explicit Types

Cast your types explicitly. This prevents surprises and ensures your schema is consistent:

```sql
-- Explicit casting ensures consistent schema
SELECT
  CAST(order_date AS TIMESTAMP)::TIMESTAMP AS order_date,  -- explicit timestamp
  COUNT(order_id)::INTEGER AS total_orders,                 -- explicit integer
  SUM(total_amount)::FLOAT AS total_revenue,                -- explicit float
  MAX(order_id)::VARCHAR AS last_order_id                   -- explicit varchar
FROM raw.raw_orders
GROUP BY order_date
```

Vulcan uses PostgreSQL-style casting (`x::int`), but don't worry, it automatically converts this to whatever your execution engine needs. So you write `::INTEGER` and Vulcan handles the rest.

**Why this matters:** Without explicit types, you might get `FLOAT` when you expected `INTEGER`, or `VARCHAR` when you wanted `TIMESTAMP`. Explicit casting prevents these surprises.

#### Inferrable Names

Your columns need names that Vulcan can figure out. If Vulcan can't infer a name, you need to add an alias:

```sql
SELECT
  1,                              -- not inferrable (what do you call this?)
  total_amount + 1,               -- not inferrable (needs an alias)
  SUM(total_amount),              -- not inferrable (needs an alias)
  order_date,                     -- inferrable as order_date
  order_date::TIMESTAMP,          -- inferrable as order_date
  total_amount + 1 AS adjusted,   -- explicitly named
  SUM(total_amount) AS revenue    -- explicitly named
```

If you forget an alias, Vulcan's formatter will add one automatically when it renders your SQL. But it's better to be explicit, you'll know what the column is called!

#### Column Metadata

Document and categorize your columns using column-level metadata properties. There are several options:

**Column Descriptions (Recommended)**

```sql
MODEL (
  name sales.daily_sales,
  kind FULL,
  cron '@daily',
  grains (order_date),
  description 'Aggregated daily sales metrics',
  column_descriptions (
    order_date = 'The date of the sales transactions',
    total_orders = 'Count of orders placed on this date',
    total_revenue = 'Sum of all order amounts for this date',
    last_order_id = 'The most recent order ID for this date'
  )
);
```

This keeps all your documentation in one place, in the MODEL block.

**Column Tags and Terms**

Beyond descriptions, you can also add tags and business glossary terms to columns:

```sql
MODEL (
  name gold_v1.rfm_customer_segmentation,
  kind FULL,
  cron '@daily',
  grains (customer_id),
  description 'RFM customer segmentation model',
  column_tags (
    customer_id = ('primary_key', 'identifier', 'grain'),
    customer_name = ('dimension', 'label', 'pii'),
    email = ('dimension', 'pii', 'contact'),
    rfm_score = ('measure', 'score', 'composite')
  ),
  column_terms (
    customer_id = ('customer.customer_id', 'identity.customer_id'),
    rfm_score = ('analytics.rfm_score', 'segmentation.rfm_composite')
  )
);
```

* **`column_tags`** - Categorize columns by role (`dimension`, `measure`), sensitivity (`pii`), or purpose
* **`column_terms`** - Link columns to business glossary terms for semantic understanding

See [Model Properties](properties.md#column_tags) for detailed documentation on all column-level metadata options.

{% hint style="info" %}
**Priority**

If you use `column_descriptions` in the DDL, Vulcan will use those and ignore any inline comments in your query. DDL descriptions take priority, so if you define descriptions in both places, the DDL version wins.
{% endhint %}

**Option 2: Inline Comments**

If you don't specify `column_descriptions` in the DDL, Vulcan will automatically pick up comments from your query:

```sql
MODEL (
  name sales.daily_sales,
  kind FULL,
  cron '@daily',
  grains (order_date)
);

SELECT
  order_date::TIMESTAMP AS order_date,           -- The date of sales transactions
  COUNT(order_id)::INTEGER AS total_orders,      -- Number of orders placed
  SUM(total_amount)::FLOAT AS total_revenue,     -- Total revenue for the day
  MAX(order_id)::VARCHAR AS last_order_id        -- Most recent order ID
FROM raw.raw_orders
GROUP BY order_date
```

Vulcan registers these comments as column descriptions in your database.

**Table comments:** If you put a comment before the `MODEL` block, Vulcan will use it as the table description. But if you also specify `description` in the MODEL block, that takes priority.

### Python Model Conventions

Python models work a bit differently because Python doesn't have the same type inference capabilities as SQL.

#### Explicit Column Definitions

You **must** define your columns explicitly in the `@model` decorator:

```python
@model(
    "sales.daily_sales_py",
    columns={
        "order_date": "timestamp",
        "total_orders": "int",
        "total_revenue": "decimal(18,2)",
        "last_order_id": "string",
    },
    kind=dict(name=ModelKindName.FULL),
)
```

Vulcan can't infer types from Python code the way it can from SQL, so you need to tell it explicitly.

#### Explicit Dependencies

Unlike SQL models (where Vulcan figures out dependencies automatically), Python models need you to list them:

```python
@model(
    "sales.daily_sales_py",
    columns={...},
    depends_on=["raw.raw_orders"],  # Must explicitly list upstream models
)
```

This is because Vulcan can't parse your Python code to find `FROM` clauses and joins. You need to tell it what this model depends on.

#### Column Metadata

Python models can't use inline comments for column descriptions. Instead, specify them in the decorator using `column_descriptions`, `column_tags`, and `column_terms`:

```python
@model(
    "gold_v1.rfm_customer_segmentation",
    columns={
        "customer_id": "int",
        "customer_name": "string",
        "rfm_score": "int",
    },
    column_descriptions={
        "customer_id": "Unique identifier for each customer",
        "customer_name": "Customer full name",
        "rfm_score": "Combined RFM score (111-555)",
    },
    column_tags={
        "customer_id": ["primary_key", "identifier", "grain"],
        "customer_name": ["dimension", "label", "pii"],
        "rfm_score": ["measure", "score", "composite"],
    },
    column_terms={
        "customer_id": ["customer.customer_id", "identity.customer_id"],
        "rfm_score": ["analytics.rfm_score", "segmentation.rfm_composite"],
    },
)
```

{% hint style="warning" %}
**Column name validation**

Vulcan will error if you put a column name in `column_descriptions`, `column_tags`, or `column_terms` that doesn't exist in `columns`. This prevents typos and keeps things consistent, if you describe a column, it better exist!
{% endhint %}

#### Return Type

Your `execute` function must return a pandas DataFrame, and the columns must match what you defined in `columns`:

```python
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:  # Must return a DataFrame
    query = "SELECT ..."
    return context.fetchdf(query)
```

The DataFrame columns need to match your `columns` definition exactly, same names, compatible types.

{% hint style="info" %}
**Learn more**

See [Python Models](types/python_models.md) for detailed information, advanced patterns, and more examples.
{% endhint %}

## Comment Registration

Vulcan registers comments (descriptions) in your database so they show up in your BI tools and data catalogs.

### How Comments Get Registered

**Model-level comments:**

* If you put a comment before the `MODEL` block, Vulcan uses it as the table comment
* If you also specify `description` in the MODEL block, that takes priority

**Column-level comments:**

* Use `column_descriptions` in the DDL (recommended)
* Or use inline comments in your SELECT query (if `column_descriptions` isn't specified)

### What Gets Registered

Not everything gets comments registered:

* **Physical tables** - Comments are registered (tables in the `vulcan__[project schema]` schema)
* **Production views** - Comments are registered
* **Temporary tables** - No comments (they're temporary)
* **Non-production views** - No comments (keeps things clean)

**Note:** Some engines automatically pass comments from physical tables to views that select from them. So even if Vulcan didn't explicitly register a comment on a view, it might still show up if the engine does this automatically.

### Engine Support

Different databases support comments differently. Some can register comments in the `CREATE` statement (one command), others need separate commands for each comment.

Here's what each engine supports:

| Engine    | `TABLE` comments | `VIEW` comments |
| --------- | ---------------- | --------------- |
| Postgres  | Y                | Y               |
| Snowflake | Y                | Y               |
| Spark     | Y                | Y               |

If your engine doesn't support comments, Vulcan will skip registration (no errors, it just won't register them).

## Macros

Macros are like variables for your SQL. They let you parameterize queries and avoid repetition. Vulcan provides several built-in macros (like `@start_ds` and `@end_ds` for incremental models), and you can define your own.

Macros use the `@` prefix. For example, `@this_model` refers to the current model being processed, and `@start_ds` is the start date for incremental processing.

See the [macros documentation](../advanced-features/macros/) for details.
