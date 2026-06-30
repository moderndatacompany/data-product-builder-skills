# Python models

Use Python models when SQL does not fit: machine learning, calling external APIs, or complex business logic that is hard to express in SQL.

Vulcan supports Python models. Your function must return a Pandas, Spark, Bigframe, or Snowpark DataFrame.

**When to use Python models:**

* Building machine learning workflows
* Integrating with external APIs
* Complex transformations that are easier in Python
* Data processing that benefits from Python libraries

{% hint style="info" %}
**Unsupported model kinds**

Python models do not support these [model kinds](../model_kinds.md). Use a SQL model instead:

```
- `VIEW` - Views need to be SQL

- `SEED` - Seed models load CSV files (SQL only)

- `MANAGED` - Managed models require SQL

- `EMBEDDED` - Embedded models inject SQL subqueries
```
{% endhint %}

## Definition

Create a Python model by adding a `.py` file to your `models/` directory and defining an `execute` function.

A basic Python model looks like this:

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
    kind=dict(
        name=ModelKindName.FULL,
    ),
    grains=["order_date"],
    depends_on=["raw.raw_orders"],
    cron='@daily',
    tags=["silver", "sales", "aggregation"],
    terms=["sales.daily_metrics", "analytics.sales_summary"],
    description="Daily sales aggregated by order_date.",
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
    """FULL model - rebuilds entire daily_sales table each run"""

    query = """
    SELECT
      CAST(order_date AS TIMESTAMP) AS order_date,
      COUNT(order_id) AS total_orders,
      SUM(total_amount) AS total_revenue,
      MAX(order_id) AS last_order_id
    FROM raw.raw_orders
    GROUP BY order_date
    ORDER BY order_date
    """

    return context.fetchdf(query)
