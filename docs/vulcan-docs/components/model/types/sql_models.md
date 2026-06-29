# SQL models

SQL models are the most common type of model you write. Define them using SQL directly, or use Python to generate SQL dynamically.

SQL models work with every supported engine (Postgres, Snowflake, Spark, Trino, BigQuery, Databricks, Redshift, MSSQL, Fabric). Most transformations in a project end up as SQL models, with Python reserved for the few cases that do not fit SQL.

## SQL-based definition

SQL-based models are the most common type. They use regular SQL with additional Vulcan features.

**Structure:** a SQL model file has these parts (in order):

1. The `MODEL` DDL (metadata and configuration)
2. Optional pre-statements (setup SQL)
3. A single query (your transformation logic)
4. Optional post-statements (cleanup or optimization SQL)
5. Optional on-virtual-update statements (view permissions, and so on)

**Creating a SQL model:** add a `.sql` file to your `models/` directory (or a subdirectory). The filename does not matter to Vulcan, but it is conventional to name it after your model. For example, `sales.daily_sales` → `daily_sales.sql`.

### Example

A simple SQL model to get you started:

```sql
-- This is the MODEL DDL, where you specify model metadata and configuration information.
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

/*
  This is the single query that defines the model's logic.
  Although it is not required, it is considered best practice to explicitly
  specify the type for each one of the model's columns through casting.
*/
SELECT
  CAST(order_date AS TIMESTAMP)::TIMESTAMP AS order_date,
  COUNT(order_id)::INTEGER AS total_orders,
  SUM(total_amount)::FLOAT AS total_revenue,
  MAX(order_id)::VARCHAR AS last_order_id
FROM raw.raw_orders
GROUP BY order_date
ORDER BY order_date
```

### `MODEL` DDL

The `MODEL` DDL is where you define your model's metadata: name, kind, schedule, owner, and more. It must be the first statement in your SQL file.

The `MODEL` DDL tells Vulcan everything it needs to know about your model. For a complete list of all available properties, see the [Model Properties](../properties.md) documentation.

### Optional pre/post-statements

Pre-statements run before your query. Post-statements run after. Use them for setup, cleanup, and optimization tasks.

**Common use cases:**

* Pre-statements: set session parameters, load UDFs, cache tables.
* Post-statements: create indexes, run data quality checks, set retention policies.

**Important:** pre/post-statements must end with semicolons. If you have post-statements, your main query must also end with a semicolon (so Vulcan knows where the query ends).

{% hint style="warning" %}
**Concurrency**

Be careful with pre-statements that create or alter physical tables. If multiple models run concurrently, you can get conflicts. Stick to session settings and temporary objects.
{% endhint %}

```sql
MODEL (
  name sales.daily_sales,
  kind FULL
);

-- Pre-statement: Cache a table for use in the query
CACHE TABLE countries AS SELECT * FROM raw.countries;

-- The model query (must end with semi-colon when post-statements are present)
SELECT
  order_date::TIMESTAMP AS order_date,
  COUNT(order_id)::INTEGER AS total_orders,
  SUM(total_amount)::FLOAT AS total_revenue
FROM raw.raw_orders
GROUP BY order_date;

-- Post-statement: Clean up the cached table
UNCACHE TABLE countries;
```

**Project-level defaults:** you can define pre/post-statements in `model_defaults` for consistent behavior across all models. Default statements run first, then model-specific ones. Learn more in the [model configuration reference](../../../configurations/options/model_defaults.md).

{% hint style="warning" %}
**Statements run twice**
{% endhint %}

