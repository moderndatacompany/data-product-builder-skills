# Variables

Macro variables are placeholders that Vulcan replaces with actual values when it renders your SQL. They make your queries dynamic: instead of hardcoding values, use variables that change based on context.

Instead of writing `WHERE date > '2023-01-01'` and updating it every day, write `WHERE date > @execution_ds` to use today's date automatically.

{% hint style="info" %}
This page covers Vulcan's built-in macro variables, the ones that come pre-configured and ready to use. To create your own custom variables, see the [Vulcan macros page](built_in.md#user-defined-variables) or [Jinja macros page](jinja.md#user-defined-variables).
{% endhint %}

## A quick example

A query that filters by date. Without macros:

```sql
SELECT *
FROM table
WHERE my_date > '2023-01-01'
```

Changing the date means editing the query. That's tedious and error-prone.

Use a macro variable to make it dynamic:

```sql
SELECT *
FROM table
WHERE my_date > @execution_ds
```

The `@` symbol tells Vulcan "this is a macro variable, replace it with a value before executing." The `@execution_ds` variable is predefined; Vulcan sets it to the date when execution started.

Run this model on February 1, 2023, and Vulcan renders it as:

```sql
SELECT *
FROM table
WHERE my_date > '2023-02-01'
```

The date updates automatically every time you run it. No manual editing.

Vulcan ships with predefined variables like this. You can also create custom variables for specific needs, covered in the macro system pages.

## Predefined variables

Vulcan provides predefined variables that are automatically available in your models. Most relate to time (dates, timestamps, and more), since time-based logic is common in data models.

The time variables follow a consistent naming pattern: a prefix (like `start`, `end`, or `execution`) plus a postfix (like `ds`, `ts`, or `epoch`) creates variables like `@start_ds` or `@execution_epoch`.

### Temporal variables

Vulcan uses Python's [datetime module](https://docs.python.org/3/library/datetime.html) under the hood and follows the standard [Unix epoch](https://en.wikipedia.org/wiki/Unix_time) (starting January 1, 1970).

{% hint style="success" %}
**Important**

All time-related predefined variables use [UTC time zone](https://en.wikipedia.org/wiki/Coordinated_Universal_Time). Handle other timezones in your query logic.

See [timezones and incremental models](../../model/model_kinds.md#timezones).
{% endhint %}

**Prefixes** indicate the time period the variable represents:

* **`start`**: the beginning of the time interval for this model run (inclusive).
* **`end`**: the end of the time interval for this model run (inclusive).
* **`execution`**: the exact timestamp when the execution started.

**Postfixes** indicate the format of the value:

* **`dt`**: a Python datetime object that becomes a SQL `TIMESTAMP`.
* **`dtntz`**: a Python datetime object that becomes a SQL `TIMESTAMP WITHOUT TIME ZONE`.
* **`date`**: a Python date object that becomes a SQL `DATE`.
* **`ds`**: a date string formatted as `'YYYY-MM-DD'` (for example, `'2023-02-01'`).
* **`ts`**: an ISO 8601 datetime string: `'YYYY-MM-DD HH:MM:SS'`.
* **`tstz`**: an ISO 8601 datetime string with timezone: `'YYYY-MM-DD HH:MM:SS+00:00'`.
* **`hour`**: an integer from 0-23 representing the hour of the day.
* **`epoch`**: an integer representing seconds since Unix epoch.
* **`millis`**: an integer representing milliseconds since Unix epoch.

All temporal variables:

**dt (datetime objects):**

* `@start_dt`
* `@end_dt`
* `@execution_dt`

**dtntz (datetime without timezone):**

* `@start_dtntz`
* `@end_dtntz`
* `@execution_dtntz`

**date (date objects):**

* `@start_date`
* `@end_date`
* `@execution_date`

**ds (date strings):**

* `@start_ds`
* `@end_ds`
* `@execution_ds`

**ts (timestamp strings):**

* `@start_ts`
* `@end_ts`
* `@execution_ts`

**tstz (timestamp strings with timezone):**

* `@start_tstz`
* `@end_tstz`
* `@execution_tstz`

**hour (hour integers):**

* `@start_hour`
* `@end_hour`
* `@execution_hour`

**epoch (Unix epoch seconds):**

* `@start_epoch`
* `@end_epoch`
* `@execution_epoch`

**millis (Unix epoch milliseconds):**

* `@start_millis`
* `@end_millis`
* `@execution_millis`

### Runtime variables

Beyond time, Vulcan provides variables that give you information about the current execution context:

*   **`@runtime_stage`**: a string indicating the current stage. Use it to conditionally run code based on whether you're creating tables, evaluating queries, or promoting views. Possible values:

    * **`'loading'`**: project is being loaded into Vulcan's runtime.
    * **`'creating'`**: model tables are being created for the first time.
    * **`'evaluating'`**: model query is being evaluated and data inserted.
    * **`'promoting'`**: model is being promoted (view created in virtual layer).
    * **`'demoting'`**: model is being demoted (view dropped from virtual layer).
    * **`'auditing'`**: an audit is being run.
    * **`'testing'`**: model is being evaluated in a unit test context.

    See [pre/post-statements](../../model/types/sql_models.md#optional-prepost-statements).
* **`@gateway`**: the name of the current [gateway](../../../configurations/#gateways) (your database connection).
* **`@this_model`**: the physical table name that the model's view selects from. Use it to create [generic assertions](../../assertions.md#generic-assertions). In [on\_virtual\_update statements](../../model/types/sql_models.md#optional-on-virtual-update-statements), it contains the qualified view name instead.
* **`@model_kind_name`**: the name of the current model kind (such as `'FULL'` or `'INCREMENTAL_BY_TIME_RANGE'`). Use it to control [physical properties in model defaults](../../../configurations/options/model_defaults.md) based on the model kind.

{% hint style="info" %}
**Embedding variables in strings**

Variables sometimes appear with curly braces like `@{variable}` instead of `@variable`. They do different things.

The curly brace syntax tells Vulcan to treat the rendered value as a SQL identifier (like a table or column name), not a string literal. If `variable` contains `foo.bar`:

* **`@variable`**: produces `foo.bar` as a literal value.
* **`@{variable}`**: produces `"foo.bar"` as an identifier, with quotes.

Use `@{variable}` to interpolate a value into an identifier name like `@{schema}_table`. Use `@variable` for plain value substitution.

See the [Vulcan macros documentation](built_in.md#embedding-variables-in-strings).
{% endhint %}

#### Before all and after all variables

These variables are available in [`before_all` and `after_all` statements](../../../configurations/options/execution_hooks.md) and in any macros called within those statements:

* **`@this_env`**: the name of the current [environment](/broken/pages/QU5rZQh0Ejzn9VWgzeyD#execution-terms).
* **`@schemas`**: a list of schema names in the [virtual layer](/broken/pages/QU5rZQh0Ejzn9VWgzeyD#execution-terms) for the current environment.
* **`@views`**: a list of view names in the [virtual layer](/broken/pages/QU5rZQh0Ejzn9VWgzeyD#execution-terms) for the current environment.

Use them for setup or cleanup operations that depend on the environment context.
