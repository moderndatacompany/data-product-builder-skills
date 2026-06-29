# Models

Work with models in Vulcan using the Orders360 example project. This guide covers how to add, edit, evaluate, and manage models with practical examples.

Models define your data transformations. They contain the SQL or Python code that transforms your data.

## Prerequisites

Before adding a model, confirm you have:

* [Created your project](get-started.md)
* [Applied your first plan](plan/plan_guide.md)
* A [dev environment](/broken/pages/QU5rZQh0Ejzn9VWgzeyD#execution-terms) for testing changes

***

## Understanding models

Models in Vulcan consist of two core components:

1. **DDL (Data Definition Language)**: the `MODEL` block that defines structure, metadata, and behavior. This is where you configure how the model works.
2. **DML (Data Manipulation Language)**: the `SELECT` query that contains transformation logic. This is where you write your SQL.

Think of the MODEL block as the configuration and the SELECT as the actual work. Together, they define what your model does and how.

### Example: daily sales model

Here's a real example from Orders360:

```sql
MODEL (
  name sales.daily_sales,
  kind FULL,
  cron '@daily',
  grains (order_date),
  tags (
    'silver',
    'sales',
    'aggregation'
  ),
  terms (
    'sales.daily_metrics',
    'analytics.sales_summary'
  ),
  description 'Daily sales summary with order counts and revenue',
  column_descriptions (
    order_date = 'Date of the sales',
    total_orders = 'Total number of orders for the day',
    total_revenue = 'Total revenue for the day',
    last_order_id = 'Last order ID processed for the day'
  ),
  column_tags (
    order_date = ('dimension', 'grain', 'date'),
    total_orders = ('measure', 'count'),
    total_revenue = ('measure', 'financial'),
    last_order_id = ('dimension', 'identifier')
  ),
  assertions (
    unique_values(columns := (order_date)),
    not_null(columns := (order_date, total_orders, total_revenue)),
    positive_values(column := total_orders),
    positive_values(column := total_revenue)
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

***

## Adding a model

Add a new model to your Orders360 project.

### Create model file

Create a new file in your `models` directory. For example, add a weekly sales aggregation:

```bash
touch models/sales/weekly_sales.sql
```

### Define the model

Edit the file and add your model definition:

```sql
MODEL (
  name sales.weekly_sales,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column order_date,
    batch_size 1
  ),
  start '2025-01-01',
  cron '@weekly',
  grains (order_date),
  tags ('silver', 'sales', 'aggregation'),
  description 'Weekly aggregated sales metrics'
);

SELECT
  DATE_TRUNC('week', order_date) AS order_date,
  COUNT(DISTINCT order_id) AS total_orders,
  SUM(total_amount) AS total_revenue,
  AVG(total_amount) AS avg_order_value
FROM sales.daily_sales
WHERE order_date BETWEEN @start_ds AND @end_ds
GROUP BY DATE_TRUNC('week', order_date)
```

### Check model status

Confirm Vulcan detects your model:

```bash
vulcan info
```

**Expected output:**

```
Connection: Connected
Models: 5
  - raw.raw_customers

  - raw.raw_orders

  - raw.raw_products

  - sales.daily_sales

  - sales.weekly_sales  ← NEW MODEL
...
```

### Apply the model

Use `vulcan plan` to apply your new model:

```bash
vulcan plan
```

**Expected output:**

```
======================================================================
Successfully Ran 2 tests against postgres
----------------------------------------------------------------------

Differences from the `prod` environment:

Models:
└── Added:
    └── sales.weekly_sales

Models needing backfill (missing dates):
└── sales.weekly_sales: 2025-01-01 - 2025-01-15

