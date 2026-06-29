# Custom materializations

Vulcan ships with [model kinds](../model/model_kinds.md) that cover the most common ways to evaluate and materialize transformations. Custom materializations cover the rest.

If a built-in kind doesn't fit your use case, write a custom materialization in Python to control how your models materialize.

{% hint style="warning" %}
**Advanced feature**

Custom materializations replace Vulcan's built-in DDL/DML for a model kind. Use one only after you've ruled out the standard kinds: most workloads fit `FULL`, `INCREMENTAL_BY_TIME_RANGE`, `INCREMENTAL_BY_UNIQUE_KEY`, or `INCREMENTAL_BY_PARTITION`. If a built-in kind is almost what you need, file an issue first.
{% endhint %}

## What is a materialization?

A materialization is the "how" behind model execution. When Vulcan runs a model, it has to get that data into your database. The materialization is the set of methods that execute your transformation logic and manage the resulting data.

Some materializations are straightforward. A `FULL` model kind replaces the table each time it runs, so its materialization is essentially `CREATE OR REPLACE TABLE [name] AS [your query]`.

Others are more complex. An `INCREMENTAL_BY_TIME_RANGE` model figures out which time intervals to process, queries only that data, and merges it into the existing table.

The materialization logic also varies by SQL engine. PostgreSQL doesn't support `CREATE OR REPLACE TABLE`, so `FULL` models on Postgres use `DROP` then `CREATE` instead. Vulcan handles these engine-specific details for built-in model kinds; with custom materializations, you control them.

## How custom materializations work

A custom materialization is like creating your own model kind. Define it in Python, name it, and reference that name in your model's `MODEL` block. It can accept configuration arguments from your model definition.

Every custom materialization needs:

* **Python code**: written as a Python class.
* **Base class**: must inherit from Vulcan's `CustomMaterialization` class.
* **Insert method**: implement the `insert` method at minimum.
* **Auto-loading**: Vulcan discovers materializations in your `materializations/` directory.

You can also:

* Override other methods from `MaterializableStrategy` or `EngineAdapter` classes.
* Execute arbitrary SQL through the engine adapter.
* Run Python processing with Pandas or other libraries. For most cases, put that logic in a [Python model](../model/types/python_models.md) instead.

Vulcan loads any Python files in your project's `materializations/` directory. Or, package your materialization as a [Python package](custom_materializations.md#python-packaging) and install it like any other dependency.

## Creating a custom materialization

Add a `.py` file to your project's `materializations/` folder. Vulcan imports all Python modules in this folder when your project loads, so your materializations are ready to use.

Your materialization class inherits from `CustomMaterialization` and implements at least the `insert` method.

### Simple example

A complete example with custom insert logic and logging:

```python
import typing as t
from sqlalchemy import text
from vulcan import CustomMaterialization
from vulcan import Model

class SimpleCustomMaterialization(CustomMaterialization):
    """Simple custom materialization - demonstrates custom insert logic"""
    
    NAME = "simple_custom"
    
    def insert(
        self,
        table_name: str,
        query_or_df: t.Union[str, t.Any],
        model: Model,
        is_first_insert: bool,
        render_kwargs: t.Dict[str, t.Any],
        **kwargs: t.Any,
    ) -> None:
        """Custom insert logic for tables"""
        
        print(f"Custom materialization: Processing table {table_name}")
        print(f"Model: {model.name}")
        print(f"Is first insert: {is_first_insert}")
        
        if is_first_insert:
            print("Creating table for the first time")
            # Create the table normally using the adapter
            self.adapter.create_table(
                table_name,
                columns=model.columns_to_types,
                target_columns_to_types=model.columns_to_types,
                partitioned_by=model.partitioned_by,
            )
        
        # Insert data with custom logic
        if isinstance(query_or_df, str):
            print("Executing SQL query")
            # Execute the query - Vulcan provides the INSERT INTO ... SELECT query
            self.adapter.execute(text(query_or_df))
        else:
            print("Inserting DataFrame")
            # Insert DataFrame normally - useful for Python models that return DataFrames
            self.adapter.insert_append(table_name, query_or_df)
        
        print(f"Custom materialization completed for {table_name}")
```

Breakdown:

