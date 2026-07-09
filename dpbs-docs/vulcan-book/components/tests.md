# Tests

Tests are your safety net for data transformations. Like unit tests in software, you write tests to verify that your models transform data correctly. Tests catch problems before they reach production.

Tests are executable documentation. They show how your model should behave with specific inputs, and they fail if something changes unexpectedly. Unlike [assertions](./assertions.md) (which check data quality at runtime), tests verify the logic of your models against predefined inputs and expected outputs.

## Why testing matters

Small errors in data models can cascade into big problems downstream. Why testing is worth your time:

* **Catch breaking changes**: refactor with confidence. Tests flag unintended behavior changes.
* **Document expected behavior**: tests serve as executable specifications (better than comments that get outdated).
* **Faster debugging**: when something breaks, tests pinpoint which transformation failed.
* **Calculation correctness**: verify that aggregations, joins, and calculations produce the expected results for known inputs.
* **Confidence in changes**: make updates knowing you catch regressions before they hit production.

Tests run on demand (such as in CI/CD pipelines) or automatically when you create a new [plan](../guides/plan/plan_guide.md).

## Creating tests

Tests live in YAML files in the `tests/` folder of your project. The filename must start with `test` and end with `.yaml` or `.yml`. You can put multiple tests in one file.

At minimum, a test needs three things:

* **model**: which model you are testing.
* **inputs**: mock data for upstream dependencies (what goes in).
* **outputs**: expected results from the model's query (what should come out).

Start with a simple example.

### Your first test

Here is a model that aggregates orders by date:

```sql
MODEL (
  name sales.daily_sales,
  kind FULL,
  cron '@daily',
  grains (order_date),
  tags ('silver', 'sales', 'aggregation'),
  description 'Daily sales summary with order counts and revenue'
);

SELECT
  CAST(order_date AS TIMESTAMP) AS order_date,
  COUNT(order_id)::INTEGER AS total_orders,
  SUM(total_amount)::FLOAT AS total_revenue,
  MAX(order_id)::VARCHAR AS last_order_id
FROM raw.raw_orders
GROUP BY order_date
ORDER BY order_date
```

Write a test to verify it works correctly:

```yaml
test_daily_sales_aggregation:
  model: sales.daily_sales
  description: >
    Test that daily_sales correctly aggregates orders by date.

  inputs:
    raw.raw_orders:
      rows:
        - order_id: O001
          order_date: '2024-03-15'
          customer_id: C001
          product_id: P001
          total_amount: 50.00
        - order_id: O002
          order_date: '2024-03-15'
          customer_id: C002
          product_id: P002
          total_amount: 75.00
        - order_id: O003
          order_date: '2024-03-16'
          customer_id: C001
          product_id: P003
          total_amount: 100.00

  outputs:
    query:
      rows:
        - order_date: "2024-03-15"
          total_orders: 2
          total_revenue: 125.00
          last_order_id: "O002"
        - order_date: "2024-03-16"
          total_orders: 1
          total_revenue: 100.00
          last_order_id: "O003"
```

This test gives the model three orders (two on March 15, one on March 16) and checks that:

* Orders are correctly grouped by date
* `total_orders` counts distinct orders per day (should be 2 for March 15, 1 for March 16)
* `total_revenue` sums the amounts correctly (50 + 75 = 125 for March 15)
* `last_order_id` returns the maximum order ID per day (O002 for March 15, O003 for March 16)

If any of these expectations do not match, the test fails and tells you what went wrong.

### Testing models with multiple dependencies

Real-world models often join multiple tables. Here is how to test a more complex model that joins customers, orders, and order items:

```yaml
test_full_model_basic:
  model: vulcan_demo.full_model
  description: |
    Validates aggregates and averages:
    - DISTINCT order counting

    - SUM(quantity * unit_price)

    - avg_order_value = total_spent / total_orders, or NULL when total_orders = 0

  inputs:
    vulcan_demo.customers:
      - customer_id: 1
        name: Alice
        email: alice@example.com
      - customer_id: 2
        name: Bob
        email: bob@example.com
      - customer_id: 3
        name: Charlie
        email: charlie@example.com

    vulcan_demo.orders:
      # Alice has 2 orders
      - order_id: 1001
        customer_id: 1
      - order_id: 1002
        customer_id: 1
      # Bob has 1 order
      - order_id: 2001
        customer_id: 2
      # Charlie has 0 orders (no rows)

    vulcan_demo.order_items:
      # Order 1001: 2*50 + 1*25 = 125
      - order_id: 1001
        product_id: 501
        quantity: 2
        unit_price: 50
      - order_id: 1001
        product_id: 502
        quantity: 1
        unit_price: 25
      # Order 1002: 1*200 = 200 → Alice total = 325
      - order_id: 1002
        product_id: 503
        quantity: 1
        unit_price: 200
      # Order 2001: 2*5 = 10 → Bob total = 10
      - order_id: 2001
        product_id: 504
        quantity: 2
        unit_price: 5

  outputs:
    query:
      rows:
        - customer_id: 1
          customer_name: Alice
          email: alice@example.com
          total_orders: 2
          total_spent: 325
          avg_order_value: 162.5
        - customer_id: 2
          customer_name: Bob
          email: bob@example.com
          total_orders: 1
          total_spent: 10
          avg_order_value: 10.0
        - customer_id: 3
          customer_name: Charlie
          email: charlie@example.com
          total_orders: 0
          total_spent: 0
          avg_order_value: null  # Division by zero handled
```

The test provides mock data for all three upstream tables. It verifies that the model:

* Joins customers with orders and order items
* Counts distinct orders per customer
* Calculates total spent (quantity × unit\_price summed across all items)
* Handles division by zero (Charlie has no orders, so avg\_order\_value should be NULL)

The comments in the YAML explain the test data, which makes it easier to understand what is being tested.

### Testing incremental models

Incremental models filter data by time range. Set `start` and `end` dates using the `vars` attribute:

```yaml
test_incremental_by_time_range_basic:
  model: vulcan_demo.incremental_by_time_range
  description: |
    Validates per-(order_date, product_id) aggregates over a fixed two-day window.
    Checks DISTINCT order counts, quantity and revenue sums, and AVG(unit_price).
  vars:
    start: '2025-01-01'
    end: '2025-01-02'

  inputs:
    vulcan_demo.products:
      - product_id: 10
        name: Widget
        category: Electronics
      - product_id: 20
        name: Gizmo
        category: Home

    vulcan_demo.orders:
      - order_id: 1001
        customer_id: 9001
        warehouse_id: 1
        order_date: '2025-01-01'
      - order_id: 1002
        customer_id: 9002
        warehouse_id: 1
        order_date: '2025-01-01'
      - order_id: 1003
        customer_id: 9003
        warehouse_id: 2
        order_date: '2025-01-02'

    vulcan_demo.order_items:
      # 2025-01-01
      - order_id: 1001
        product_id: 10
        quantity: 2
        unit_price: 50
      - order_id: 1001
        product_id: 20
        quantity: 1
        unit_price: 200
      - order_id: 1002
        product_id: 10
        quantity: 1
        unit_price: 60
      # 2025-01-02
      - order_id: 1003
        product_id: 10
        quantity: 5
        unit_price: 40

  outputs:
    query:
      rows:
        - order_date: '2025-01-01'
          product_id: 20
          product_name: Gizmo
          category: Home
          order_count: 1
          total_quantity: 1
          total_sales_amount: 200
          avg_unit_price: 200
        - order_date: '2025-01-01'
          product_id: 10
          product_name: Widget
          category: Electronics
          order_count: 2
          total_quantity: 3
          total_sales_amount: 160
          avg_unit_price: 55
        - order_date: '2025-01-02'
          product_id: 10
          product_name: Widget
          category: Electronics
          order_count: 1
          total_quantity: 5
          total_sales_amount: 200
          avg_unit_price: 40
```