Apply - Backfill Tables [y/n]:
```

Type `y` to apply and backfill the model.

***

## Editing an existing model

Edit an existing model by modifying the file and using Vulcan's tools to preview and apply changes.

### Edit the model file

Modify `sales.daily_sales` to add a new column. Open `models/sales/daily_sales.sql`:

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
    order_date = 'Date of the sales',
    total_orders = 'Total number of orders for the day',
    total_revenue = 'Total revenue for the day',
    last_order_id = 'Last order ID processed for the day',
    avg_order_value = 'Average order value for the day'  -- NEW COLUMN DESCRIPTION
  ),
  column_tags (
    order_date = ('dimension', 'grain', 'date'),
    total_orders = ('measure', 'count'),
    total_revenue = ('measure', 'financial'),
    avg_order_value = ('measure', 'financial'),
    last_order_id = ('dimension', 'identifier')
  ),
  assertions (
    unique_values(columns := (order_date)),
    not_null(columns := (order_date, total_orders, total_revenue)),
    positive_values(column := total_orders),
    positive_values(column := total_revenue)
  )
);

SELECT
  CAST(order_date AS TIMESTAMP)::TIMESTAMP AS order_date,
  COUNT(order_id)::INTEGER AS total_orders,
  SUM(total_amount)::FLOAT AS total_revenue,
  AVG(total_amount)::FLOAT AS avg_order_value,  -- NEW COLUMN
  MAX(order_id)::VARCHAR AS last_order_id
FROM raw.raw_orders
GROUP BY order_date
ORDER BY order_date
```

### Evaluate the model (optional)

Preview the model output without materializing it:

```bash
vulcan evaluate sales.daily_sales --start=2025-01-15 --end=2025-01-15
```

**Expected output:**

```
order_date          total_orders  total_revenue  avg_order_value  last_order_id
2025-01-15 00:00:00           42         1250.50           29.77        ORD-00142
```

**What happened?**

* The `evaluate` command runs the model query without creating tables. A dry run.
* Shows the output with the new column.
* Useful for testing changes before applying them.

Use `evaluate` to test changes quickly without waiting for full materialization.

### Preview changes with plan

See what will change and how it affects downstream models:

```bash
vulcan plan dev
```

**Expected output:**

```
======================================================================
Successfully Ran 2 tests against postgres
----------------------------------------------------------------------

Differences from the `prod` environment:

Models:
└── Directly Modified:
    └── sales.daily_sales

Directly Modified: sales.daily_sales (Non-breaking)
└── Diff:
    @@ -22,6 +22,7 @@
      SELECT
        CAST(order_date AS TIMESTAMP)::TIMESTAMP AS order_date,
        COUNT(order_id)::INTEGER AS total_orders,
        SUM(total_amount)::FLOAT AS total_revenue,
    +   AVG(total_amount)::FLOAT AS avg_order_value,
        MAX(order_id)::VARCHAR AS last_order_id
      FROM raw.raw_orders

Models needing backfill (missing dates):
└── sales.daily_sales: 2025-01-01 - 2025-01-15

Apply - Backfill Tables [y/n]:
```

**Understanding the output:**

* **Non-breaking**: Vulcan detected this as non-breaking (adding a column). Adding columns is safe. Existing queries still work.
* **Diff**: shows exactly what changed. The green `+` marks an added line.
* **No downstream impact**: `sales.weekly_sales` isn't listed because it doesn't use this column yet. Downstream models don't need reprocessing.

Non-breaking changes don't cascade. You can add columns without forcing downstream models to reprocess.

### Apply the changes

Type `y` to apply the plan:

```
Apply - Backfill Tables [y/n]: y
```

**Expected output:**

```
[1/1] sales.daily_sales          [insert 2025-01-01 - 2025-01-15] 5.2s

Executing model batches ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 100.0% • 1/1 • 0:00:05

✔ Model batches executed
✔ Plan applied successfully
```

***

## Making a breaking change

Breaking changes affect downstream models. Here's how Vulcan handles this.

### Add a filter to daily sales

Edit `models/sales/daily_sales.sql` to add a WHERE clause:

```sql
SELECT
  CAST(order_date AS TIMESTAMP)::TIMESTAMP AS order_date,
  COUNT(order_id)::INTEGER AS total_orders,
  SUM(total_amount)::FLOAT AS total_revenue,
  AVG(total_amount)::FLOAT AS avg_order_value,
  MAX(order_id)::VARCHAR AS last_order_id
FROM raw.raw_orders
WHERE total_amount > 10  -- NEW FILTER: Only orders > $10
GROUP BY order_date
ORDER BY order_date
```

### Create plan

```bash
vulcan plan dev
```

**Expected output:**