| Component         | What it does                                                                     |
| ----------------- | -------------------------------------------------------------------------------- |
| `NAME`            | The identifier you use in your model definition (for example, `simple_custom`).  |
| `table_name`      | The target table where data is inserted.                                         |
| `query_or_df`     | A SQL query string or a DataFrame (Pandas, PySpark, Snowpark).                   |
| `model`           | The full model definition object, with access to all model properties.           |
| `is_first_insert` | `True` if this is the first time inserting data for this model version.          |
| `render_kwargs`   | Dictionary of arguments used to render the model query.                          |
| `self.adapter`    | The engine adapter: your interface to execute SQL and interact with the database.|

### Minimal example

A simple full-refresh materialization:

```python
from vulcan import CustomMaterialization
from vulcan import Model
import typing as t

class CustomFullMaterialization(CustomMaterialization):
    NAME = "my_custom_full"

    def insert(
        self,
        table_name: str,
        query_or_df: t.Any,
        model: Model,
        is_first_insert: bool,
        render_kwargs: t.Dict[str, t.Any],
        **kwargs: t.Any,
    ) -> None:
        self.adapter.replace_query(table_name, query_or_df)
```

This replaces the table contents each time the model runs, like a `FULL` model kind.

### Controlling table creation and deletion

Customize how tables and views are created and deleted by overriding the `create` and `delete` methods:

```python
from vulcan import CustomMaterialization
from vulcan import Model
import typing as t

class CustomFullMaterialization(CustomMaterialization):
    NAME = "my_custom_full"
    
    def insert(self, table_name: str, query_or_df: t.Any, model: Model, 
               is_first_insert: bool, render_kwargs: t.Dict[str, t.Any], **kwargs: t.Any) -> None:
        self.adapter.replace_query(table_name, query_or_df)

    def create(
        self,
        table_name: str,
        model: Model,
        is_table_deployable: bool,
        render_kwargs: t.Dict[str, t.Any],
        **kwargs: t.Any,
    ) -> None:
        # Custom table/view creation logic
        # Uses self.adapter methods like create_table, create_view, or ctas
        self.adapter.create_table(
            table_name,
            columns=model.columns_to_types,
            target_columns_to_types=model.columns_to_types,
        )

    def delete(self, name: str, **kwargs: t.Any) -> None:
        # Custom table/view deletion logic
        self.adapter.drop_table(name)
```

This gives you control over the lifecycle of your data objects.

## Using a custom materialization

To use the materialization, set the model's `kind` to `CUSTOM` and pass the class `NAME` as `materialization`:

{% tabs %}
{% tab title="SQL" %}
```sql
MODEL (
  name vulcan_demo.custom_model,
  kind CUSTOM (
    materialization 'simple_custom'
  ),
  grains (customer_id)
);

SELECT
  c.customer_id,
  c.name AS customer_name,
  COUNT(DISTINCT o.order_id) AS total_orders,
  COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS total_spent
FROM vulcan_demo.customers c
LEFT JOIN vulcan_demo.orders o ON c.customer_id = o.customer_id
LEFT JOIN vulcan_demo.order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.name
ORDER BY total_spent DESC
```
{% endtab %}

{% tab title="Python" %}
```python
import typing as t
import pandas as pd
from datetime import datetime
from vulcan import ExecutionContext, model
from vulcan import ModelKindName

@model(
    "vulcan_demo.custom_model_py",
    columns={
        "customer_id": "int",
        "customer_name": "string",
        "total_orders": "int",
        "total_spent": "decimal(10,2)",
    },
    kind=dict(
        name=ModelKindName.CUSTOM,
        materialization="simple_custom",
    ),
    grains=["customer_id"],
    depends_on=["vulcan_demo.customers", "vulcan_demo.orders", "vulcan_demo.order_items"],
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:
    """Python model using custom materialization with dynamic dependencies"""
    
    # Simple customer summary
    query = """
    SELECT 
        c.customer_id,
        c.name as customer_name,
        COUNT(DISTINCT o.order_id) as total_orders,
        COALESCE(SUM(oi.quantity * oi.unit_price), 0) as total_spent
    FROM vulcan_demo.customers c
    LEFT JOIN vulcan_demo.orders o ON c.customer_id = o.customer_id
    LEFT JOIN vulcan_demo.order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id, c.name
    ORDER BY total_spent DESC
    """
    
    # Execute query and return results
    return context.fetchdf(query)
```
{% endtab %}
{% endtabs %}

### Passing properties to the materialization

Pass configuration to your materialization with `materialization_properties` to customize behavior per model:

```sql
MODEL (
  name vulcan_demo.custom_model,
  kind CUSTOM (
    materialization 'simple_custom',
    materialization_properties (
      'config_key' = 'config_value',
      'batch_size' = 1000
    )
  )
);
```