The `vars` section tells Vulcan what time range to use when running the model. Incremental models filter by `@start_ds` and `@end_ds` macros, and you need to control those in your test.

### Testing CTEs

You can test individual CTEs (Common Table Expressions) within your model. Use this to debug complex queries step by step.

Suppose you have a model with a CTE:

```sql
WITH filtered_orders_cte AS (
  SELECT id, item_id
  FROM vulcan_demo.incremental_model
  WHERE item_id = 1
)
SELECT
  item_id,
  COUNT(DISTINCT id) AS num_orders
FROM filtered_orders_cte
GROUP BY item_id
```

You can test both the CTE and the final query:

```yaml
test_model_with_cte:
  model: vulcan_demo.full_model
  inputs:
    vulcan_demo.incremental_model:
      rows:
        - id: 1
          item_id: 1
        - id: 2
          item_id: 1
        - id: 3
          item_id: 2
  outputs:
    ctes:
      filtered_orders_cte:
        rows:
          - id: 1
            item_id: 1
          - id: 2
            item_id: 1
    query:
      rows:
        - item_id: 1
          num_orders: 2
```

This verifies that:

1. The CTE correctly filters to `item_id = 1` (should return rows with id 1 and 2)
2. The final query correctly counts distinct orders (should be 2)

Testing CTEs separately makes it easier to pinpoint where things go wrong in complex queries.

## Supported data formats

Vulcan supports several formats for test data. Pick whichever format fits your situation:

### YAML dictionaries (default)

The most common format. List your rows as YAML dictionaries:

```yaml
inputs:
  vulcan_demo.orders:
    rows:
      - order_id: 1001
        customer_id: 1
        order_date: '2025-01-01'
```

This works well for small datasets and when you want everything in one place.

### CSV format

If you have lots of data, CSV is often easier to read and write:

```yaml
inputs:
  vulcan_demo.orders:
    format: csv
    rows: |
      order_id,customer_id,order_date
      1001,1,2025-01-01
      1002,2,2025-01-01
```

You can customize CSV parsing with `csv_settings` if you need different separators or other options.

### SQL queries

Use a SQL query when you want more control over how data is generated:

```yaml
inputs:
  vulcan_demo.orders:
    query: |
      SELECT 1001 AS order_id, 1 AS customer_id, '2025-01-01' AS order_date
      UNION ALL
      SELECT 1002 AS order_id, 2 AS customer_id, '2025-01-01' AS order_date
```

Use this when you need to generate test data programmatically or when the data structure is complex.

### External files

For large test datasets, store them in separate files:

```yaml
inputs:
  vulcan_demo.orders:
    format: csv
    path: fixtures/orders_test_data.csv
```

This keeps your test files clean and makes it easy to reuse test data across multiple tests.

## Omitting columns

For wide tables, you do not need to specify every column. Omit columns (they are treated as `NULL`) or use partial matching to only test the columns you care about:

```yaml
outputs:
  query:
    partial: true  # Only test specified columns
    rows:
      - customer_id: 1
        total_spent: 325
```

Use this when you have a table with 50 columns but only care about testing a few of them.

**Apply partial matching globally:**

```yaml
outputs:
  partial: true
  query:
    rows:
      - customer_id: 1
        total_spent: 325
```

This applies partial matching to all outputs in the test. Useful when you only test a subset of columns.

## Freezing time

If your model uses `CURRENT_TIMESTAMP` or similar functions, freeze time in your tests to make them deterministic. Otherwise, your tests fail every time you run them because the timestamp changes.

```yaml
test_with_timestamp:
  model: vulcan_demo.audit_log
  outputs:
    query:
      - event: "login"
        created_at: "2023-01-01 12:05:03"
  vars:
    execution_time: "2023-01-01 12:05:03"
```

Setting `execution_time` in `vars` makes `CURRENT_TIMESTAMP` and `CURRENT_DATE` return fixed values, so your tests are predictable and repeatable.

## Running tests

### Command line

Run tests from the command line:

```bash
# Run all tests
vulcan test

# Run specific test file
vulcan test tests/test_daily_sales.yaml

# Run specific test
vulcan test tests/test_daily_sales.yaml::test_daily_sales_aggregation

# Run tests matching a pattern
vulcan test tests/test_*
```

The `::` syntax lets you run a specific test from a file when debugging a single failing test.

### Example output

When tests pass, you see something like:

```
$ vulcan test
..
----------------------------------------------------------------------
Ran 2 tests in 0.024s

OK
```

The dots (`.`) indicate passing tests.

**When tests fail:**

```
$ vulcan test
F
======================================================================
FAIL: test_daily_sales_aggregation (tests/test_daily_sales.yaml)
----------------------------------------------------------------------
AssertionError: Data mismatch (exp: expected, act: actual)

  total_orders
         exp  act
0        3.0  2.0

----------------------------------------------------------------------
Ran 1 test in 0.012s

FAILED (failures=1)
```

The output shows what did not match. In this case, `total_orders` was expected to be 3.0 but was actually 2.0. This tells you what to investigate.

## Automatic test generation

Writing tests can be tedious, especially when you are getting started. Vulcan can generate tests automatically:

```bash
vulcan create_test vulcan_demo.daily_sales \
  --query raw.raw_orders "SELECT * FROM raw.raw_orders WHERE order_date BETWEEN '2025-01-01' AND '2025-01-02' LIMIT 10" 
```

This creates a test file with actual data from your warehouse, which makes it easy to bootstrap your test suite. You can then tweak the generated test to match your needs.

**Tip:** start with generated tests, then refine them to test edge cases and specific scenarios. This is much faster than writing everything from scratch.

## Troubleshooting

### Preserving fixtures

When a test fails, you may want to inspect the actual data that was created. Use `--preserve-fixtures` to keep test fixtures:

```bash
vulcan test --preserve-fixtures
```

Fixtures are created as views in a schema named `vulcan_test_<random_ID>`. Query these views directly to see what data was produced for debugging.

### Type mismatches

Sometimes Vulcan cannot figure out the correct types for your test data. If you see type errors, specify them explicitly:

```yaml
inputs:
  vulcan_demo.orders:
    columns:
      order_id: INT
      order_date: DATE
      total_amount: DECIMAL(10,2)
    rows:
      - order_id: 1001
        order_date: '2025-01-01'
        total_amount: 99.99
```

The `columns` section tells Vulcan what types to use, which avoids type inference issues. You can also explicitly cast columns in your model's query to help Vulcan infer types more accurately.

### Test not finding model

**Problem:** test says it cannot find the model.

**Solution:** make sure the model name in your test matches exactly what is in your `models/` folder. Model names are case-sensitive and must include the schema (such as `sales.daily_sales`, not just `daily_sales`).

### Output order matters

**Problem:** test fails even though the data looks correct.

**Solution:** the columns in your expected output must appear in the same order as the model's query selects them. Check the `SELECT` statement order and make sure your test rows match.

### Partial matching not working

**Problem:** partial matching is not ignoring extra columns.

**Solution:** set `partial: true` at the right level. It needs to be under `outputs.query` (or `outputs.ctes.<cte_name>`) for CTE-specific partial matching, or under `outputs` for global partial matching.

## Test structure reference

A complete reference of all the fields you can use in a test. Most tests only need `model`, `inputs`, and `outputs`.

### `<test_name>`

The unique name of your test. Use descriptive names that explain what you are testing, such as `test_daily_sales_aggregation` or `test_customer_revenue_calculation`.

### `<test_name>.model`

The fully qualified name of the model being tested (such as `sales.daily_sales`). This model must exist in your project's `models/` folder.

### `<test_name>.description`

An optional description that explains what the test validates. This helps your teammates (and future you) understand what the test checks.

### `<test_name>.schema`

The name of the schema that contains the test fixtures (the views created for this test). If not specified, Vulcan creates a temporary schema.

### `<test_name>.gateway`