```
======================================================================
Successfully Ran 2 tests against postgres
----------------------------------------------------------------------

Differences from the `prod` environment:

Models:
├── Directly Modified:
│   └── sales.daily_sales
└── Indirectly Modified:
    └── sales.weekly_sales

Directly Modified: sales.daily_sales (Breaking)
└── Diff:
    @@ -26,6 +26,7 @@
      FROM raw.raw_orders
    + WHERE total_amount > 10
      GROUP BY order_date

└── Indirectly Modified Children:
    └── sales.weekly_sales (Indirect Breaking)

Models needing backfill (missing dates):
├── sales.daily_sales: 2025-01-01 - 2025-01-15
└── sales.weekly_sales: 2025-01-01 - 2025-01-15

Apply - Backfill Tables [y/n]:
```

**Understanding breaking changes:**

* **Breaking**: adding a WHERE clause filters data, making existing data invalid.
* **Indirectly modified**: `sales.weekly_sales` depends on `daily_sales`, so it needs reprocessing with the new filtered data.
* **Cascading backfill**: both models need reprocessing. Vulcan handles this, processing upstream first.

Breaking changes are more expensive because they cascade. Confirm you need a breaking change before making one.

***

## Evaluating a model

The `evaluate` command tests models without materializing data. Use it for iteration and debugging. It shows what your model will produce without creating tables.

### Basic evaluation

```bash
vulcan evaluate sales.daily_sales --start=2025-01-15 --end=2025-01-15
```

**Expected output:**

```
order_date          total_orders  total_revenue  avg_order_value  last_order_id
2025-01-15 00:00:00           42         1250.50           29.77        ORD-00142
```

### Evaluate multiple days

```bash
vulcan evaluate sales.daily_sales --start=2025-01-10 --end=2025-01-15
```

**Expected output:**

```
order_date          total_orders  total_revenue  avg_order_value  last_order_id
2025-01-10 00:00:00           38         1120.25           29.48        ORD-00110
2025-01-11 00:00:00           45         1350.75           30.02        ORD-00111
2025-01-12 00:00:00           41         1225.50           29.89        ORD-00112
2025-01-13 00:00:00           39         1180.00           30.26        ORD-00113
2025-01-14 00:00:00           44         1320.50           30.01        ORD-00114
2025-01-15 00:00:00           42         1250.50           29.77        ORD-00142
```

### Evaluate with filters

Test your model logic with different conditions:

```bash
vulcan evaluate sales.daily_sales --start=2025-01-15 --end=2025-01-15 --where "total_amount > 50"
```

**Use cases for evaluate:**

* Test model logic before applying changes.
* Debug query issues. See what's happening with your data.
* Verify data transformations. Check aggregations, joins, etc.
* Check data quality. Spot issues before they reach production.
* Iterate quickly without materialization costs.

***

## Reverting a change

Vulcan lets you revert model changes using Virtual Updates. Revert quickly without reprocessing your data.

### Revert the change

Edit `models/sales/daily_sales.sql` to remove the WHERE clause we added:

```sql
SELECT
  CAST(order_date AS TIMESTAMP)::TIMESTAMP AS order_date,
  COUNT(order_id)::INTEGER AS total_orders,
  SUM(total_amount)::FLOAT AS total_revenue,
  AVG(total_amount)::FLOAT AS avg_order_value,
  MAX(order_id)::VARCHAR AS last_order_id
FROM raw.raw_orders
-- WHERE total_amount > 10  -- REMOVED FILTER
GROUP BY order_date
ORDER BY order_date
```

### Apply reverted plan

```bash
vulcan plan dev
```

**Expected output:**

```
======================================================================
Successfully Ran 2 tests against postgres
----------------------------------------------------------------------

Differences from the `dev` environment:

Models:
├── Directly Modified:
│   └── sales.daily_sales
└── Indirectly Modified:
    └── sales.weekly_sales

Directly Modified: sales.daily_sales (Breaking)
└── Diff:
    @@ -26,7 +26,6 @@
      FROM raw.raw_orders
    - WHERE total_amount > 10
      GROUP BY order_date

Apply - Virtual Update [y/n]: y
```

**Virtual update:**