```

**How it works:**

The `@model` decorator captures your model's metadata (like the `MODEL` DDL in SQL models). You specify column names and types in the `columns` argument. This is required because Vulcan needs to create the table before your function runs.

**Function signature:** your `execute` function receives:

* `context: ExecutionContext`: for running queries and getting time intervals
* `start`, `end`: time range for incremental models
* `execution_time`: when the model is running
* `**kwargs`: any other runtime variables

**Return types:** you can return Pandas, PySpark, Bigframe, or Snowpark DataFrames. If your output is large, you can also use Python generators to return data in chunks for memory management.

## Python dependencies

If your Python model (or engine-side UDF) needs additional Python packages, build a wheel and place it in your project under `dependencies/python/`.

See: [https://packaging.python.org/en/latest/specifications/binary-distribution-format/](https://packaging.python.org/en/latest/specifications/binary-distribution-format/)

```bash
python -m pip install -U build
python -m build
ls -1 dist/*.whl
```

Place wheels (and/or packages) at your project root under `dependencies/python/`. Nested folders under `dependencies/python/` are supported.

In standard Vulcan execution flows (for example, local Docker or cloned-project execution), drop wheels into `dependencies/python/` and import them normally in your model or UDF code.

## `@model` specification

The `@model` decorator accepts the same properties as SQL models. Use Python syntax instead of SQL DDL. `name`, `kind`, `cron`, `grains`, and the rest work the same way.

Python model `kind`s are specified with a Python dictionary containing the kind's name and arguments. All model kind arguments are listed in the [models configuration reference page](../properties.md).

```python
from vulcan import ModelKindName

@model(
    "sales.daily_sales",
    kind=dict(
        name=ModelKindName.INCREMENTAL_BY_TIME_RANGE,
        time_column="order_date",
    ),
)
```

All model kind properties are documented in the [model configuration reference](../properties.md).

Supported `kind` dictionary `name` values are:

* `ModelKindName.VIEW`
* `ModelKindName.FULL`
* `ModelKindName.SEED`
* `ModelKindName.INCREMENTAL_BY_TIME_RANGE`
* `ModelKindName.INCREMENTAL_BY_UNIQUE_KEY`
* `ModelKindName.INCREMENTAL_BY_PARTITION`
* `ModelKindName.SCD_TYPE_2_BY_TIME`
* `ModelKindName.SCD_TYPE_2_BY_COLUMN`
* `ModelKindName.EMBEDDED`
* `ModelKindName.CUSTOM`
* `ModelKindName.MANAGED`
* `ModelKindName.EXTERNAL`

## Execution context

Python models can do anything you want, but all models should be [idempotent](/broken/pages/QU5rZQh0Ejzn9VWgzeyD#execution-terms). Python models can fetch data from upstream models or data outside of Vulcan.

**Fetching data:** use `context.fetchdf()` to run SQL queries and get DataFrames:

```python
df = context.fetchdf("SELECT * FROM vulcan_demo.products")
```

**Resolving table names:** use `context.resolve_table()` to get the correct table name for the current environment (it handles dev/prod prefixes automatically):

```python
table = context.resolve_table("vulcan_demo.products")
df = context.fetchdf(f"SELECT * FROM {table}")
```

**Best practice:** make your models [idempotent](/broken/pages/QU5rZQh0Ejzn9VWgzeyD#execution-terms). Running them multiple times should produce the same result. This makes debugging and restatements much easier.

```python
df = context.fetchdf("SELECT * FROM vulcan_demo.products")
```

## Optional pre/post-statements

You can run SQL commands before and after your Python model executes. Use this to set session parameters, create indexes, or run data quality checks.

**Pre-statements:** run before your `execute` function. **Post-statements:** run after your `execute` function completes.

Pass SQL strings, SQLGlot expressions, or macro calls as lists to `pre_statements` and `post_statements`.

{% hint style="warning" %}
**Concurrency**

Be careful with pre-statements that create or alter physical tables. If multiple models run concurrently, you can get conflicts. Stick to session settings, UDFs, and temporary objects in pre-statements.
{% endhint %}

**Project-level defaults:** you can define pre/post-statements in `model_defaults` for consistent behavior across all models. Default statements run first, then model-specific ones. Learn more in the [model configuration reference](../../../configurations/options/model_defaults.md).

```python
@model(
    "vulcan_demo.model_with_statements",
    kind="full",
    columns={
        "id": "int",
        "name": "text",
    },
    pre_statements=[
        "SET GLOBAL parameter = 'value';",
        exp.Cache(this=exp.table_("x"), expression=exp.select("1")),
    ],
    post_statements=["@CREATE_INDEX(@this_model, id)"],
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:

    return pd.DataFrame([
        {"id": 1, "name": "name"}
    ])

```

The previous example's `post_statements` called user-defined Vulcan macro `@CREATE_INDEX(@this_model, id)`.

We could define the `CREATE_INDEX` macro in the project's `macros` directory like this. The macro creates a table index on a single column, conditional on the [runtime stage](../../advanced-features/macros/variables.md#runtime-variables) being `creating` (table creation time).

```python
@macro()
def create_index(
    evaluator: MacroEvaluator,
    model_name: str,
    column: str,
):
    if evaluator.runtime_stage == "creating":
        return f"CREATE INDEX idx ON {model_name}({column});"
    return None
```

**Alternative approach:** instead of using the `@model` decorator's `pre_statements` and `post_statements`, you can execute SQL directly in your function using `context.engine_adapter.execute()`.

**Important:** if you want post-statements to run after your function completes, use `yield` instead of `return`. Post-statements specified after a `yield` execute after the function finishes.

This example function includes both pre- and post-statements:

```python
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:

    # pre-statement
    context.engine_adapter.execute("SET GLOBAL parameter = 'value';")

    # post-statement requires using `yield` instead of `return`
    yield pd.DataFrame([
        {"id": 1, "name": "name"}
    ])

    # post-statement
    context.engine_adapter.execute("CREATE INDEX idx ON vulcan_demo.model_with_statements (id);")
```

## Optional on-virtual-update statements

On-virtual-update statements run when views are created or updated in the virtual layer. This happens after your model's physical table is created and the view pointing to it is set up.

**Common use case:** granting permissions on views so users can query them.

You can set `on_virtual_update` in the `@model` decorator to a list of SQL strings, SQLGlot expressions, or macro calls.

**Project-level defaults:** you can define on-virtual-update statements at the project level using `model_defaults` in your configuration. These apply to all models in your project (including Python models) and merge with any model-specific statements. Default statements run first, followed by model-specific statements. Learn more in the [model configuration reference](../../../configurations/options/model_defaults.md).

```python
@model(
    "vulcan_demo.model_with_grants",
    kind="full",
    columns={
        "id": "int",
        "name": "text",
    },
    on_virtual_update=["GRANT SELECT ON VIEW @this_model TO ROLE dev_role"],
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:

    return pd.DataFrame([
        {"id": 1, "name": "name"}
    ])
```

{% hint style="info" %}
**Virtual layer resolution**

These statements run at the virtual layer, so table names resolve to view names, not physical table names. For example, in a `dev` environment, `vulcan_demo.model_with_grants` and `@this_model` resolve to `vulcan_demo__dev.model_with_grants` (the view), not the physical table.
{% endhint %}

## Dependencies

To fetch data from an upstream model, first get the table name using `context`'s `resolve_table` method. This returns the appropriate table name for the current runtime [environment](/broken/pages/QU5rZQh0Ejzn9VWgzeyD#execution-terms):

```python
table = context.resolve_table("vulcan_demo.products")
df = context.fetchdf(f"SELECT * FROM {table}")
```

The `resolve_table` method automatically adds the referenced model to the Python model's dependencies.

The only other way to set dependencies in Python models is to define them explicitly in the `@model` decorator with the keyword `depends_on`. Dependencies defined in the model decorator take precedence over any dynamic references inside the function.

```python
@model(
    "vulcan_demo.full_model_py",
    columns={
        "product_id": "int",
        "product_name": "string",
        "category": "string",
        "total_sales": "decimal(10,2)",
    },
    kind=dict(
        name=ModelKindName.FULL,
    ),
    grains=["product_id"],
    depends_on=["vulcan_demo.products", "vulcan_demo.order_items", "vulcan_demo.orders"],
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:
    # Dependencies are explicitly declared above
    query = """
    SELECT 
        p.product_id,
        p.name AS product_name,
        p.category,
        COALESCE(SUM(oi.quantity * oi.unit_price), 0) as total_sales
    FROM vulcan_demo.products p
    LEFT JOIN vulcan_demo.order_items oi ON p.product_id = oi.product_id
    LEFT JOIN vulcan_demo.orders o ON oi.order_id = o.order_id
    GROUP BY p.product_id, p.name, p.category
    ORDER BY total_sales DESC
    """
    
    return context.fetchdf(query)
```

You can use [global variables](../../../configurations/options/variables.md) or [blueprint variables](python_models.md#python-model-blueprinting) in `resolve_table` calls:

```python
@model(
    "@schema_name.test_model2",
    kind="FULL",
    columns={"id": "INT"},
)
def execute(context, **kwargs):
    table = context.resolve_table(f"{context.var('schema_name')}.test_model1")
    select_query = exp.select("*").from_(table)
    return context.fetchdf(select_query)
```

## Returning empty DataFrames

Python models cannot return empty DataFrames directly. If your model might return empty data, use `yield` instead of `return`:

**Why?** This lets Vulcan handle the empty case properly. If you `return` an empty DataFrame, Vulcan errors. If you `yield` an empty generator or conditionally yield, it works fine.

```python
@model(
    "vulcan_demo.empty_df_model"
)
def execute(
    context: ExecutionContext,
) -> pd.DataFrame:

    [...code creating df...]

    if df.empty:
        yield from ()
    else:
        yield df
```

## User-defined variables

[User-defined global variables](../../../configurations/options/variables.md) can be accessed from within the Python model with the `context.var` method.

For example, this model accesses the user-defined variables `var` and `var_with_default`. It specifies a default value of `default_value` if `variable_with_default` resolves to a missing value.

```python
@model(
    "vulcan_demo.model_with_vars",
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:
    var_value = context.var("var")
    var_with_default_value = context.var("var_with_default", "default_value")
    ...
```

Alternatively, you can access global variables via `execute` function arguments, where the name of the argument corresponds to the name of a variable key.

For example, this model specifies `my_var` as an argument to the `execute` method. The model code can reference the `my_var` object directly:

```python
@model(
    "vulcan_demo.model_with_arg_vars",
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    my_var: Optional[str] = None,
    **kwargs: t.Any,
) -> pd.DataFrame:
    my_var_plus1 = my_var + 1
    ...
```

Make sure the argument has a default value if the variable might be missing.

Arguments must be specified explicitly: variables cannot be accessed using `kwargs`.

## Python model blueprinting

Python models can serve as templates for creating multiple models. This is called blueprinting: you define one model template, and Vulcan creates multiple models from it.

**How it works:** parameterize the model name with a variable (using `@{variable}` syntax) and provide a list of mappings in `blueprints`. Vulcan creates one model for each mapping.

**Use case:** when you have similar models that differ only by a few parameters (such as different schemas, regions, or customers).

This example creates two models:

```python
import typing as t
from datetime import datetime

import pandas as pd
from vulcan import ExecutionContext, model

@model(
    "@{customer}.some_table",
    kind="FULL",
    blueprints=[
        {"customer": "customer1", "field_a": "x", "field_b": "y"},
        {"customer": "customer2", "field_a": "z", "field_b": "w"},
    ],
    columns={
        "field_a": "text",
        "field_b": "text",
        "customer": "text",
    },
)
def entrypoint(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:
    return pd.DataFrame(
        {
            "field_a": [context.blueprint_var("field_a")],
            "field_b": [context.blueprint_var("field_b")],
            "customer": [context.blueprint_var("customer")],
        }
    )
```

**Important:** notice the `@{customer}` syntax in the model name. The curly braces tell Vulcan to treat the variable value as a SQL identifier (not a string literal). Learn more about this syntax [here](../../advanced-features/macros/built_in.md#embedding-variables-in-strings).

**Dynamic blueprints:** you can generate blueprints dynamically using macros. Use this when your blueprint list comes from external sources (such as CSV files or API calls):

```python
@model(
    "@{customer}.some_table",
    blueprints="@gen_blueprints()",  # Macro generates the list
    ...
)
```

For example, the definition of `gen_blueprints` may look like this:

```python
from vulcan import macro

@macro()
def gen_blueprints(evaluator):
    return (
        "((customer := customer1, field_a := x, field_b := y),"
        " (customer := customer2, field_a := z, field_b := w))"
    )
```

It's also possible to use the `@EACH` macro, combined with a global list variable (`@values`):

```python

@model(
    "@{customer}.some_table",
    blueprints="@EACH(@values, x -> (customer := schema_@x))",
    ...
)
...
```

## Using macros in model properties

Python models support macro variables in model properties, but there is a gotcha when macros appear inside strings.

**The issue:** cron expressions often use `@` (such as `@daily`, `@hourly`), which conflicts with Vulcan's macro syntax.

**The solution:** wrap the entire expression in quotes and prefix with `@`:

```python
# Correct: Wrap the cron expression containing a macro variable
@model(
    "vulcan_demo.scheduled_model",
    cron="@'*/@{mins} * * * *'",  # Note the @'...' syntax
    ...
)