The gateway whose `test_connection` runs this test. If not specified, the default gateway is used. Useful when you need to test against a specific database or engine.

### `<test_name>.inputs`

Mock data for upstream models that your target model depends on. If your model has no dependencies, omit this.

### `<test_name>.inputs.<upstream_model>`

A model that your target model depends on. Provide mock data for each upstream model.

### `<test_name>.inputs.<upstream_model>.rows`

The rows of test data, defined as an array of dictionaries:

```yaml
    <upstream_model>:
      rows:
        - <column_name>: <column_value>
        ...
```

**Shortcut:** If `rows` is the only key, you can omit it:

```yaml
    <upstream_model>:
      - <column_name>: <column_value>
      ...
```

### `<test_name>.inputs.<upstream_model>.format`

The format of the input data. Options: `yaml` (default) or `csv`.

```yaml
    <upstream_model>:
      format: csv
```

### `<test_name>.inputs.<upstream_model>.csv_settings`

When using CSV format, customize how the CSV is parsed:

```yaml
    <upstream_model>:
      format: csv
      csv_settings: 
        sep: "#"
        skip_blank_lines: true
      rows: |
        <column1_name>#<column2_name>
        <row1_value>#<row1_value>
```

See [pandas read\_csv documentation](https://pandas.pydata.org/docs/reference/api/pandas.read_csv.html) for all supported settings.

### `<test_name>.inputs.<upstream_model>.path`

Load data from an external file:

```yaml
    <upstream_model>:
      path: filepath/test_data.yaml
```

### `<test_name>.inputs.<upstream_model>.columns`

Specify column types explicitly to help Vulcan interpret your data correctly:

```yaml
    <upstream_model>:
      columns:
        <column_name>: <column_type>
        ...
```

This is especially useful when Vulcan cannot infer types correctly (such as with dates or decimals).

### `<test_name>.inputs.<upstream_model>.query`

Generate input data using a SQL query:

```yaml
    <upstream_model>:
      query: <sql_query>
```

**Note:** you cannot use `query` together with `rows`. Pick one or the other.

### `<test_name>.outputs`

The expected outputs from your model. This is what you assert should be true.

**Important:** column order matters. The columns in your expected rows must match the order they appear in the model's `SELECT` statement.

### `<test_name>.outputs.partial`

When `true`, only test the columns you specify. Extra columns in the output are ignored. Useful for wide tables where you only care about a few columns.

### `<test_name>.outputs.query`

The expected output of the model's final query. Optional if you test CTEs instead.

### `<test_name>.outputs.query.partial`

Same as `outputs.partial`, but applies only to the query output (not CTEs).

### `<test_name>.outputs.query.rows`

The expected rows from the model's query. Same format as input rows.

### `<test_name>.outputs.query.query`

Generate expected output using a SQL query. Useful when the expected output is complex or you want to compute it dynamically.

### `<test_name>.outputs.ctes`

Test individual CTEs within your model. Optional if you test the final query output.

### `<test_name>.outputs.ctes.<cte_name>`

The expected output of a specific CTE. Use this to test intermediate steps in complex queries.

### `<test_name>.outputs.ctes.<cte_name>.partial`

Partial matching for a specific CTE.

### `<test_name>.outputs.ctes.<cte_name>.rows`

Expected rows for a specific CTE.

### `<test_name>.outputs.ctes.<cte_name>.query`

Generate expected CTE output using a SQL query.

### `<test_name>.vars`

Set values for macro variables used in your model:

```yaml
  vars:
    start: 2022-01-01
    end: 2022-01-01
    execution_time: 2022-01-01
    <macro_variable_name>: <macro_variable_value>
```

**Special variables:**

* `start`: overrides `@start_ds` for incremental models.
* `end`: overrides `@end_ds` for incremental models.
* `execution_time`: overrides `@execution_ds` and makes `CURRENT_TIMESTAMP` and `CURRENT_DATE` return fixed values.

Use these for testing incremental models and making time-dependent tests deterministic.