* No backfill required. Just updates references. Vulcan changes which physical table the view points to.
* Fast operation. Completes in seconds.
* Previous data remains available.

Virtual updates work well for reverting changes. They're fast and don't require reprocessing data.

***

## Validating models

Vulcan provides multiple ways to validate your models, and checks them automatically.

### Automatic validation

Vulcan validates models when you run `plan`:

1. **Unit tests**: run to validate logic.
2. **Assertions**: execute when data is loaded to tables.
3. **Assertions**: check data quality constraints.

**Example output:**

```
======================================================================
Successfully Ran 2 tests against postgres
----------------------------------------------------------------------
```

### Manual validation options

1.  **Evaluate**: test model output without materialization.

    ```bash
    vulcan evaluate sales.daily_sales --start=2025-01-15 --end=2025-01-15
    ```
2.  **Unit tests**: write tests in `tests/` directory.

    ```bash
    vulcan test
    ```
3.  **Plan preview**: see changes before applying.

    ```bash
    vulcan plan dev
    ```

***

## Deleting a model

Remove a model from your project.

### Delete model file

```bash
rm models/sales/weekly_sales.sql
```

### Delete associated tests (if any)

```bash
rm tests/test_weekly_sales.yaml
```

### Apply deletion plan

```bash
vulcan plan dev
```

**Expected output:**

```
======================================================================
Successfully Ran 1 tests against postgres
----------------------------------------------------------------------

Differences from the `dev` environment:

Models:
└── Removed Models:
    └── sales.weekly_sales

Apply - Virtual Update [y/n]: y
```

Type `y` to apply the deletion.

**Expected output:**

```
Virtually Updating 'dev' ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 100.0% • 0:00:00

The target environment has been updated successfully
Virtual Update executed successfully
```

### Apply to production

```bash
vulcan plan
```

**Expected output:**

```
Differences from the `prod` environment:

Models:
└── Removed Models:
    └── sales.weekly_sales

Apply - Virtual Update [y/n]: y
```

***

## Model examples from Orders360

### Seed model: raw orders

```sql
MODEL (
  name raw.raw_orders,
  kind SEED (
    path '../../seeds/raw_orders.csv'
  ),
  description 'Seed model loading raw order data from CSV file',
  columns (
    order_id VARCHAR,
    order_date DATE,
    customer_id VARCHAR,
    product_id VARCHAR,
    total_amount FLOAT
  ),
  column_descriptions (
    order_id = 'Unique identifier for each order',
    order_date = 'Date when the order was placed',
    customer_id = 'Reference to customer who placed the order',
    product_id = 'Reference to product that was ordered',
    total_amount = 'Total order amount in dollars'
  ),
  assertions (
    unique_values(columns := (order_id)),
    not_null(columns := (order_id, order_date, customer_id, product_id)),
    positive_values(column := total_amount)
  ),
  grain order_id
);
```

### Transformation model: daily sales

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
    order_date = 'Date of the sales',
    total_orders = 'Total number of orders for the day',
    total_revenue = 'Total revenue for the day',
    last_order_id = 'Last order ID processed for the day'
  ),
  column_tags (
    order_date = ('dimension', 'grain', 'date'),
    total_orders = ('measure', 'count'),
    total_revenue = ('measure', 'financial'),
    last_order_id = ('dimension', 'identifier')
  ),
  assertions (
    unique_values(columns := (order_date)),
    not_null(columns := (order_date, total_orders, total_revenue)),
    positive_values(column := total_orders),
    positive_values(column := total_revenue)
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

***

## Best practices

1. **Use descriptive names**: `sales.daily_sales` is clearer than `sales.ds`.
2. **Add column descriptions**: document what each column represents.
3. **Use assertions**: validate data quality at the model level.
4. **Test before applying**: use `evaluate` to preview changes.
5. **Review plans carefully**: check diffs and downstream impacts.
6. **Use dev environments**: test changes before production. Don't test in prod.

***

## Next steps

* Learn about [Model Kinds](../components/model/model_kinds.md) for different model types
* Explore [Model Properties](../components/model/properties.md) for advanced configuration
* Read about [Plans](plan/plan_guide.md) for applying model changes