Pre/post-statements are evaluated twice: when a model's table is created and when its query logic is evaluated. Executing statements more than once can have unintended side-effects. You can [conditionally execute](../../advanced-features/macros/built_in.md#prepost-statements) them based on Vulcan's [runtime stage](../../advanced-features/macros/variables.md#runtime-variables).

```
**Solution:** Use conditional execution with `@IF` and `@runtime_stage` to control when statements run. For example, only run a post-statement when the query is actually being evaluated:
```

You can condition the post-statement to only run after the model query is evaluated using the [`@IF` macro operator](../../advanced-features/macros/built_in.md#if) and [`@runtime_stage` macro variable](../../advanced-features/macros/variables.md#runtime-variables):

```sql
MODEL (
  name sales.daily_sales,
  kind FULL
);

CACHE TABLE countries AS SELECT * FROM raw.countries;

SELECT
  order_date::TIMESTAMP AS order_date,
  COUNT(order_id)::INTEGER AS total_orders
FROM raw.raw_orders
GROUP BY order_date;

@IF(
  @runtime_stage = 'evaluating',
  UNCACHE TABLE countries
);
```

**Important:** the SQL command inside `@IF()` does not end with a semicolon. The semicolon goes after the `@IF()` macro's closing parenthesis.

### Optional on-virtual-update statements

On-virtual-update statements run when views are created or updated in the virtual layer. This happens after your model's physical table is created and the view is set up.

**Common use case:** granting permissions on views so users can query them.

**Project-level defaults:** you can define on-virtual-update statements at the project level using `model_defaults` in your configuration. These apply to all models in your project and merge with any model-specific statements. Default statements run first, then model-specific statements. Learn more in the [model configuration reference](../../../configurations/options/model_defaults.md).

**Syntax:** wrap these statements in `ON_VIRTUAL_UPDATE_BEGIN;` ... `ON_VIRTUAL_UPDATE_END;` blocks:

```sql
MODEL (
  name sales.daily_sales,
  kind FULL
);

SELECT
  order_date::TIMESTAMP,
  COUNT(order_id)::INTEGER AS total_orders
FROM raw.raw_orders
GROUP BY order_date;

ON_VIRTUAL_UPDATE_BEGIN;
GRANT SELECT ON VIEW @this_model TO ROLE role_name;
JINJA_STATEMENT_BEGIN;
GRANT SELECT ON VIEW {{ this_model }} TO ROLE admin;
JINJA_END;
ON_VIRTUAL_UPDATE_END;
```

**Jinja support:** you can use [Jinja expressions](../../advanced-features/macros/jinja.md) in these statements. Wrap them in `JINJA_STATEMENT_BEGIN;` ... `JINJA_END;` blocks (as shown in the example above).

{% hint style="info" %}
**Virtual layer resolution**

These statements run at the virtual layer, so table names resolve to view names, not physical table names. In a `dev` environment, `sales.daily_sales` and `@this_model` resolve to `sales__dev.daily_sales` (the view), not the physical table.
{% endhint %}

### The model query

Your model must contain a standalone query. This can be:

* A single `SELECT` statement
* Multiple `SELECT` statements combined with `UNION`, `INTERSECT`, or `EXCEPT`

The result of this query becomes your model's table or view data.

### SQL model blueprinting

SQL models can serve as templates for creating multiple models. This is called blueprinting: define one template, get multiple models.

**How it works:** parameterize your model name with a variable (using `@{variable}` syntax) and provide a list of mappings in `blueprints`. Vulcan creates one model for each mapping.

**Use case:** when you have similar models that differ only by parameters (such as different regions, schemas, or customers).

This example creates four models from one template:

```sql
MODEL (
  name vulcan_demo.fct_daily_sales__@{region},
  kind VIEW,
  blueprints (
    (region := 'north'),
    (region := 'south'),
    (region := 'east'),
    (region := 'west')
  ),
  grains region_id
);

SELECT
  *
FROM vulcan_demo.fct_daily_sales
@WHERE(TRUE)
  LOWER(region_name) = LOWER(@region)
```

Vulcan creates these four models from that template:

```sql
-- This uses the first variable mapping
MODEL (
  name vulcan_demo.fct_daily_sales__north,
  kind VIEW
);

SELECT
  *
FROM vulcan_demo.fct_daily_sales
WHERE
  LOWER(region_name) = LOWER('north')

-- This uses the second variable mapping
MODEL (
  name vulcan_demo.fct_daily_sales__south,
  kind VIEW
);

SELECT
  *
FROM vulcan_demo.fct_daily_sales
WHERE
  LOWER(region_name) = LOWER('south')
```

**Important syntax:** notice `@{region}` in the model name. The curly braces tell Vulcan to treat the variable value as a SQL identifier (not a string literal).

You can see the different behavior in the `WHERE` clause. `@region` (without braces) resolves to the string literal `'north'` (with single quotes) because the blueprint value is quoted. Learn more about the curly brace syntax [here](../../advanced-features/macros/built_in.md#embedding-variables-in-strings).

**Dynamic blueprints:** you can generate blueprints using macros. Use this when your blueprint list comes from external sources (CSV files, APIs, and so on):

```sql
MODEL (
  name vulcan_demo.fct_daily_sales__@{region},
  blueprints @gen_blueprints(),  -- Macro generates the list
  ...
);
```

Here is how to define the macro:

```python
from vulcan import macro

@macro()
def gen_blueprints(evaluator):
    return (
        "((region := 'north'),"
        " (region := 'south'),"
        " (region := 'east'),"
        " (region := 'west'))"
    )
```

You can also use the `@EACH` macro with a global list variable:

```sql
MODEL (
  name vulcan_demo.fct_daily_sales__@{region},
  kind VIEW,
  blueprints @EACH(@values, x -> (region := @x)),
);

SELECT
  *
FROM vulcan_demo.fct_daily_sales
@WHERE(TRUE)
  LOWER(region_name) = LOWER(@region)
```

## Python-based definition

You can also define SQL models using Python. This is useful when:

* Your query is too complex for clean SQL
* You need heavy dynamic logic (which would require lots of macros)
* You want to generate SQL programmatically

**How it works:** you write Python code that generates SQL, and Vulcan executes it. You still get SQL models (they run SQL queries), but you write them in Python.

For the complete guide on Python-based SQL models, including the `@model` decorator, execution context, and examples, see the [Python Models](python_models.md) page.

## Automatic dependencies

Vulcan parses your SQL and figures out dependencies automatically. You do not need to specify what your model depends on.

**How it works:** Vulcan analyzes your `FROM` and `JOIN` clauses and builds a dependency graph. When you run `vulcan plan`, it ensures upstream models run first.

**Example:** this query automatically depends on `raw.raw_orders`:

```sql
SELECT order_date, COUNT(order_id) AS total_orders
FROM raw.raw_orders
GROUP BY order_date
```

Vulcan makes sure `raw.raw_orders` runs before this model.

**External dependencies:** if you reference tables that are not Vulcan models, Vulcan can handle them too, either implicitly (through execution order) or via [signals](../../advanced-features/signals.md).

**Manual dependencies:** sometimes you need to add extra dependencies manually (a hidden dependency or a macro that references another model). Use the `depends_on` property in your `MODEL` DDL for that.

## Conventions

Vulcan follows some conventions to keep things consistent and reliable. The key ones:

### Explicit type casting

Vulcan encourages explicit type casting for all columns. This helps Vulcan understand your data types and prevents incorrect inference.

**Format:** use `column_name::data_type` syntax (works in any SQL dialect):

```sql
SELECT
  order_date::DATE AS order_date,
  total_orders::INTEGER AS total_orders,
  revenue::DECIMAL(10,2) AS revenue
```

**Why this matters:** explicit types make your models more predictable and help Vulcan optimize queries better.

### Explicit SELECTs

Avoid `SELECT *` when possible. It is convenient but dangerous: if an upstream source adds or removes columns, your model's output changes unexpectedly.

**Best practice:** list every column you need explicitly. If you query external sources, use [`create_external_models`](../../../cli.md#create_external_models) to capture their schema, or define them as [external models](../model_kinds.md#external).

**Why avoid `SELECT *` on external sources:** it prevents Vulcan from optimizing queries and determining column-level lineage. Define external models instead.

### Encoding

SQL model files must be UTF-8 encoded. Other encodings can cause parsing errors or unexpected behavior.

## Transpilation

Vulcan uses [SQLGlot](https://github.com/tobymao/sqlglot) to parse and transpile SQL. This gives you:

**Write in any dialect, run on any engine:** write PostgreSQL-style SQL, and Vulcan converts it to BigQuery. Or write Snowflake SQL and run it on Spark.

**Use advanced syntax:** you can use features from one dialect even if your engine does not support them. For example, `x::int` (PostgreSQL syntax) works even on engines that only support `CAST(x AS INT)`. SQLGlot handles the conversion.

**Formatting flexibility:** trailing commas, extra whitespace, minor formatting differences: SQLGlot normalizes them all. Write SQL however you like, and Vulcan makes it consistent.

## Macros

Standard SQL does not handle the things real pipelines need every day: date ranges that shift each run, conditional logic, repeated patterns. Macros fill that gap.

**Macro variables:** incremental models get automatic time variables. `@start_date`, `@end_date`, `@start_ds`, `@end_ds` resolve to the interval Vulcan is currently processing, so you do not hard-code dates.

**Custom macros:** Vulcan ships [its own macro syntax](../../advanced-features/macros/) and supports [Jinja](https://jinja.palletsprojects.com/en/3.1.x/). Use them for repeated CTEs, conditional joins, or any block of SQL you would otherwise copy and paste across models.

**Why bother:** the repeated SQL lives in one place. When the business rule changes, you edit one macro instead of grepping for the pattern across thirty models.

Learn more about macros in the [Macros documentation](../../advanced-features/macros/).