# This also works with blueprint variables
@model(
    "@{customer}.scheduled_model",
    cron="@'0 @{hour} * * *'",
    blueprints=[
        {"customer": "customer_1", "hour": 2}, # Runs at 2 AM
        {"customer": "customer_2", "hour": 8}, # Runs at 8 AM
    ],
    ...
)

```

This is necessary because cron expressions often use `@` for aliases (such as `@daily`, `@hourly`), which can conflict with Vulcan's macro syntax.

## Examples

Practical examples showing different ways to use Python models.

### Basic

A simple Python model that returns a static Pandas DataFrame. All [metadata properties](../properties.md) work the same as SQL models. Use Python syntax.

```python
import typing as t
from datetime import datetime

import pandas as pd
from sqlglot.expressions import to_column
from vulcan import ExecutionContext, model

@model(
    "vulcan_demo.basic_model",
    owner="data_team",
    cron="@daily",
    columns={
        "id": "int",
        "name": "text",
    },
    column_descriptions={
        "id": "Unique ID",
        "name": "Name corresponding to the ID",
    },
    audits=[
        ("not_null", {"columns": [to_column("id")]}),
    ],
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:

    return pd.DataFrame([
        {"id": 1, "name": "name"}
    ])
```

### SQL query and Pandas

A more realistic example: query upstream models, do some pandas processing, and return the result. This shows how to use Python models in practice:

```python
import typing as t
from datetime import datetime

import pandas as pd
from vulcan import ExecutionContext, model

@model(
    "vulcan_demo.sql_pandas_model",
    columns={
        "product_id": "int",
        "product_name": "text",
        "total_sales": "decimal(10,2)",
    },
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:
    # get the upstream model's name and register it as a dependency
    products_table = context.resolve_table("vulcan_demo.products")
    order_items_table = context.resolve_table("vulcan_demo.order_items")

    # fetch data from the model as a pandas DataFrame
    df = context.fetchdf(f"""
        SELECT 
            p.product_id,
            p.name AS product_name,
            SUM(oi.quantity * oi.unit_price) as total_sales
        FROM {products_table} p
        LEFT JOIN {order_items_table} oi ON p.product_id = oi.product_id
        GROUP BY p.product_id, p.name
    """)

    # do some pandas stuff
    df['total_sales'] = df['total_sales'].fillna(0)
    return df
```

### PySpark

If you use Spark, use the PySpark DataFrame API instead of Pandas. PySpark DataFrames compute in a distributed fashion (across your Spark cluster), which is much faster for large datasets.

**Why PySpark over Pandas:** Pandas loads everything into memory on a single machine. PySpark distributes the work across your cluster, so you can handle much larger datasets.

```python
import typing as t
from datetime import datetime

import pandas as pd
from pyspark.sql import DataFrame, functions

from vulcan import ExecutionContext, model

@model(
    "vulcan_demo.pyspark_model",
    columns={
        "customer_id": "int",
        "customer_name": "text",
        "region": "text",
    },
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> DataFrame:
    # get the upstream model's name and register it as a dependency
    table = context.resolve_table("vulcan_demo.customers")

    # use the spark DataFrame api to add the region column
    df = context.spark.table(table).withColumn("region", functions.lit("North"))

    # returns the pyspark DataFrame directly, so no data is computed locally
    return df
```

### Snowpark

If you use Snowflake, use the Snowpark DataFrame API. Like PySpark, Snowpark DataFrames compute on Snowflake's servers (not locally), which is much more efficient.

**Why Snowpark over Pandas:** all computation happens in Snowflake, so you are not moving data to your local machine. Faster, cheaper, and can handle huge datasets.

```python
import typing as t
from datetime import datetime

import pandas as pd
from snowflake.snowpark.dataframe import DataFrame

from vulcan import ExecutionContext, model

@model(
    "vulcan_demo.snowpark_model",
    columns={
        "id": "int",
        "name": "text",
        "country": "text",
    },
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> DataFrame:
    # returns the snowpark DataFrame directly, so no data is computed locally
    df = context.snowpark.create_dataframe([[1, "a", "usa"], [2, "b", "cad"]], schema=["id", "name", "country"])
    df = df.filter(df.id > 1)
    return df
```

### Bigframe

If you use BigQuery, use the [Bigframe](https://cloud.google.com/bigquery/docs/use-bigquery-dataframes#pandas-examples) DataFrame API. Bigframe looks like Pandas but runs everything in BigQuery.

**Why Bigframe over Pandas:** all computation happens in BigQuery, so you get BigQuery's scale and performance. You can also use BigQuery remote functions (as in the example below) for custom Python logic.

```python
import typing as t
from datetime import datetime

from bigframes.pandas import DataFrame

from vulcan import ExecutionContext, model


def get_bucket(num: int):
    if not num:
        return "NA"
    boundary = 10
    return "at_or_above_10" if num >= boundary else "below_10"


@model(
    "vulcan_demo.bigframe_model",
    columns={
        "title": "text",
        "views": "int",
        "bucket": "text",
    },
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> DataFrame:
    # Create a remote function to be used in the Bigframe DataFrame
    remote_get_bucket = context.bigframe.remote_function([int], str)(get_bucket)

    # Returns the Bigframe DataFrame handle, no data is computed locally
    df = context.bigframe.read_gbq("bigquery-samples.wikipedia_pageviews.200809h")

    df = (
        # This runs entirely on the BigQuery engine lazily
        df[df.title.str.contains(r"[Gg]oogle")]
        .groupby(["title"], as_index=False)["views"]
        .sum(numeric_only=True)
        .sort_values("views", ascending=False)
    )

    return df.assign(bucket=df["views"].apply(remote_get_bucket))
```

### Batching

If your Python model outputs a huge DataFrame and you cannot use Spark, Bigframe, or Snowpark, batch the output using Python generators.

**The problem:** with Pandas, everything loads into memory. If your output is too large, you run out of memory.

**The solution:** use `yield` to return DataFrames in chunks. Vulcan processes them one at a time, so you never have more than one chunk in memory at once.

Here is how to do it:

```python
@model(
    "vulcan_demo.batching_model",
    columns={
        "customer_id": "int",
    },
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:
    # get the upstream model's table name
    table = context.resolve_table("vulcan_demo.customers")

    for i in range(3):
        # run 3 queries to get chunks of data and not run out of memory
        df = context.fetchdf(f"SELECT customer_id from {table} WHERE customer_id = {i}")
        yield df
```

## Serialization

Vulcan executes Python models locally (wherever Vulcan is running) using a custom serialization framework. Your Python code runs on your machine or CI/CD environment, not in the database.

**Why this matters:** you have full access to Python libraries, can make API calls, and run ML processing. The database receives only the final DataFrame.