Then access these properties in your materialization code via `model.custom_materialization_properties`:

```python
class SimpleCustomMaterialization(CustomMaterialization):
    NAME = "simple_custom"

    def insert(
        self,
        table_name: str,
        query_or_df: t.Any,
        model: Model,
        is_first_insert: bool,
        render_kwargs: t.Dict[str, t.Any],
        **kwargs: t.Any,
    ) -> None:
        # Access custom properties
        config_value = model.custom_materialization_properties.get("config_key")
        batch_size = model.custom_materialization_properties.get("batch_size", 500)
        
        print(f"Config value: {config_value}, Batch size: {batch_size}")
        
        # Proceed with insert logic
        self.adapter.replace_query(table_name, query_or_df)
```

This lets you build flexible materializations that adapt to different use cases.

## Extending `CustomKind`

{% hint style="warning" %}
This subclasses Vulcan internals, which means more surface area to maintain. If the standard `Materialization` subclass works, stay there. Use this only when you need to validate custom properties before any database connection.
{% endhint %}

Subclass `CustomKind` when you need to validate or coerce custom properties before Vulcan opens any database connection, or you need a property to be present (and the right type) at parse time rather than at runtime.

Create a subclass of `CustomKind` and Vulcan detects and uses it instead of the default when your project loads.

### Creating a custom kind

A custom kind that validates a `primary_key` property:

```python
import typing as t
from typing_extensions import Self
from pydantic import model_validator
from sqlglot import exp
from vulcan import CustomKind
from vulcan.utils.pydantic import list_of_fields_validator
from vulcan.utils.errors import ConfigError

class MyCustomKind(CustomKind):

    _primary_key: t.List[exp.Expression]

    @model_validator(mode="after")
    def _validate_model(self) -> Self:
        self._primary_key = list_of_fields_validator(
            self.materialization_properties.get("primary_key"),
            {"dialect": self.dialect}
        )
        if not self.primary_key:
            raise ConfigError("primary_key must be specified")
        return self

    @property
    def primary_key(self) -> t.List[exp.Expression]:
        return self._primary_key
```

### Using the custom kind in a model

Use it in your model:

```sql
MODEL (
  name vulcan_demo.my_model,
  kind CUSTOM (
    materialization 'my_custom_full',
    materialization_properties (
      primary_key = (col1, col2)
    )
  )
);
```

### Linking to your materialization

Connect your custom kind to your materialization with a generic type parameter:

```python
class CustomFullMaterialization(CustomMaterialization[MyCustomKind]):
    NAME = "my_custom_full"

    def insert(
        self,
        table_name: str,
        query_or_df: t.Any,
        model: Model,
        is_first_insert: bool,
        render_kwargs: t.Dict[str, t.Any],
        **kwargs: t.Any,
    ) -> None:
        assert isinstance(model.kind, MyCustomKind)

        self.adapter.merge(
            ...,
            unique_key=model.kind.primary_key
        )
```

When Vulcan loads your materialization, it inspects the type signature for generic parameters that subclass `CustomKind`. If it finds one, it uses your subclass when building `model.kind` instead of the default.

Two benefits:

* **Early validation**: `primary_key` validation runs at load time, not evaluation time. Issues are caught before you create a plan.
* **Type safety**: `model.kind` resolves to your custom kind object, giving you access to extra properties without additional validation.

## Sharing custom materializations

Two ways to share a materialization across projects:

### Copying files

Copy the materialization code into each project's `materializations/` directory. It works, but you have to update each copy manually when you change anything.

If you go this route, keep the materialization code in version control and set up a way to notify users when updates are available.

### Python packaging

Packaging the materialization as a Python package solves the copy-paste problem and covers the case where the scheduler (Airflow and others) runs on machines that don't have access to the project's `materializations/` directory.

Package your materialization with [setuptools entrypoints](https://packaging.python.org/en/latest/guides/creating-and-discovering-plugins/#using-package-metadata):

{% tabs %}
{% tab title="pyproject.toml" %}
```toml
[project.entry-points."vulcan.materializations"]
my_materialization = "my_package.my_materialization:CustomFullMaterialization"
```
{% endtab %}

{% tab title="setup.py" %}
```python
setup(
    ...,
    entry_points={
        "vulcan.materializations": [
            "my_materialization = my_package.my_materialization:CustomFullMaterialization",
        ],
    },
)
```
{% endtab %}
{% endtabs %}

Once the package is installed, Vulcan discovers and loads your materialization from the entrypoint list. No manual configuration needed.
