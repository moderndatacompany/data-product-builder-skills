# Jinja

Vulcan supports macros from the [Jinja](https://jinja.palletsprojects.com/en/3.1.x/) templating system. If you're already familiar with Jinja from dbt or other tools, use it here.

Jinja works differently than Vulcan's native macros. Vulcan macros understand the semantic structure of your SQL; Jinja macros are pure string substitution. They assemble SQL text by replacing placeholders without building a semantic representation of the query.

{% hint style="info" %}
**dbt compatibility**

Vulcan supports the standard Jinja function library, but **not** dbt-specific functions like `{{ ref() }}`. In a dbt project using the Vulcan adapter, dbt-specific functions work there but not in native Vulcan projects.
{% endhint %}

## The basics

Jinja uses curly braces `{}` to mark macro code. The second character after the opening brace tells Jinja what to do:

- **`{{...}}` expressions**: replaced with values in your rendered SQL. Use them for variables and function calls.

- **`{%...%}` statements**: control flow and logic. Use them for `if` statements, `for` loops, and setting variables.

- **`{#...#}` comments**: stripped out and don't appear in your final SQL.

Jinja syntax isn't valid SQL, so wrap your Jinja queries in special blocks so Vulcan processes them. For queries, use `JINJA_QUERY_BEGIN; ...; JINJA_END;`:

```sql hl_lines="5 9"
MODEL (
  name vulcan_example.full_model
);

JINJA_QUERY_BEGIN;

SELECT {{ 1 + 1 }};

JINJA_END;
```

For pre/post-statements (code that runs before or after your query), use `JINJA_STATEMENT_BEGIN; ...; JINJA_END;`:

```sql
MODEL (
  name vulcan_example.full_model
);

JINJA_STATEMENT_BEGIN;
{{ pre_hook() }}
JINJA_END;

JINJA_QUERY_BEGIN;
SELECT {{ 1 + 1 }};
JINJA_END;

JINJA_STATEMENT_BEGIN;
{{ post_hook() }}
JINJA_END;
```

## Using Vulcan's predefined variables

Use any of Vulcan's [predefined macro variables](./variables.md) in your Jinja code. Some give you information about the Vulcan project (like `runtime_stage` or `this_model`); others are temporal (like `start_ds` and `execution_date` for incremental models).

Access them by putting the variable name (unquoted) inside curly braces:

```sql
JINJA_QUERY_BEGIN;

SELECT *
FROM table
WHERE time_column BETWEEN '{{ start_ds }}' and '{{ end_ds }}';

JINJA_END;
```

The single quotes around the variable references are needed because `start_ds` and `end_ds` return string values. Numeric variables like `start_epoch` don't need quotes.

One special case: the `gateway` variable is a function call, so it needs parentheses: `{{ gateway() }}` instead of `{{ gateway }}`.

## User-defined variables

Beyond predefined variables, create your own. Vulcan supports global variables (defined in your project config) and local variables (defined in a specific model).

### Global variables

Global variables are defined in your project configuration file and usable in any model. See the [Vulcan macros documentation](./built_in.md#global-variables) for setup.

Access them with the `{{ var() }}` function. Pass the variable name (in single quotes) as the first argument and an optional default value as the second:

```sql
JINJA_QUERY_BEGIN;

SELECT *
FROM table
WHERE int_variable = {{ var('int_var') }};

JINJA_END;
```

If the variable might not exist, provide a default:

```sql
JINJA_QUERY_BEGIN;

SELECT *
FROM table
WHERE some_value = {{ var('missing_var', 0) }};

JINJA_END;
```

If `missing_var` isn't defined, Vulcan uses `0` as the fallback value.

### Gateway variables

Gateway variables work like global variables but are defined in a specific gateway's configuration. They take precedence over global variables with the same name. See the [Vulcan macros documentation](./built_in.md#gateway-variables).

Access them like global variables, with `{{ var() }}`.

### Blueprint variables

Blueprint variables let you create model templates. Define them in the `MODEL` block to generate multiple models from one template:

```sql
MODEL (
  name @customer.some_table,
  kind FULL,
  blueprints (
    (customer := customer1, field_a := x, field_b := y),
    (customer := customer2, field_a := z)
  )
);

JINJA_QUERY_BEGIN;
SELECT
  {{ blueprint_var('field_a') }}
  {{ blueprint_var('field_b', 'default_b') }} AS field_b
FROM {{ blueprint_var('customer') }}.some_source
JINJA_END;
```

Use `{{ blueprint_var() }}` to access them, with an optional default value like `{{ var() }}`.

### Local variables

Define variables available only in the current model with `{% set ... %}`:

```sql
MODEL (
  name vulcan_example.full_model,
  kind FULL,
  cron '@daily',
  assertions (assert_positive_order_ids),
);

JINJA_QUERY_BEGIN;

{% set my_col = 'num_orders' %} -- Jinja definition of variable `my_col`

SELECT
  item_id,
  count(distinct id) AS {{ my_col }}, -- Reference to Jinja variable {{ my_col }}
FROM
  vulcan_example.incremental_model
GROUP BY item_id

JINJA_END;
```

The `{% set %}` statement goes after the `MODEL` block and before your SQL query.

Jinja variables can be strings, numbers, or complex data structures like lists, tuples, or dictionaries. They support Python methods, so you can call `.upper()` on strings, iterate over lists, and more.

## Control flow

Jinja provides control flow operators to make your SQL dynamic.

### For loops

For loops iterate over collections to generate repetitive SQL. They start with `{% for ... %}` and end with `{% endfor %}`.

This example creates indicator columns for different vehicle types:

```sql
JINJA_QUERY_BEGIN;

SELECT
  {% for vehicle_type in ['car', 'truck', 'bus'] %}
    CASE WHEN user_vehicle = '{{ vehicle_type }}' THEN 1 ELSE 0 END as vehicle_{{ vehicle_type }},
  {% endfor %}
FROM table

JINJA_END;
```

A few things to notice:

- The values in the list are quoted: `['car', 'truck', 'bus']`.

- When `{{ vehicle_type }}` is used in the `CASE WHEN`, it needs quotes: `'{{ vehicle_type }}'`.

- When used in an identifier name like `vehicle_{{ vehicle_type }}`, no quotes needed.

- The trailing comma after the `CASE WHEN` line is removed automatically by Vulcan's semantic understanding.

This renders to:

```sql
SELECT
  CASE WHEN user_vehicle = 'car' THEN 1 ELSE 0 END AS vehicle_car,
  CASE WHEN user_vehicle = 'truck' THEN 1 ELSE 0 END AS vehicle_truck,
  CASE WHEN user_vehicle = 'bus' THEN 1 ELSE 0 END AS vehicle_bus
FROM table
```

Define your lists separately when possible:

```sql
JINJA_QUERY_BEGIN;

{% set vehicle_types = ['car', 'truck', 'bus'] %}

SELECT
  {% for vehicle_type in vehicle_types %}
    CASE WHEN user_vehicle = '{{ vehicle_type }}' THEN 1 ELSE 0 END as vehicle_{{ vehicle_type }},
  {% endfor %}
FROM table

JINJA_END;
```

Same result, but easier to maintain.

### If statements

If statements conditionally include SQL based on a condition. They start with `{% if ... %}` and end with `{% endif %}`.

The condition must evaluate to `True` or `False`. `True`, `1 + 1 == 2`, and `'a' in ['a', 'b']` all work.

This example conditionally includes a testing column:

```sql
JINJA_QUERY_BEGIN;

{% set testing = True %}

SELECT
  normal_column,
  {% if testing %}
    testing_column
  {% endif %}
FROM table

JINJA_END;
```

Since `testing` is `True`, this renders to:

```sql
SELECT
  normal_column,
  testing_column
FROM table
```

## User-defined macro functions

Macro functions let you reuse code across multiple models. Define them in `.sql` files in your project's `macros` directory. Put multiple functions in one file or split them across files.

Define a function with `{% macro %}` and `{% endmacro %}`:

```sql
{% macro print_text() %}
text
{% endmacro %}
```

Call it in your model with `{{ print_text() }}`. It gets replaced with `text`.

Functions can take arguments:

```sql
{% macro alias(expression, alias) %}
  {{ expression }} AS {{ alias }}
{% endmacro %}
```

Use it:

```sql
JINJA_QUERY_BEGIN;

SELECT
  item_id,
  {{ alias('item_id', 'item_id2')}}
FROM table

JINJA_END;
```

This renders to:

```sql
SELECT
  item_id,
  item_id AS item_id2
FROM table
```

Even though you quoted the arguments in the function call, they're not quoted in the output. Vulcan's semantic understanding recognizes `item_id` as a column name and handles it accordingly.

To select a string literal instead of a column, use double quotes around the string in the function call:

```sql
JINJA_QUERY_BEGIN;

SELECT
  item_id,
  {{ alias("'item_id'", 'item_id2')}}
FROM table

JINJA_END;
```

This renders to:

```sql
SELECT
  item_id,
  'item_id' AS item_id2
FROM table
```

The double quotes tell Vulcan "this is a string literal, not a column name." Use `'"item_id"'` for double quotes in the output, useful for some SQL dialects.

## Mixing macro systems

Vulcan supports both Jinja and [Vulcan macros](./built_in.md). Pick one system per model. Mixing them can cause confusing behavior or errors.

Use [predefined Vulcan macro variables](./variables.md) in Jinja queries, but when passing them as arguments to a Jinja macro function, use the Jinja syntax `{{ start_ds }}` instead of the Vulcan `@start_ds` syntax. Add quotes as needed.
