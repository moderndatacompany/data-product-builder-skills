# Built-in

## Macro systems: two approaches

Vulcan macros work differently than templating systems like [Jinja](https://jinja.palletsprojects.com/en/3.1.x/). Templating systems do string substitution: they scan your code, find special characters, and replace them with other text. That's it.

Templating systems are language-agnostic. They work for blog posts, HTML, SQL, and anything else. They have control flow (if-then, loops) and other features, but those exist to help substitute the right strings.

Vulcan macros are built specifically for SQL and understand what your SQL means. Instead of swapping strings, Vulcan macros analyze your SQL with the [sqlglot](https://github.com/tobymao/sqlglot) library to build a semantic representation of your query, then modify that representation. They can do things templating systems can't: distinguish a column name from a string literal, understand query structure, and more.

You can also write macro logic in Python, giving you more power than string substitution alone.

### How Vulcan macros work

This section describes what Vulcan does when it processes a macro. You don't need it to write macros, only to debug ones that aren't behaving as expected.

The key difference between Vulcan macros and templating systems is the role of string substitution. In templating systems, string substitution is the whole point.

In Vulcan, string substitution is one step toward modifying the semantic representation of the SQL query. _Vulcan macros work by building and modifying the semantic representation of the SQL query._

After processing all non-SQL text, Vulcan uses the substituted values to modify the semantic representation of the query to its final state.

Vulcan does this in 5 steps:

1. Parse the text with the appropriate sqlglot SQL dialect (e.g., Postgres, BigQuery, etc.). During the parsing, it detects the special macro symbol `@` to differentiate non-SQL from SQL text. The parser builds a semantic representation of the SQL code's structure, capturing non-SQL text as "placeholder" values to use in subsequent steps.
2. Examine the placeholder values to classify them as one of the following types:
   * Creation of user-defined macro variables with the `@DEF` operator (see more about [user-defined macro variables](built_in.md#user-defined-variables))
   * Macro variables: [Vulcan pre-defined](variables.md), [user-defined local](built_in.md#local-variables), and [user-defined global](built_in.md#global-variables)
   * Macro functions, both [Vulcan's](built_in.md#macro-operators) and [user-defined](built_in.md#user-defined-macro-functions)
3. Substitute macro variable values where they are detected. In most cases, this is direct string substitution as with a templating system.
4. Execute any macro functions and substitute the returned values.
5. Modify the semantic representation of the SQL query with the substituted variable values from (3) and functions from (4).

### Embedding variables in strings

Vulcan always incorporates macro variable values into the semantic representation of a SQL query (step 5 above). To do that, it infers the role each macro variable value plays in the query.

For context, two commonly used types of string in SQL are:

* String literals, which represent text values and are surrounded by single quotes, such as `'the_string'`
* Identifiers, which reference database objects like column, table, alias, and function names
  * They may be unquoted or quoted with double quotes, backticks, or brackets, depending on the SQL dialect

In a normal query, Vulcan can determine the role of a given string. It's harder when a macro variable is embedded directly into a string, especially in the `MODEL` block (rather than the query itself).

For example, consider a project that defines a [gateway variable](built_in.md#gateway-variables) named `gateway_var`. The project includes a model that references `@gateway_var` as part of the schema in the model's `name`, which is a SQL _identifier_.

Initial attempt:

```sql
MODEL (
  name the_@gateway_var_schema.table
);
```

From Vulcan's perspective, the model schema is the combination of 3 sub-strings: `the_`, the value of `@gateway_var`, and `_schema`.

Vulcan concatenates those strings, but it doesn't have the context to know it's building a SQL identifier, so it returns a string literal.

Add curly braces to the macro variable reference (`@{gateway_var}` instead of `@gateway_var`) to give Vulcan that context:

```sql
MODEL (
  name the_@{gateway_var}_schema.table
);
```

The curly braces tell Vulcan to treat the string as a SQL identifier and quote it based on the SQL dialect's quoting rules.

The most common use of the curly brace syntax is embedding macro variables into strings. It also distinguishes string literals from identifiers in SQL queries. For example, consider a macro variable `my_variable` whose value is `col`.

If you `SELECT` this value with regular macro syntax, it renders to a string literal:

```sql
SELECT @my_variable AS the_column; -- renders to SELECT 'col' AS the_column
```

`'col'` is surrounded by single quotes, so the SQL engine uses that string as the column's data value.

With curly braces, Vulcan treats the rendered string as an identifier:

```sql
SELECT @{my_variable} AS the_column; -- renders to SELECT col AS the_column
```

`col` is not surrounded by single quotes, so the SQL engine treats it as a reference to a column or other object named `col`.

## User-defined variables

Vulcan supports 4 kinds of user-defined macro variables: [global](built_in.md#global-variables), [gateway](built_in.md#gateway-variables), [blueprint](built_in.md#blueprint-variables), and [local](built_in.md#local-variables).

How they're organized:

* **Global and gateway variables**: defined in your project configuration file and usable in any model.
* **Blueprint and local variables**: defined in a specific model and only work in that model.

If variables share a name across levels, the most specific one wins. Local variables override blueprint or gateway variables, gateway variables override global variables, and so on. Set defaults globally and override them when needed.

### Global variables

Global variables live in your project configuration file under the [`variables` key](../../../configurations/options/variables.md). Use them for values shared across multiple models.

You can store numbers (`int`, `float`), booleans (`bool`), strings (`str`), or lists and dictionaries containing these types.

Access them in your models with `@VAR_NAME` (simple syntax) or `@VAR('var_name')` (function syntax). The function syntax accepts a default value as the second argument, useful when the variable might not be defined.

This Vulcan configuration key defines 6 variables of different data types:

{% tabs %}
{% tab title="YAML" %}
```yaml
variables:
  int_var: 1
  float_var: 2.0
  bool_var: true
  str_var: "cat"
  list_var: [1, 2, 3]
  dict_var:
    key1: 1
    key2: 2
```
{% endtab %}

{% tab title="Python" %}
```python
variables = {
    "int_var": 1,
    "float_var": 2.0,
    "bool_var": True,
    "str_var": "cat",
    "list_var": [1, 2, 3],
    "dict_var": {"key1": 1, "key2": 2},
}

config = Config(
    variables=variables,
    ... # other Config arguments
)
```
{% endtab %}
{% endtabs %}

A model definition can access the `int_var` value in a `WHERE` clause:

```sql
SELECT *
FROM table
WHERE int_variable = @INT_VAR
```

You can also access the same variable by passing the variable name into the `@VAR()` macro function. Note that the variable name is in single quotes in `@VAR('int_var')`:

```sql
SELECT *
FROM table
WHERE int_variable = @VAR('int_var')
```

Pass a default as the second argument to `@VAR()`. Vulcan uses it as a fallback when the variable isn't in the configuration file.

The `WHERE` clause renders to `WHERE some_value = 0` because no variable named `missing_var` is defined in the project configuration file:

```sql
SELECT *
FROM table
WHERE some_value = @VAR('missing_var', 0)
```

A similar API is available for [Python macro functions](built_in.md#accessing-global-variable-values) via the `evaluator.var` method and [Python models](../../model/types/python_models.md#user-defined-variables) via the `context.var` method.

### Gateway variables

Like global variables, gateway variables are defined in the project configuration file, but under a specific gateway's `variables` key:

{% tabs %}
{% tab title="YAML" %}
```yaml
gateways:
  my_gateway:
    variables:
      int_var: 1
    ...
```
{% endtab %}

{% tab title="Python" %}
```python
gateway_variables = {
  "int_var": 1
}

config = Config(
    gateways={
      "my_gateway": GatewayConfig(
        variables=gateway_variables
        ... # other GatewayConfig arguments
        ),
      }
)
```
{% endtab %}
{% endtabs %}

Access them in models the same way as [global variables](built_in.md#global-variables).

Gateway-specific variable values take precedence over variables with the same name in the root `variables` key.

### Blueprint variables

Blueprint macro variables are defined in a model. They take precedence over [global](built_in.md#global-variables) or [gateway-specific](built_in.md#gateway-variables) variables with the same name.

Define blueprint variables as a property of the `MODEL` statement. They are the mechanism for [creating model templates](../../model/types/sql_models.md):

```sql
MODEL (
  name @customer.some_table,
  kind FULL,
  blueprints (
    (customer := customer1, field_a := x, field_b := y, field_c := 'foo'),
    (customer := customer2, field_a := z, field_b := w, field_c := 'bar')
  )
);

SELECT
  @field_a,
  @{field_b} AS field_b,
  @field_c AS @{field_c}
FROM @customer.some_source

/*
When rendered for customer1.some_table:
SELECT
  x,
  y AS field_b,
  'foo' AS foo
FROM customer1.some_source

When rendered for customer2.some_table:
SELECT
  z,
  w AS field_b,
  'bar' AS bar
FROM customer2.some_source
*/
```

Note the regular `@field_a` and curly brace syntax `@{field_b}` macro variable references in the model query. Both render as identifiers. `field_c`, a string in the blueprints, renders as a string literal with regular macro syntax `@field_c`; use curly braces `@{field_c}` to render it as an identifier. See [above](built_in.md#embedding-variables-in-strings).

Access blueprint variables with the syntax shown above or with the `@BLUEPRINT_VAR()` macro function, which supports default values for undefined variables (similar to `@VAR()`).

### Local variables

Local macro variables are defined in a model. They take precedence over [global](built_in.md#global-variables), [blueprint](built_in.md#blueprint-variables), or [gateway-specific](built_in.md#gateway-variables) variables with the same name.

Define local macro variables with the `@DEF` macro operator. Set the macro variable `macro_var` to `1`:

```sql
@DEF(macro_var, 1);
```

Vulcan has 3 requirements for using the `@DEF` operator:

1. The `MODEL` statement must end with a semi-colon `;`.
2. All `@DEF` uses must come after the `MODEL` statement and before the SQL query.
3. Each `@DEF` use must end with a semi-colon `;`.

Consider the model `vulcan_example.full_model` from the [Vulcan quickstart guide](../../../guides/get-started.md):

```sql
MODEL (
  name vulcan_example.full_model,
  kind FULL,
  cron '@daily',
  assertions (assert_positive_order_ids),
);

SELECT
  item_id,
  count(distinct id) AS num_orders,
FROM
  vulcan_example.incremental_model
GROUP BY item_id
```

Extend this model with a user-defined macro variable to filter results by `item_size`:

```sql
MODEL (
  name vulcan_example.full_model,
  kind FULL,
  cron '@daily',
  assertions (assert_positive_order_ids),
); -- NOTE: semi-colon at end of MODEL statement

@DEF(size, 1); -- NOTE: semi-colon at end of @DEF operator

SELECT
  item_id,
  count(distinct id) AS num_orders,
FROM
  vulcan_example.incremental_model
WHERE
  item_size > @size -- Reference to macro variable `@size` defined above with `@DEF()`
GROUP BY item_id
```

This example defines the macro variable `size` with `@DEF(size, 1)`. When the model runs, Vulcan substitutes `1` where `@size` appears in the `WHERE` clause.

### Macro functions

Vulcan also supports inline macro functions. They express more readable and reusable logic than variables alone:

```sql
MODEL(...);

@DEF(
  rank_to_int,
  x -> case when left(x, 1) = 'A' then 1 when left(x, 1) = 'B' then 2 when left(x, 1) = 'C' then 3 end
);

SELECT
  id,
  cust_rank_1,
  cust_rank_2,
  cust_rank_3
  @rank_to_int(cust_rank_1) as cust_rank_1_int,
  @rank_to_int(cust_rank_2) as cust_rank_2_int,
  @rank_to_int(cust_rank_3) as cust_rank_3_int
FROM
  some.model
```

Macro functions also accept multiple arguments:

```sql
@DEF(pythag, (x,y) -> sqrt(pow(x, 2) + pow(y, 2)));

SELECT
  sideA,
  sideB,
  @pythag(sideA, sideB) AS sideC
FROM
  some.triangle
```

```sql
@DEF(nrr, (starting_mrr, expansion_mrr, churned_mrr) -> (starting_mrr + expansion_mrr - churned_mrr) / starting_mrr);

SELECT
  @nrr(fy21_mrr, fy21_expansions, fy21_churns) AS fy21_net_retention_rate,
  @nrr(fy22_mrr, fy22_expansions, fy22_churns) AS fy22_net_retention_rate,
  @nrr(fy23_mrr, fy23_expansions, fy23_churns) AS fy23_net_retention_rate,
FROM
  some.revenue
```

Nest macro functions:

```sql
MODEL (
  name dummy.model,
  kind FULL
);

@DEF(area, r -> pi() * r * r);
@DEF(container_volume, (r, h) -> @area(@r) * h);

SELECT container_id, @container_volume((cont_di / 2), cont_hi) AS volume
```

## Macro operators

Vulcan's macro system ships with operators that add dynamic behavior to your models. These built-in tools adapt your SQL to different situations.

### @EACH

`@EACH` is a `for` loop for your SQL. It takes a list of items and applies a function to each one, transforming them into whatever you need.

<details>

<summary>Learn more about `for` loops and `@EACH`</summary>

Before the `@EACH` operator, dissect a `for` loop to understand its components.

A `for` loop has 2 parts: a collection of items and an action to take for each item. A `for` loop in Python:

```python
for number in [4, 5, 6]:
    print(number)
```

This loop prints each number in the brackets:

```python
4
5
6
```

The first line sets up the loop, doing 2 things:

1. Tells Python that code inside the loop refers to each item as `number`.
2. Tells Python to step through the list of items in brackets.

The second line tells Python what to do for each item. Here, it prints the item.

The loop runs once for each item in the list, substituting the item for `number` in the code. The first iteration executes `print(4)`, the second `print(5)`.

The Vulcan `@EACH` operator implements the equivalent of a `for` loop in Vulcan macros.

`@EACH` gets its name from performing an action "for each" item in the collection. It is equivalent to the Python loop above; the two loop components are specified differently.

</details>

`@EACH` takes 2 arguments: a list of items and a function definition.

```sql
@EACH([list of items], [function definition])
```

The function definition is specified inline. This example uses the identity function, returning the input unmodified:

```sql
SELECT
  @EACH([4, 5, 6], number -> number)
FROM table
```

The first argument sets up the loop: `@EACH([4, 5, 6]` tells Vulcan to step through the list of items in brackets.

The second argument `number -> number` tells Vulcan what to do for each item using an anonymous function (also called a "lambda" function). The left side of the arrow names how the code on the right refers to each item (like `name` in `for [name] in [items]` in a Python `for` loop).

The right side of the arrow specifies what to do to each item in the list. `number -> number` tells `@EACH` that for each item `number`, return that item (for example, `1`).

Vulcan macros use semantic understanding of SQL to take automatic actions based on where macro variables appear. If `@EACH` is used in the `SELECT` clause of a SQL statement:

1. It prints the item.
2. It knows fields are separated by commas in `SELECT`, so it separates the printed items with commas.

Because of the automatic print and comma-separation, the anonymous function `number -> number` tells `@EACH` to print each item `number` and separate items with commas. The output:

```sql
SELECT
  4,
  5,
  6
FROM table
```

This basic example is too simple to be useful. Many uses of `@EACH` use values as literals, identifiers, or both.

For example, a column `favorite_number` might contain values `4`, `5`, and `6`, and you want to unpack that column into 3 indicator (binary, dummy, one-hot encoded) columns. Written by hand:

```sql
SELECT
  CASE WHEN favorite_number = 4 THEN 1 ELSE 0 END as favorite_4,
  CASE WHEN favorite_number = 5 THEN 1 ELSE 0 END as favorite_5,
  CASE WHEN favorite_number = 6 THEN 1 ELSE 0 END as favorite_6
FROM table
```

In that SQL query, each number is used in 2 ways. For `4`:

1. As a literal numeric value in `favorite_number = 4`.
2. As part of a column name in `favorite_4`.

Each use is described separately.

For the literal numeric value, `@EACH` substitutes the exact value passed in the brackets, _including quotes_. A query similar to the `CASE WHEN` example above:

```sql
SELECT
  @EACH([4,5,6], x -> CASE WHEN favorite_number = x THEN 1 ELSE 0 END as column)
FROM table
```

It renders to this SQL:

```sql
SELECT
  CASE WHEN favorite_number = 4 THEN 1 ELSE 0 END AS column,
  CASE WHEN favorite_number = 5 THEN 1 ELSE 0 END AS column,
  CASE WHEN favorite_number = 6 THEN 1 ELSE 0 END AS column
FROM table
```

Note that the numbers `4`, `5`, and `6` are unquoted in _both_ the input `@EACH` array and the resulting SQL query.

Quote them in the input `@EACH` array instead:

```sql
SELECT
  @EACH(['4','5','6'], x -> CASE WHEN favorite_number = x THEN 1 ELSE 0 END as column)
FROM table
```

They render quoted in the resulting SQL query:

```sql
SELECT
  CASE WHEN favorite_number = '4' THEN 1 ELSE 0 END AS column,
  CASE WHEN favorite_number = '5' THEN 1 ELSE 0 END AS column,
  CASE WHEN favorite_number = '6' THEN 1 ELSE 0 END AS column
FROM table
```

Place the array values at the end of a column name using the Vulcan macro operator `@` inside the `@EACH` function definition:

```sql
SELECT
  @EACH(['4','5','6'], x -> CASE WHEN favorite_number = x THEN 1 ELSE 0 END as column_@x)
FROM table
```

This query renders to:

```sql
SELECT
  CASE WHEN favorite_number = '4' THEN 1 ELSE 0 END AS column_4,
  CASE WHEN favorite_number = '5' THEN 1 ELSE 0 END AS column_5,
  CASE WHEN favorite_number = '6' THEN 1 ELSE 0 END AS column_6
FROM table
```

This syntax works regardless of whether the array values are quoted or not.

{% hint style="info" %}
**Embedding macros in strings**

Place macro values at the end of a column name with `column_@x`. To put the variable anywhere else in the identifier, use curly braces `@{}`. For example: `@{x}_column` or `my_@{x}_column`.

See [above](built_in.md#embedding-variables-in-strings) for more on embedding macros in strings.
{% endhint %}

### @IF

`@IF` conditionally includes parts of your SQL based on a logical condition. It's an if-then statement for your query.

It has 3 parts:

1. A condition that evaluates to `TRUE` or `FALSE` (written in SQL).
2. What to return if the condition is `TRUE`.
3. What to return if the condition is `FALSE` (optional; if omitted and the condition is false, nothing is included).

These elements are specified as:

```sql
@IF([logical condition], [value if TRUE], [value if FALSE])
```

The value to return if the condition is `FALSE` is optional. If it's not provided and the condition is `FALSE`, the macro has no effect on the resulting query.

Write the logical condition _in SQL_. It's evaluated with [SQLGlot's](https://github.com/tobymao/sqlglot) SQL executor. Supported operators:

* **Equality**: `=` for equals, `!=` or `<>` for not equals.
* **Comparison**: `<`, `>`, `<=`, `>=`.
* **Between**: `[number] BETWEEN [low number] AND [high number]`.
* **Membership**: `[item] IN ([comma-separated list of items])`.

These conditions are all valid SQL and evaluate to `TRUE`:

* `'a' = 'a'`
* `'a' != 'b'`
* `0 < 1`
* `1 >= 1`
* `2 BETWEEN 1 AND 3`
* `'a' IN ('a', 'b')`

Use `@IF` to modify any part of a SQL query. This query conditionally includes `sensitive_col` in the results:

```sql
SELECT
  col1,
  @IF(1 > 0, sensitive_col)
FROM table
```

Because `1 > 0` evaluates to `TRUE`, the query is rendered as:

```sql
SELECT
  col1,
  sensitive_col
FROM table
```

Note that `@IF(1 > 0, sensitive_col)` doesn't include the third argument specifying a value if `FALSE`. Had the condition evaluated to `FALSE`, `@IF` would return nothing and only `col1` would be selected.

Specify `nonsensitive_col` to return if the condition evaluates to `FALSE`:

```sql
SELECT
  col1,
  @IF(1 > 2, sensitive_col, nonsensitive_col)
FROM table
```

Because `1 > 2` evaluates to `FALSE`, the query is rendered as:

```sql
SELECT
  col1,
  nonsensitive_col
FROM table
```

[Macro rendering](built_in.md#vulcan-macro-approach) happens before the `@IF` condition is evaluated. Vulcan doesn't evaluate `my_column > @my_value` until it has first substituted the number `@my_value` represents.

Your macro might do things besides returning a value, such as printing a message or executing a statement (the macro "has side effects"). Side effect code always runs during the rendering step. To prevent this, condition the side effects on the evaluation stage in your macro code.

#### Pre/post-statements

Use `@IF` to conditionally execute pre/post-statements:

```sql
@IF([logical condition], [statement to execute if TRUE]);
```

The `@IF` statement itself must end with a semi-colon, but the inner statement argument must not.

This example conditionally executes a pre/post-statement depending on the model's [runtime stage](variables.md#predefined-variables), accessed via the pre-defined macro variable `@runtime_stage`. The `@IF` post-statement runs only at model evaluation time:

```sql
MODEL (
  name vulcan_example.full_model,
  kind FULL,
  cron '@daily',
  grains (item_id),
  assertions (assert_positive_order_ids),
);

SELECT
  item_id,
  count(distinct id) AS num_orders,
FROM
  vulcan_example.incremental_model
GROUP BY item_id
ORDER BY item_id;

@IF(
  @runtime_stage = 'evaluating',
  ALTER TABLE vulcan_example.full_model ALTER item_id TYPE VARCHAR
);
```

NOTE: you can also alter a column's type when `@runtime_stage = 'creating'`, but that's only useful when the model is incremental and the alteration persists. `FULL` models are rebuilt on each evaluation, so changes made at their creation stage are overwritten each time.

### @EVAL

`@EVAL` evaluates its arguments with SQLGlot's SQL executor.

Use it to execute mathematical or other calculations in SQL code. It behaves like the first argument of the [`@IF` operator](built_in.md#if) but isn't limited to logical conditions.

A query adding 5 to a macro variable:

```sql
MODEL (
  ...
);

@DEF(x, 1);

SELECT
  @EVAL(5 + @x) as my_six
FROM table
```

After macro variable substitution, this renders as `@EVAL(5 + 1)` and evaluates to `6`. The final rendered query:

```sql
SELECT
  6 as my_six
FROM table
```

### @FILTER

`@FILTER` subsets an input array to items meeting the logical condition in the anonymous function. Its output can be consumed by other macro operators such as [`@EACH`](built_in.md#each) or [`@REDUCE`](built_in.md#reduce).

The user-specified anonymous function must evaluate to `TRUE` or `FALSE`. `@FILTER` applies the function to each item in the array and includes the item in the output array only if it meets the condition.

Write the anonymous function _in SQL_. It's evaluated with [SQLGlot's](https://github.com/tobymao/sqlglot) SQL executor and supports standard SQL equality and comparison operators. See [`@IF`](built_in.md#if) above for supported operators.

A `@FILTER` call:

```sql
@FILTER([1,2,3], x -> x > 1)
```

It applies the condition `x > 1` to each item in the input array `[1,2,3]` and returns `[2,3]`.

### @REDUCE

`@REDUCE` combines the items in an array.

The anonymous function specifies how items in the input array combine. Unlike `@EACH` and `@FILTER`, the anonymous function takes 2 arguments whose values are named in parentheses.

An anonymous function for `@EACH` might be `x -> x + 1`. The `x` to the left of the arrow tells Vulcan that the array items are referred to as `x` in the code to the right.

Because the `@REDUCE` anonymous function takes 2 arguments, the text to the left of the arrow must contain 2 comma-separated names in parentheses. `(x, y) -> x + y` tells Vulcan that items are referred to as `x` and `y` in the code to the right.

The anonymous function takes only 2 arguments, but the input array can contain any number of items.

Consider `(x, y) -> x + y`. Only the `y` argument corresponds to items in the array; `x` is a temporary value created when the function is evaluated.

For the call `@REDUCE([1,2,3,4], (x, y) -> x + y)`, the anonymous function is applied to the array in these steps:

1. Take the first two items in the array as `x` and `y`. Apply the function to them: `1 + 2` = `3`.
2. Take the output of step (1) as `x` and the next item in the array `3` as `y`. Apply the function to them: `3 + 3` = `6`.
3. Take the output of step (2) as `x` and the next item in the array `4` as `y`. Apply the function to them: `6 + 4` = `10`.
4. No items remain. Return value from step (3): `10`.

`@REDUCE` is almost always used with another macro operator. For example, build a `WHERE` clause from multiple column names:

```sql
SELECT
  my_column
FROM
  table
WHERE
  col1 = 1 and col2 = 1 and col3 = 1
```

Use `@EACH` to build each column's predicate (for example, `col1 = 1`) and `@REDUCE` to combine them into a single statement:

```sql
SELECT
  my_column
FROM
  table
WHERE
  @REDUCE(
    @EACH([col1, col2, col3], x -> x = 1), -- Builds each individual predicate `col1 = 1`
    (x, y) -> x AND y -- Combines individual predicates with `AND`
  )
```

### @STAR

`@STAR` returns a set of column selections in a query.

`@STAR` is named after SQL's star operator `*` but generates a set of column selections and aliases programmatically instead of selecting all available columns. A query may use more than one `@STAR` and may also include explicit column selections.

`@STAR` uses Vulcan's knowledge of each table's columns and data types to generate the column list.

If the column data types are known, the resulting query `CAST`s columns to their data type in the source table. Otherwise, the columns are listed without casting.

`@STAR` supports these arguments, in this order:

* `relation`: the relation/table whose columns are selected.
* `alias` (optional): the alias of the relation, if it has one.
* `exclude` (optional): a list of columns to exclude.
* `prefix` (optional): a string to use as a prefix for all selected column names.
* `suffix` (optional): a string to use as a suffix for all selected column names.
* `quote_identifiers` (optional): whether to quote the resulting identifiers. Defaults to true.

**NOTE**: the `exclude` argument used to be named `except_`. `except_` is still supported but discouraged. It will be deprecated.

Like all Vulcan macro functions, omitting an argument in `@STAR` requires passing subsequent arguments with their name and the special `:=` keyword operator. Omit the `alias` argument with `@STAR(foo, exclude := [c])`. See [below](built_in.md#positional-and-keyword-arguments) for macro function arguments.

A `@STAR` example:

```sql
SELECT
  @STAR(foo, bar, [c], 'baz_', '_qux')
FROM foo AS bar
```

The arguments to `@STAR`:

1. The name of the table `foo` (from the query's `FROM foo`).
2. The table alias `bar` (from the query's `AS bar`).
3. A list of columns to exclude, containing one column `c`.
4. A string `baz_` to use as a prefix for all column names.
5. A string `_qux` to use as a suffix for all column names.

`foo` contains 4 columns: `a` (`TEXT`), `b` (`TEXT`), `c` (`TEXT`), and `d` (`INT`). After macro expansion, with known column types the query renders to:

```sql
SELECT
  CAST("bar"."a" AS TEXT) AS "baz_a_qux",
  CAST("bar"."b" AS TEXT) AS "baz_b_qux",
  CAST("bar"."d" AS INT) AS "baz_d_qux"
FROM foo AS bar
```

Aspects of the rendered query:

* Each column is `CAST` to its data type in the table `foo` (for example, `a` to `TEXT`).
* Each column selection uses the alias `bar` (for example, `"bar"."a"`).
* Column `c` is not present because it was passed to `@STAR`'s `exclude` argument.
* Each column alias is prefixed with `baz_` and suffixed with `_qux` (for example, `"baz_a_qux"`).

A more complex example that gives different prefixes to `a` and `b` than to `d` and includes an explicit column `my_column`:

```sql
SELECT
  @STAR(foo, bar, exclude := [c, d], 'ab_pre_'),
  @STAR(foo, bar, exclude := [a, b, c], 'd_pre_'),
  my_column
FROM foo AS bar
```

As before, `foo` contains 4 columns: `a` (`TEXT`), `b` (`TEXT`), `c` (`TEXT`), and `d` (`INT`). After macro expansion, the query renders to:

```sql
SELECT
  CAST("bar"."a" AS TEXT) AS "ab_pre_a",
  CAST("bar"."b" AS TEXT) AS "ab_pre_b",
  CAST("bar"."d" AS INT) AS "d_pre_d",
  my_column
FROM foo AS bar
```

Aspects of the rendered query:

* Columns `a` and `b` have the prefix `"ab_pre_"`; column `d` has the prefix `"d_pre_"`.
* Column `c` is not present because it was passed to the `exclude` argument in both `@STAR` calls.
* `my_column` is present in the query.

### @GENERATE\_SURROGATE\_KEY

`@GENERATE_SURROGATE_KEY` generates a surrogate key from a set of columns. The surrogate key is a sequence of alphanumeric digits returned by a hash function, such as [`MD5`](https://en.wikipedia.org/wiki/MD5), on the concatenated column values.

The surrogate key is created by:

1. `CAST`ing each column's value to `TEXT` (or the SQL engine's equivalent type).
2. Replacing `NULL` values with the text `'_vulcan_surrogate_key_null_'` for each column.
3. Concatenating the column values after steps 1 and 2.
4. Applying the [`MD5()` hash function](https://en.wikipedia.org/wiki/MD5) to the concatenated value from step 3.

The query:

```sql
SELECT
  @GENERATE_SURROGATE_KEY(a, b, c) AS col
FROM foo
```

renders to:

```sql
SELECT
  MD5(
    CONCAT(
      COALESCE(CAST("a" AS TEXT), '_vulcan_surrogate_key_null_'),
      '|',
      COALESCE(CAST("b" AS TEXT), '_vulcan_surrogate_key_null_'),
      '|',
      COALESCE(CAST("c" AS TEXT), '_vulcan_surrogate_key_null_')
    )
  ) AS "col"
FROM "foo" AS "foo"
```

By default, the `MD5` function is used. Change this by setting the `hash_function` argument:

```sql
SELECT
  @GENERATE_SURROGATE_KEY(a, b, c, hash_function := 'SHA256') AS col
FROM foo
```

This query renders to:

```sql
SELECT
  SHA256(
    CONCAT(
      COALESCE(CAST("a" AS TEXT), '_vulcan_surrogate_key_null_'),
      '|',
      COALESCE(CAST("b" AS TEXT), '_vulcan_surrogate_key_null_'),
      '|',
      COALESCE(CAST("c" AS TEXT), '_vulcan_surrogate_key_null_')
    )
  ) AS "col"
FROM "foo" AS "foo"
```

### @SAFE\_ADD

`@SAFE_ADD` adds two or more operands, substituting `NULL`s with `0`s. It returns `NULL` if all operands are `NULL`.

For example, the following query:

```sql
SELECT
  @SAFE_ADD(a, b, c)
FROM foo
```

would be rendered as:

```sql
SELECT
  CASE WHEN a IS NULL AND b IS NULL AND c IS NULL THEN NULL ELSE COALESCE(a, 0) + COALESCE(b, 0) + COALESCE(c, 0) END
FROM foo
```

### @SAFE\_SUB

`@SAFE_SUB` subtracts two or more operands, substituting `NULL`s with `0`s. It returns `NULL` if all operands are `NULL`.

For example, the following query:

```sql
SELECT
  @SAFE_SUB(a, b, c)
FROM foo
```

would be rendered as:

```sql
SELECT
  CASE WHEN a IS NULL AND b IS NULL AND c IS NULL THEN NULL ELSE COALESCE(a, 0) - COALESCE(b, 0) - COALESCE(c, 0) END
FROM foo
```

### @SAFE\_DIV

`@SAFE_DIV` divides two numbers, returning `NULL` if the denominator is `0`.

For example, the following query:

```sql
SELECT
  @SAFE_DIV(a, b)
FROM foo
```

would be rendered as:

```sql
SELECT
  a / NULLIF(b, 0)
FROM foo
```

### @UNION

`@UNION` returns a `UNION` query that selects all columns with matching names and data types from the tables.

Its first argument can be a condition or the `UNION` "type". If the first argument evaluates to a boolean (`TRUE` or `FALSE`), it's treated as a condition. If the condition is `FALSE`, only the first table is returned. If `TRUE`, the union operation runs.

If the first argument isn't a boolean condition, it's treated as the `UNION` "type": either `'DISTINCT'` (removing duplicate rows) or `'ALL'` (returning all rows). Subsequent arguments are the tables to combine.

Assume that:

* `foo` is a table with 3 columns: `a` (`INT`), `b` (`TEXT`), `c` (`TEXT`).
* `bar` is a table with 3 columns: `a` (`INT`), `b` (`INT`), `c` (`TEXT`).

The expression:

```sql
@UNION('distinct', foo, bar)
```

would be rendered as:

```sql
SELECT
  CAST(a AS INT) AS a,
  CAST(c AS TEXT) AS c
FROM foo
UNION
SELECT
  CAST(a AS INT) AS a,
  CAST(c AS TEXT) AS c
FROM bar
```

If the union type is omitted, `'ALL'` is the default. So the expression:

```sql
@UNION(foo, bar)
```

would be rendered as:

```sql
SELECT
  CAST(a AS INT) AS a,
  CAST(c AS TEXT) AS c
FROM foo
UNION ALL
SELECT
  CAST(a AS INT) AS a,
  CAST(c AS TEXT) AS c
FROM bar
```

Use a condition to control whether the union happens:

```sql
@UNION(1 > 0, 'all', foo, bar)
```

This renders the same as above. If the condition is `FALSE`:

```sql
@UNION(1 > 2, 'all', foo, bar)
```

Only the first table would be selected:

```sql
SELECT
  CAST(a AS INT) AS a,
  CAST(c AS TEXT) AS c
FROM foo
```

### @HAVERSINE\_DISTANCE

`@HAVERSINE_DISTANCE` returns the [haversine distance](https://en.wikipedia.org/wiki/Haversine_formula) between two geographic points.

It supports these arguments, in this order:

* `lat1`: latitude of the first point.
* `lon1`: longitude of the first point.
* `lat2`: latitude of the second point.
* `lon2`: longitude of the second point.
* `unit` (optional): the measurement unit. Currently only `'mi'` (miles, default) and `'km'` (kilometers) are supported.

Vulcan macro operators don't accept named arguments. `@HAVERSINE_DISTANCE(lat1=lat_column)` errors.

The query:

```sql
SELECT
  @HAVERSINE_DISTANCE(driver_y, driver_x, passenger_y, passenger_x, 'mi') AS dist
FROM rides
```

would be rendered as:

```sql
SELECT
  7922 * ASIN(SQRT((POWER(SIN(RADIANS((passenger_y - driver_y) / 2)), 2)) + (COS(RADIANS(driver_y)) * COS(RADIANS(passenger_y)) * POWER(SIN(RADIANS((passenger_x - driver_x) / 2)), 2)))) * 1.0 AS dist
FROM rides
```

### @PIVOT

`@PIVOT` returns a set of columns as a result of pivoting an input column on the specified values. This operation pivots from a "long" format (multiple values in a single column) to a "wide" format (one value in each of multiple columns).

It supports these arguments, in this order:

* `column`: the column to pivot.
* `values`: the values to use for pivoting (one column is created for each value in `values`).
* `alias` (optional): whether to create aliases for the resulting columns. Defaults to true.
* `agg` (optional): the aggregation function to use. Defaults to `SUM`.
* `cmp` (optional): the comparison operator to use for comparing column values. Defaults to `=`.
* `prefix` (optional): a prefix to use for all aliases.
* `suffix` (optional): a suffix to use for all aliases.
* `then_value` (optional): the value to use if the comparison succeeds. Defaults to `1`.
* `else_value` (optional): the value to use if the comparison fails. Defaults to `0`.
* `quote` (optional): whether to quote the resulting aliases. Defaults to true.
* `distinct` (optional): whether to apply a `DISTINCT` clause for the aggregation function. Defaults to false.

Like all Vulcan macro functions, omitting an argument in `@PIVOT` requires passing subsequent arguments with their name and the special `:=` keyword operator. Omit the `agg` argument with `@PIVOT(status, ['cancelled', 'completed'], cmp := '<')`. See [below](built_in.md#positional-and-keyword-arguments) for macro function arguments.

The query:

```sql
SELECT
  date_day,
  @PIVOT(status, ['cancelled', 'completed'])
FROM rides
GROUP BY 1
```

would be rendered as:

```sql
SELECT
  date_day,
  SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS "'cancelled'",
  SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS "'completed'"
FROM rides
GROUP BY 1
```

### @DEDUPLICATE

`@DEDUPLICATE` deduplicates rows in a table based on the specified partition and order columns using a window function.

It supports these arguments, in this order:

* `relation`: the table or CTE name to deduplicate.
* `partition_by`: column names or expressions to identify a window of rows out of which to select one as the deduplicated row.
* `order_by`: a list of strings representing the ORDER BY clause. Optional. Add nulls ordering like this: `['<column_name> desc nulls last']`.

For example, the following query:

```sql
with raw_data as (
@deduplicate(my_table, [id, cast(event_date as date)], ['event_date DESC', 'status ASC'])
)

select * from raw_data
```

would be rendered as:

```sql
WITH "raw_data" AS (
  SELECT
    *
  FROM "my_table" AS "my_table"
  QUALIFY
    ROW_NUMBER() OVER (PARTITION BY "id", CAST("event_date" AS DATE) ORDER BY "event_date" DESC, "status" ASC) = 1
)
SELECT
  *
FROM "raw_data" AS "raw_data"
```

### @DATE\_SPINE

`@DATE_SPINE` returns the SQL required to build a date spine. The spine includes the start\_date (if aligned to the datepart) AND the end\_date. This differs from the [`date_spine`](https://github.com/dbt-labs/dbt-utils?tab=readme-ov-file#date_spine-source) macro in `dbt-utils`, which does NOT include the end\_date. Use it to join unique, hard-coded date ranges with other tables and views so people don't have to constantly adjust date ranges in `where` clauses across many SQL models.

It supports these arguments, in this order:

* `datepart`: the datepart to use for the date spine: day, week, month, quarter, or year.
* `start_date`: the start date for the date spine in format YYYY-MM-DD.
* `end_date`: the end date for the date spine in format YYYY-MM-DD.

For example, the following query:

```sql
WITH discount_promotion_dates AS (
  @date_spine('day', '2024-01-01', '2024-01-16')
)

SELECT * FROM discount_promotion_dates
```

would be rendered as:

```sql
WITH "discount_promotion_dates" AS (
  SELECT
    "_exploded"."date_day" AS "date_day"
  FROM UNNEST(CAST(GENERATE_SERIES(CAST('2024-01-01' AS DATE), CAST('2024-01-16' AS DATE), INTERVAL '1' DAY) AS
DATE[])) AS "_exploded"("date_day")
)
SELECT
  "discount_promotion_dates"."date_day" AS "date_day"
FROM "discount_promotion_dates" AS "discount_promotion_dates"
```

Note: this is DuckDB SQL; other dialects are transpiled accordingly.

* Recursive CTEs (common table expressions) are used for `Redshift`, `MySQL`, and `MSSQL`.
* For `MSSQL` specifically, the recursion limit is approximately 100. Add an `OPTION (MAXRECURSION 0)` clause after the date spine macro logic to remove the limit. This applies for long date ranges.

### @RESOLVE\_TEMPLATE

`@resolve_template` is a helper macro for cases where you need access to the _components_ of the physical object name. Use it for:

* Explicit control over table locations on a per-model basis for engines that decouple storage and compute (such as Athena, Trino, and Spark).
* Generating references to engine-specific metadata tables derived from the physical table name, such as the [`<table>$properties`](https://trino.io/docs/current/connector/iceberg.html#metadata-tables) metadata table in Trino.

It relies on the `@this_model` variable, so it works only during the `creating` and `evaluation` [runtime stages](variables.md#runtime-variables). Calling it during the `loading` stage is a no-op.

The `@resolve_template` macro supports these arguments:

* `template`: the string template to render into an AST node.
* `mode`: the type of SQLGlot AST node to return after rendering the template. Valid values: `literal` or `table`. Defaults to `literal`.

The `template` can contain these placeholders, which are substituted:

* `@{catalog_name}`: the name of the catalog, for example `datalake`.
* `@{schema_name}`: the name of the physical schema Vulcan uses for the model version table, for example `vulcan__landing`.
* `@{table_name}`: the name of the physical table Vulcan uses for the model version, for example `landing__customers__2517971505`.

Note the curly brace syntax `@{}` in the template placeholders. See [above](built_in.md#embedding-variables-in-strings).

Use `@resolve_template` in a `MODEL` block:

```sql
MODEL (
  name datalake.landing.customers,
  ...
  physical_properties (
    location = @resolve_template('s3://warehouse-data/@{catalog_name}/prod/@{schema_name}/@{table_name}')
  )
);
-- CREATE TABLE "datalake"."vulcan__landing"."landing__customers__2517971505" ...

-- WITH (location = 's3://warehouse-data/datalake/prod/vulcan__landing/landing__customers__2517971505')
```

And within a query, using `mode := 'table'`:

```sql
SELECT * FROM @resolve_template('@{catalog_name}.@{schema_name}.@{table_name}$properties', mode := 'table')
-- SELECT * FROM "datalake"."vulcan__landing"."landing__customers__2517971505$properties"
```

### @AND

`@AND` combines a sequence of operands using the `AND` operator, filtering out any NULL expressions.

For example, the following expression:

```sql
@AND(TRUE, NULL)
```

would be rendered as:

```sql
TRUE
```

### @OR

`@OR` combines a sequence of operands using the `OR` operator, filtering out any NULL expressions.

For example, the following expression:

```sql
@OR(TRUE, NULL)
```

would be rendered as:

```sql
TRUE
```

### SQL clause operators

Vulcan's macro system has 7 operators that correspond to different SQL clauses:

* **`@WITH`**: common table expression `WITH` clause.
* **`@JOIN`**: table `JOIN` clause(s).
* **`@WHERE`**: filtering `WHERE` clause.
* **`@GROUP_BY`**: grouping `GROUP BY` clause.
* **`@HAVING`**: group by filtering `HAVING` clause.
* **`@ORDER_BY`**: ordering `ORDER BY` clause.
* **`@LIMIT`**: limiting `LIMIT` clause.

Each operator dynamically adds the code for its corresponding clause to a model's SQL query.

#### How SQL clause operators work

SQL clause operators take a single argument that determines whether the clause is generated.

If the argument is `TRUE`, the clause code is generated; if `FALSE`, it isn't. Write the argument _in SQL_; its value is evaluated with [SQLGlot's](https://github.com/tobymao/sqlglot) SQL engine.

Each SQL clause operator may be used only once in a query. Common table expressions or subqueries may contain their own single use of the operator.

Revisit the example model from the [User-defined Variables](built_in.md#user-defined-variables) section above.

As written, the model always includes the `WHERE` clause. Make its presence dynamic with the `@WHERE` macro operator:

```sql
MODEL (
  name vulcan_example.full_model,
  kind FULL,
  cron '@daily',
  assertions (assert_positive_order_ids),
);

@DEF(size, 1);

SELECT
  item_id,
  count(distinct id) AS num_orders,
FROM
  vulcan_example.incremental_model
@WHERE(TRUE) item_id > @size
GROUP BY item_id
```

The `@WHERE` argument is `TRUE`, so the `WHERE` code is included in the rendered model:

```sql
SELECT
  item_id,
  count(distinct id) AS num_orders,
FROM
  vulcan_example.incremental_model
WHERE item_id > 1
GROUP BY item_id
```

If the `@WHERE` argument were `FALSE`, the `WHERE` clause would be omitted from the query.

These operators aren't useful with hard-coded values. Instead, the argument can be code executable by the SQLGlot SQL executor.

The `WHERE` clause is included in this query because 1 is less than 2:

```sql
MODEL (
  name vulcan_example.full_model,
  kind FULL,
  cron '@daily',
  assertions (assert_positive_order_ids),
);

@DEF(size, 1);

SELECT
  item_id,
  count(distinct id) AS num_orders,
FROM
  vulcan_example.incremental_model
@WHERE(1 < 2) item_id > @size
GROUP BY item_id
```

The operator's argument code can include macro variables.

Here, the 2 numbers being compared are defined as macro variables instead of hard-coded:

```sql
MODEL (
  name vulcan_example.full_model,
  kind FULL,
  cron '@daily',
  assertions (assert_positive_order_ids),
);

@DEF(left_number, 1);
@DEF(right_number, 2);
@DEF(size, 1);

SELECT
  item_id,
  count(distinct id) AS num_orders,
FROM
  vulcan_example.incremental_model
@WHERE(@left_number < @right_number) item_id > @size
GROUP BY item_id
```

The argument to `@WHERE` becomes "1 < 2" as in the previous hard-coded example after Vulcan substitutes the macro variables `left_number` and `right_number`.

### SQL clause operator examples

Brief examples of each SQL clause operator.

The examples use variants of this simple select statement:

```sql
SELECT *
FROM all_cities
```

#### @WITH operator

The `@WITH` operator creates [common table expressions](https://en.wikipedia.org/wiki/Hierarchical_and_recursive_queries_in_SQL#Common_table_expression), or CTEs.

CTEs typically replace derived tables (subqueries in the `FROM` clause) to make SQL code easier to read. Less commonly, recursive CTEs support analysis of hierarchical data with SQL.

```sql
@WITH(True) all_cities as (select * from city)
select *
FROM all_cities
```

renders to

```sql
WITH all_cities as (select * from city)
select *
FROM all_cities
```

#### @JOIN operator

The `@JOIN` operator specifies joins between tables or other SQL objects. It supports different join types (INNER, OUTER, CROSS, and more).

```sql
select *
FROM all_cities
LEFT OUTER @JOIN(True) country
  ON city.country = country.name
```

renders to

```sql
select *
FROM all_cities
LEFT OUTER JOIN country
  ON city.country = country.name
```

The `@JOIN` operator recognizes that `LEFT OUTER` is part of the `JOIN` specification and omits it if the `@JOIN` argument evaluates to False.

#### @WHERE operator

The `@WHERE` operator adds a filtering `WHERE` clause to the query when its argument evaluates to True.

```sql
SELECT *
FROM all_cities
@WHERE(True) city_name = 'Toronto'
```

renders to

```sql
SELECT *
FROM all_cities
WHERE city_name = 'Toronto'
```

#### @GROUP\_BY operator

```sql
SELECT *
FROM all_cities
@GROUP_BY(True) city_id
```

renders to

```sql
SELECT *
FROM all_cities
GROUP BY city_id
```

#### @HAVING operator

```sql
SELECT
count(city_pop) as population
FROM all_cities
GROUP BY city_id
@HAVING(True) population > 1000
```

renders to

```sql
SELECT
count(city_pop) as population
FROM all_cities
GROUP BY city_id
HAVING population > 1000
```

#### @ORDER\_BY operator

```sql
SELECT *
FROM all_cities
@ORDER_BY(True) city_pop
```

renders to

```sql
SELECT *
FROM all_cities
ORDER BY city_pop
```

#### @LIMIT operator

```sql
SELECT *
FROM all_cities
@LIMIT(True) 10
```

renders to

```sql
SELECT *
FROM all_cities
LIMIT 10
```

## User-defined macro functions

Macro functions let you write reusable logic to call from multiple models. Define it once and reuse it instead of copying the same code everywhere.

Vulcan supports macro functions in 2 languages:

* **SQL functions**: use the [Jinja templating system](jinja.md#user-defined-macro-functions).
* **Python functions**: use SQLGlot and give you more power for complex operations beyond what variables and operators can handle alone.

### Python macro functions

#### Setup

Python macro functions should be placed in `.py` files in the Vulcan project's `macros` directory. Multiple functions can be defined in one `.py` file, or they can be distributed across multiple files.

An empty `__init__.py` file must be present in the Vulcan project's `macros` directory. It will be created automatically when the project scaffold is created with `vulcan init`.

Each `.py` file containing a macro definition must import Vulcan's `macro` decorator with `from vulcan import macro`.

Python macros are defined as regular python functions adorned with the Vulcan `@macro()` decorator. The first argument to the function must be `evaluator`, which provides the macro evaluation context in which the macro function will run.

#### Inputs and outputs

Python macros parse all arguments passed to the macro call with SQLGlot before they are used in the function body. Therefore, unless [argument type annotations are provided](built_in.md#argument-data-types) in the function definition, the macro function code must process SQLGlot expressions and may need to extract the expression's attributes/contents for use.

Python macro functions may return values of either `string` or SQLGlot `expression` types. Vulcan will automatically parse returned strings into a SQLGlot expression after the function is executed so they can be incorporated into the model query's semantic representation.

Macro functions may [return a list of strings or expressions](built_in.md#returning-more-than-one-value) that all play the same role in the query (e.g., specifying column definitions). For example, a list containing multiple `CASE WHEN` statements would be incorporated into the query properly, but a list containing both `CASE WHEN` statements and a `WHERE` clause would not.

#### Macro function basics

This example demonstrates the core requirements for defining a python macro - it takes no user-supplied arguments and returns the string `text`.

```python
from vulcan import macro

@macro() # Note parentheses at end of `@macro()` decorator
def print_text(evaluator):
  return 'text'
```

We could use this in a Vulcan SQL model like this:

```sql
SELECT
  @print_text() as my_text
FROM table
```

After processing, it will render to this:

```sql
SELECT
  text as my_text
FROM table
```

Note that the python function returned a string `'text'`, but the rendered query uses `text` as a column name. That is due to the function's returned text being parsed as SQL code by SQLGlot and integrated into the query's semantic representation.

The rendered query will treat `text` as a string if we double-quote the single-quoted value in the function definition as `"'text'"`:

```python
from vulcan import macro

@macro()
def print_text(evaluator):
    return "'text'"
```

When run in the same model query as before, this will render to:

```sql
SELECT
  'text' as my_text
FROM table
```

#### Argument data types

Most macro functions provide arguments so users can supply custom values when the function is called. The data type of the argument plays a key role in how the macro code processes its value, and providing type annotations in the macro definition ensures that the macro code receives the data type it expects. This section provides a brief description of Vulcan macro type annotation - find additional information [below](built_in.md#typed-macros).

As [mentioned above](built_in.md#inputs-and-outputs), argument values passed to the macro call are parsed by SQLGlot before they become available to the function code. If an argument does not have a type annotation in the macro function definition, its value will always be a SQLGlot expression in the function body. Therefore, the macro function code must operate directly on the expression (and may need to extract information from it before usage).

If an argument does have a type annotation in the macro function definition, the value passed to the macro call will be coerced to that type after parsing by SQLGlot and before the values are used in the function body. Essentially, Vulcan will extract the relevant information of the annotated data type from the expression for you (if possible).

For example, this macro function determines whether an argument's value is any of the integers 1, 2, or 3:

```python
from vulcan import macro

@macro()
def arg_in_123(evaluator, my_arg):
    return my_arg in [1,2,3]
```

When this macro is called, it will return `FALSE` even if an integer was passed in the call. Consider this macro call:

```sql
SELECT
  @arg_in_123(1)
```

It returns `SELECT FALSE` because:

1. The passed value `1` is parsed by SQLGlot into a SQLGlot expression before the function code executes and
2. There is no matching SQLGlot expression in `[1,2,3]`

However, the macro will treat the argument like a normal Python function does if we annotate `my_arg` with the integer `int` type in the function definition:

```python
from vulcan import macro

@macro()
def arg_in_123(evaluator, my_arg: int): # Type annotation `my_arg: int`
    return my_arg in [1,2,3]
```

Now the macro call will return `SELECT TRUE` because the value is coerced to a Python integer before the function code executes and `1` is in `[1,2,3]`.

If an argument has a default value, the value is not parsed by SQLGlot before the function code executes. Therefore, take care to ensure that the default's data type matches that of a user-supplied argument by adding a type annotation, making the default value a SQLGlot expression, or making the default value `None`.

#### Positional and keyword arguments

In a macro call, the arguments may be provided by position if none are skipped.

For example, consider the `add_args()` function - it has three arguments with default values provided in the function definition:

```python
from vulcan import macro

@macro()
def add_args(
    evaluator,
    argument_1: int = 1,
    argument_2: int = 2,
    argument_3: int = 3
):
    return argument_1 + argument_2 + argument_3
```

An `@add_args` call providing values for all arguments accepts positional arguments like this: `@add_args(5, 6, 7)` (which returns 5 + 6 + 7 = `18`). A call omitting and using the default value for the final `argument_3` can also use positional arguments: `@add_args(5, 6)` (which returns 5 + 6 + 3 = `14`).

However, skipping an argument requires specifying the names of subsequent arguments (i.e., using "keyword arguments"). For example, skipping the second argument above by just omitting it - `@add_args(5, , 7)` - results in an error.

Unlike Python, Vulcan keyword arguments must use the special operator `:=`. To skip and use the default value for the second argument above, the call must name the third argument: `@add_args(5, argument_3 := 8)` (which returns 5 + 2 + 8 = `15`).

#### Variable-length arguments

The `add_args()` macro defined in the [previous section](built_in.md#positional-and-keyword-arguments) accepts only three arguments and requires that all three have a value. This greatly limits the macro's flexibility because users may want to add any number of values together.

The macro can be improved by allowing users to provide any number of arguments at call time. We use Python's "variable-length arguments" to accomplish this:

```python
from vulcan import macro

@macro()
def add_args(evaluator, *args: int): # Variable-length arguments of integer type `*args: int`
    return sum(args)
```

This macro can be called with one or more arguments. For example:

* `@add_args(1)` returns 1
* `@add_args(1, 2)` returns 3
* `@add_args(1, 2, 3)` returns 6

#### Returning more than one value

Macro functions are a convenient way to tidy model code by creating multiple outputs from one function call. Python macro functions do this by returning a list of strings or SQLGlot expressions.

For example, we might want to create indicator variables from the values in a string column. We can do that by passing in the name of column and a list of values for which it should create indicators, which we then interpolate into `CASE WHEN` statements.

Because Vulcan parses the input objects, they become SQLGLot expressions in the function body. Therefore, the function code **cannot** treat the input list as a regular Python list.

Two things will happen to the input Python list before the function code is executed:

1. Each of its entries will be parsed by SQLGlot. Different inputs are parsed into different SQLGlot expressions:
   * Numbers are parsed into [`Literal` expressions](https://sqlglot.com/sqlglot/expressions.html#Literal)
   * Quoted strings are parsed into [`Literal` expressions](https://sqlglot.com/sqlglot/expressions.html#Literal)
   * Unquoted strings are parsed into [`Column` expressions](https://sqlglot.com/sqlglot/expressions.html#Column)
2. The parsed entries will be contained in a SQLGlot [`Array` expression](https://sqlglot.com/sqlglot/expressions.html#Array), the SQL entity analogous to a Python list

Because the input `Array` expression named `values` is not a Python list, we cannot iterate over it directly - instead, we iterate over its `expressions` attribute with `values.expressions`:

```python
from vulcan import macro

@macro()
def make_indicators(evaluator, string_column, values):
    cases = []

    for value in values.expressions: # Iterate over `values.expressions`
        cases.append(f"CASE WHEN {string_column} = '{value}' THEN '{value}' ELSE NULL END AS {string_column}_{value}")

    return cases
```

We call this function in a model query to create `CASE WHEN` statements for the `vehicle` column values `truck` and `bus` like this:

```sql
SELECT
  @make_indicators(vehicle, [truck, bus])
FROM table
```

Which renders to:

```sql
SELECT
  CASE WHEN vehicle = 'truck' THEN 'truck' ELSE NULL END AS vehicle_truck,
  CASE WHEN vehicle = 'bus' THEN 'bus' ELSE NULL END AS vehicle_bus,
FROM table
```

Note that in the call `@make_indicators(vehicle, [truck, bus])` none of the three values is quoted.

Because they are unquoted, SQLGlot will parse them all as `Column` expressions. In the places we used single quotes when building the string (`'{value}'`), they will be single-quoted in the output. In the places we did not quote them (`{string_column} =` and `{string_column}_{value}`), they will not.

#### Accessing predefined and local variable values

[Pre-defined variables](variables.md#predefined-variables) and [user-defined local variables](built_in.md#local-variables) can be accessed within the macro's body via the `evaluator.locals` attribute.

The first argument to every macro function, the macro evaluation context `evaluator`, contains macro variable values in its `locals` attribute. `evaluator.locals` is a dictionary whose key:value pairs are macro variables names and the associated values.

For example, a function could access the predefined `execution_epoch` variable containing the epoch timestamp of when the execution started.

```python
from vulcan import macro

@macro()
def get_execution_epoch(evaluator):
    return evaluator.locals['execution_epoch']
```

The function would return the `execution_epoch` value when called in a model query:

```sql
SELECT
  @get_execution_epoch() as execution_epoch
FROM table
```

The same approach works for user-defined local macro variables, where the key `"execution_epoch"` would be replaced with the name of the user-defined variable to be accessed.

One downside of that approach to accessing user-defined local variables is that the name of the variable is hard-coded into the function. A more flexible approach is to pass the name of the local macro variable as a function argument:

```python
from vulcan import macro

@macro()
def get_macro_var(evaluator, macro_var):
    return evaluator.locals[macro_var]
```

We could define a local macro variable `my_macro_var` with a value of 1 and pass it to the `get_macro_var` function like this:

```sql
MODEL (...);

@DEF(my_macro_var, 1); -- Define local macro variable 'my_macro_var'

SELECT
  @get_macro_var('my_macro_var') as macro_var_value -- Access my_macro_var value from Python macro function
FROM table
```

The model query would render to:

```sql
SELECT
  1 as macro_var_value
FROM table
```

#### Accessing global variable values

[User-defined global variables](built_in.md#global-variables) can be accessed within the macro's body using the `evaluator.var` method.

If a global variable is not defined, the method will return a Python `None` value. You may provide a different default value as the method's second argument.

For example:

```python
from vulcan.core.macros import macro

@macro()
def some_macro(evaluator):
    var_value = evaluator.var("<var_name>") # Default value is `None`
    another_var_value = evaluator.var("<another_var_name>", "default_value") # Default value is `"default_value"`
    ...
```

#### Accessing model, physical table, and virtual layer view names

All Vulcan models have a name in their `MODEL` specification. We refer to that as the model's "unresolved" name because it may not correspond to any specific object in the SQL engine.

When Vulcan renders and executes a model, it converts the model name into three forms at different stages:

1. The _fully qualified_ name
   * If the model name is of the form `schema.table`, Vulcan determines the correct catalog and adds it, like `catalog.schema.table`
   * Vulcan quotes each component of the name using the SQL engine's quoting and case-sensitivity rules, like `"catalog"."schema"."table"`
2. The _resolved_ physical table name
   * The qualified name of the model's underlying physical table
3. The _resolved_ virtual layer view name
   * The qualified name of the model's virtual layer view in the environment where the model is being executed

You can access any of these three forms in a Python macro through properties of the `evaluation` context object.

Access the unresolved, fully-qualified name through the `this_model_fqn` property.

```python
from vulcan.core.macros import macro

@macro()
def some_macro(evaluator):
    # Example:
    # Name in model definition: landing.customers
    # Value returned here: '"datalake"."landing"."customers"'
    unresolved_model_fqn = evaluator.this_model_fqn
    ...
```

Access the resolved physical table and virtual layer view names through the `this_model` property.

The `this_model` property returns different names depending on the runtime stage:

* `promoting` runtime stage: `this_model` resolves to the virtual layer view name
  * Example
    * Model name is `db.test_model`
    * `plan` is running in the `dev` environment
    * `this_model` resolves to `"catalog"."db__dev"."test_model"` (note the `__dev` suffix in the schema name)
* All other runtime stages: `this_model` resolves to the physical table name
  * Example
    * Model name is `db.test_model`
    * `plan` is running in any environment
    * `this_model` resolves to `"catalog"."vulcan__project"."project__test_model__684351896"`

```python
from vulcan.core.macros import macro

@macro()
def some_macro(evaluator):
    if evaluator.runtime_stage == "promoting":
        # virtual layer view name '"catalog"."db__dev"."test_model"'
        resolved_name = evaluator.this_model
    else:
        # physical table name '"catalog"."vulcan__project"."project__test_model__684351896"'
        resolved_name = evaluator.this_model
    ...
```

#### Accessing model schemas

Model schemas can be accessed within a Python macro function through its evaluation context's `column_to_types()` method, if the column types can be statically determined. For instance, a schema of an [external model](../../model/types/external_models.md) can be accessed only after the `vulcan create_external_models` command has been executed.

This macro function renames the columns of an upstream model by adding a prefix to them:

```python
from sqlglot import exp
from vulcan.core.macros import macro

@macro()
def prefix_columns(evaluator, model_name, prefix: str):
    renamed_projections = []

    # The following converts `model_name`, which is a SQLGlot expression, into a lookup key,
    # assuming that it does not contain quotes. If it did, we would have to generate SQL for
    # each part of `model_name` separately and then concatenate these parts, because in that
    # case `model_name.sql()` would produce an invalid lookup key.
    model_name_sql = model_name.sql()

    for name in evaluator.columns_to_types(model_name_sql):
        new_name = prefix + name
        renamed_projections.append(exp.column(name).as_(new_name))

    return renamed_projections
```

This can then be used in a SQL model like this:

```sql
MODEL (
  name schema.child,
  kind FULL
);

SELECT
  @prefix_columns(schema.parent, 'stg_')
FROM
  schema.parent
```

Note that `columns_to_types` expects an _unquoted model name_, such as `schema.parent`. Since macro arguments without type annotations are SQLGlot expressions, the macro code must extract meaningful information from them. For instance, the lookup key in the above macro definition is extracted by generating the SQL code for `model_name` using the `sql()` method.

Accessing the schema of an upstream model can be useful for various reasons. For example:

* Renaming columns so that downstream consumers are not tightly coupled to external or source tables
* Selecting only a subset of columns that satisfy some criteria (e.g. columns whose names start with a specific prefix)
* Applying transformations to columns, such as masking PII or computing various statistics based on the column types

Using `columns_to_types`, a single macro can apply the same transformation to every column that matches some condition, so you don't end up with one near-duplicate macro per model.

Note: there may be models whose schema is not available when the project is being loaded, in which case a special placeholder column will be returned, aptly named: `__schema_unavailable_at_load__`. In some cases, the macro's implementation will need to account for this placeholder in order to avoid issues due to the schema being unavailable.

#### Accessing snapshots

After a Vulcan project has been successfully loaded, its snapshots can be accessed in Python macro functions and Python models that generate SQL through the `get_snapshot` method of `MacroEvaluator`.

This enables the inspection of physical table names or the processed intervals for certain snapshots at runtime, as shown in the example below:

```python
from vulcan.core.macros import macro

@macro()
def some_macro(evaluator):
    if evaluator.runtime_stage == "evaluating":
        # Check the intervals a snapshot has data for and alter the behavior of the macro accordingly
        intervals = evaluator.get_snapshot("some_model_name").intervals
        ...
    ...
```

#### Using SQLGlot expressions

Vulcan automatically parses strings returned by Python macro functions into [SQLGlot](https://github.com/tobymao/sqlglot) expressions so they can be incorporated into the model query's semantic representation. Functions can also return SQLGlot expressions directly.

For example, consider a macro function that uses the `BETWEEN` operator in the predicate of a `WHERE` clause. A function returning the predicate as a string might look like this, where the function arguments are substituted into a Python f-string:

```python
from vulcan import macro, SQL

@macro()
def between_where(evaluator, column_name: SQL, low_val: SQL, high_val: SQL):
    return f"{column_name} BETWEEN {low_val} AND {high_val}"
```

The function could then be called in a query:

```sql
SELECT
  a
FROM table
WHERE @between_where(a, 1, 3)
```

And it would render to:

```sql
SELECT
  a
FROM table
WHERE a BETWEEN 1 and 3
```

Alternatively, the function could return a [SQLGLot expression](https://github.com/tobymao/sqlglot/blob/main/sqlglot/expressions.py) equivalent to that string by using SQLGlot's expression methods for building semantic representations:

```python
from vulcan import macro

@macro()
def between_where(evaluator, column, low_val, high_val):
    return column.between(low_val, high_val)
```

The methods are available because the `column` argument is parsed as a SQLGlot [Column expression](https://sqlglot.com/sqlglot/expressions.html#Column) when the macro function is executed.

Column expressions are sub-classes of the [Condition class](https://sqlglot.com/sqlglot/expressions.html#Condition), so they have builder methods like [`between`](https://sqlglot.com/sqlglot/expressions.html#Condition.between) and [`like`](https://sqlglot.com/sqlglot/expressions.html#Condition.like).

#### Macro pre/post-statements

Macro functions may be used to generate pre/post-statements in a model.

By default, when you first add the pre/post-statement macro functions to a model, Vulcan will treat those models as directly modified and require a backfill in the next plan. Vulcan will also treat edits to or removals of pre/post-statement macros as a breaking change.

If your macro does not affect the data returned by a model and you do not want its addition/editing/removal to trigger a backfill, you can specify in the macro definition that it only affects the model's metadata. Vulcan will still detect changes and create new snapshots for a model when you add/edit/remove the macro, but it will not view the change as breaking and require a backfill.

Specify that a macro only affects a model's metadata by setting the `@macro()` decorator's `metadata_only` argument to `True`. For example:

```python
from vulcan import macro

@macro(metadata_only=True)
def print_message(evaluator, message):
  print(message)
```

### Typed macros

Typed macros are macros that declare their argument types using Python type hints. Without types, every argument arrives as a SQLGlot `exp.Literal` that you have to coerce by hand. With types, Vulcan does the coercion for you, and the function body works with regular `str`, `int`, `list`, and so on.

#### Why use them

1. **Less boilerplate.** No manual conversion from `exp.Literal` to `str` or `int` in every macro.
2. **Errors caught earlier.** A wrong argument type fails at parse time, with a message that points at the call site, instead of throwing somewhere deep inside the macro body.
3. **Better IDE support.** Autocomplete and inline docs show the actual parameter types, not `Any`.

#### Defining a Typed Macro

Typed macros in Vulcan use Python's type hints. Here's a simple example of a typed macro that repeats a string a given number of times:

```python
from vulcan import macro

@macro()
def repeat_string(evaluator, text: str, count: int):
    return text * count
```

This macro takes two arguments: `text` of type `str` and `count` of type `int`, and it returns a string.

Without type hints, the inputs are two SQLGlot `exp.Literal` objects you would need to manually convert to Python `str` and `int` types. With type hints, you can work with them as string and integer types directly.

Let's try to use the macro in a Vulcan model:

```sql
SELECT
  @repeat_string('Vulcan ', 3) as repeated_string
FROM some_table;
```

Unfortunately, this model generates an error when rendered:

```
Error: Invalid expression / Unexpected token. Line 1, Col: 23.
  Vulcan Vulcan Vulcan
```

Why? The macro returned `Vulcan Vulcan Vulcan` as expected, but that string is not valid SQL in the rendered query:

```sql
SELECT
  Vulcan Vulcan Vulcan as repeated_string ### invalid SQL code
FROM some_table;
```

The problem is a mismatch between our macro's Python return type `str` and the type expected by the parsed SQL query.

Recall that Vulcan macros work by modifying the query's semantic representation. In that representation, a SQLGlot string literal type is expected. Vulcan will do its best to return the type expected by the query's semantic representation, but that is not possible in all scenarios.

Therefore, we must explicitly convert the output with SQLGlot's `exp.Literal.string()` method:

```python
from vulcan import macro

@macro()
def repeat_string(evaluator, text: str, count: int):
    return exp.Literal.string(text * count)
```

Now the query will render with a valid single-quoted string literal:

```sql
SELECT
  'Vulcan Vulcan Vulcan ' AS "repeated_string"
FROM "some_table" AS "some_table"
```

Typed macros coerce the **inputs** to a macro function, but the macro code is responsible for coercing the **output** to the type expected by the query's semantic representation.

#### Supported Types

Vulcan supports common Python types for typed macros including:

* `str` -- This handles string literals and basic identifiers, but won't coerce anything more complicated.
* `int`
* `float`
* `bool`
* `datetime.datetime`
* `datetime.date`
* `SQL` -- When you want the SQL string representation of the argument that's passed in
* `list[T]` - where `T` is any supported type including sqlglot expressions
* `tuple[T]` - where `T` is any supported type including sqlglot expressions
* `T1 | T2 | ...` - where `T1`, `T2`, etc. are any supported types including sqlglot expressions

We also support SQLGlot expressions as type hints, allowing you to ensure inputs are coerced to the desired SQL AST node your intending on working with. Some useful examples include:

* `exp.Table`
* `exp.Column`
* `exp.Literal`
* `exp.Identifier`

While these might be obvious examples, you can effectively coerce an input into _any_ SQLGlot expression type, which can be useful for more complex macros. When coercing to more complex types, you will almost certainly need to pass a string literal since expression to expression coercion is limited. When a string literal is passed to a macro that hints at a SQLGlot expression, the string will be parsed using SQLGlot and coerced to the correct type. Failure to coerce to the correct type will result in the original expression being passed to the macro and a warning being logged for the user to address as-needed.

```python
@macro()
def stamped(evaluator, query: exp.Select) -> exp.Subquery:
    return query.select(exp.Literal.string(str(datetime.now())).as_("stamp")).subquery()

# Coercing to a complex node like `exp.Select` works as expected given a string literal input
# SELECT * FROM @stamped('SELECT a, b, c')
```

When coercion fails, there will always be a warning logged but we will not crash. We believe the macro system should be flexible by default, meaning the default behavior is preserved if we cannot coerce. Given that, the user can express whatever level of additional checks they want. For example, if you would like to raise an error when the coercion fails, you can use an `assert` statement. For example:

```python
@macro()
def my_macro(evaluator, table: exp.Table) -> exp.Column:
    assert isinstance(table, exp.Table)
    table.set("catalog", "dev")
    return table

# Works
# SELECT * FROM @my_macro('some.table')
# SELECT * FROM @my_macro(some.table)

# Raises an error thanks to the users inclusion of the assert, otherwise would pass through the string literal and log a warning
# SELECT * FROM @my_macro('SELECT 1 + 1')
```

In using assert this way, you still get the benefits of reducing/removing the boilerplate needed to coerce types; but you **also** get guarantees about the type of the input. This is a useful pattern and is user-defined, so you can use it as you see fit. It ultimately allows you to keep the macro definition clean and focused on the core business logic.

#### Advanced Typed Macros

You can create more complex macros using advanced Python features like generics. For example, a macro that accepts a list of integers and returns their sum:

```python
from typing import List
from vulcan import macro

@macro()
def sum_integers(evaluator, numbers: List[int]) -> int:
    return sum(numbers)
```

Usage in Vulcan:

```sql
SELECT
  @sum_integers([1, 2, 3, 4, 5]) as total
FROM some_table;
```

Generics nest and resolve recursively, so `List[Tuple[str, int]]` works the way you'd expect.

#### Summary

Typed macros catch argument-type errors at parse time instead of at runtime, and they let macro bodies use plain Python values (`str`, `int`, lists, dicts) instead of unwrapping `exp.Literal` by hand. If a macro takes a column list or a date range, type it.

## Mixing macro systems

Vulcan supports both Vulcan macros and [Jinja macros](jinja.md). Pick one system per model. Mixing them can cause confusion or break in unexpected ways. Pick the one that fits your needs and stick with it.
