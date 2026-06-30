# Transpiling semantics

The `vulcan transpile` command converts semantic queries into executable SQL. Use it to preview, debug, and validate semantic logic before execution.

Transpilation converts semantic layer queries (business-friendly) into SQL that your database understands.

## What is transpilation?

Transpilation transforms semantic layer queries into database-specific SQL. It converts "business language" (semantic queries) into "database language" (SQL).

* **Semantic SQL → native SQL**: converts semantic SQL queries with `MEASURE()` functions into standard SQL.
* **REST API payload → native SQL**: converts JSON query payloads into executable SQL statements. Use for API-driven applications.
* **Validation**: catches errors before query execution.
* **Debugging**: inspect the generated SQL to see exactly what Vulcan ran on the warehouse for a given semantic query.

Semantic queries are easier to write, but databases need SQL. Transpilation bridges that gap.

## Basic structure

### Semantic SQL query structure

Semantic SQL queries follow standard SQL syntax with semantic layer extensions:

```sql
SELECT 
  alias.dimension_name,           # Dimensions: attributes for grouping and filtering
  MEASURE(alias.measure_name)  # Measures: aggregated calculations (required wrapper)
FROM alias                        # Semantic model alias (business-friendly name)
CROSS JOIN other_alias            # Optional: join multiple models
WHERE 
  alias.dimension_name = 'value'  # Optional: filter on dimensions
  AND segment_name = true         # Optional: use segments (only = true supported)
GROUP BY alias.dimension_name     # Required: all non-aggregated columns
ORDER BY MEASURE(alias.measure_name)    # Optional: sort results
LIMIT 100                         # Optional: limit result set
OFFSET 0                          # Optional: pagination offset
```

**Key components:**

* `alias.dimension_name`: reference dimensions using semantic model alias.
* `MEASURE(measure_name)`: required wrapper for measures to apply aggregation.
* `FROM alias`: use semantic model alias, not physical model name.
* `CROSS JOIN`: join syntax (join conditions inferred automatically).
* `segment_name = true`: segments only support `= true`, not `= false`.

### REST API payload structure

REST API queries use JSON payloads with semantic query definitions:

```json
{
  "query": {
    "measures": ["alias.measure_name"],              # Required: array of measure names
    "dimensions": ["alias.dimension_name"],         # Optional: array of dimension names
    "segments": ["segment_name"],                    # Optional: array of segment names
    "timeDimensions": [{                             # Optional: array of time dimension objects
      "dimension": "alias.time_dimension",           # Required: time dimension member
      "dateRange": ["2024-01-01", "2024-12-31"],    # Optional: date range array or string
      "granularity": "month"                         # Optional: hour, day, week, month, quarter, year
    }],
    "filters": [{                                    # Optional: array of filter objects
      "member": "alias.dimension_name",              # Required: fully qualified member name
      "operator": "equals",                          # Required: filter operator
      "values": ["value1", "value2"]                 # Optional: array of filter values
    }],
    "order": {                                       # Optional: sort order object
      "alias.measure_name": "desc",                  # Member name: "asc" or "desc"
      "alias.dimension_name": "asc"
    },
    "limit": 100,                                    # Optional: maximum rows to return
    "offset": 0,                                     # Optional: rows to skip
    "timezone": "UTC",                               # Optional: timezone for date parsing
    "renewQuery": false                              # Optional: bypass cache if true
  },
  "ttl_minutes": 60                                  # Optional: cache duration in minutes
}
```

**Key components:**

* `measures`: array of fully qualified measure names: `"alias.measure_name"`.
* `dimensions`: array of fully qualified dimension names: `"alias.dimension_name"`.
* `segments`: array of segment names (no alias prefix needed).
* `timeDimensions`: array of objects with `dimension`, `dateRange`, and `granularity`.
* `filters`: array of filter objects with `member`, `operator`, and `values`.
* `order`: object mapping member names to sort direction (`"asc"` or `"desc"`).

## Basic usage

### Transpiling semantic SQL queries

Convert semantic SQL queries to native SQL:

```bash
vulcan transpile --format sql "SELECT MEASURE(total_users) FROM users"
```

**Output:** Generated SQL that can be executed directly against your database.

### Transpiling REST API payloads

Convert JSON query payloads to native SQL:

```bash
vulcan transpile --format json '{"query": {"measures": ["users.total_users"]}}'
```

**Output:** Generated SQL from the REST-style query definition.

## Command syntax

### Basic format

```bash
vulcan transpile --format <format> "<query>"
```

**Parameters:**

* `--format` (required): output format: `sql` or `json`.
* `"<query>"` (required): the semantic query to transpile.
  * For SQL format: semantic SQL query string.
  * For JSON format: JSON query payload string.

### Advanced options

```bash
vulcan transpile --format sql "<query>" [--disable-post-processing]
```

**Options:**

* `--disable-post-processing`: enable pushdown mode for CTE support and advanced SQL features.
  * **Default**: post-processing enabled (CTEs not supported).
  * **With flag**: pushdown enabled (CTEs supported, no pre-aggregations).

## Transpiling semantic SQL

### Basic query

Transpile a simple semantic SQL query:

```bash
vulcan transpile --format sql "SELECT MEASURE(total_users) FROM users"
```

**Generated SQL:**

```sql
SELECT sum("users".user_id) AS total_users
FROM analytics.users AS "users"
```

### Query with dimensions

Transpile queries with dimensions and grouping:

```bash
vulcan transpile --format sql "SELECT users.plan_type, MEASURE(total_users) FROM users GROUP BY users.plan_type"
```

**Generated SQL:**

```sql
SELECT "users".plan_type, sum("users".user_id) AS total_users
FROM analytics.users AS "users"
GROUP BY "users".plan_type
```

### Query with filters

Transpile queries with WHERE conditions:

```bash
vulcan transpile --format sql "SELECT MEASURE(total_arr) FROM subscriptions WHERE subscriptions.status = 'active'"
```

**Generated SQL:**

```sql
SELECT sum("subscriptions".arr) AS total_arr
FROM analytics.subscriptions AS "subscriptions"
WHERE "subscriptions".status = 'active'
```

### Query with time grouping

Transpile time-based queries:

```bash
vulcan transpile --format sql "SELECT DATE_TRUNC('month', subscriptions.start_date) as month, MEASURE(total_arr) FROM subscriptions GROUP BY month"
```

**Generated SQL:**

```sql
SELECT DATE_TRUNC('month', "subscriptions".start_date) AS month,
       sum("subscriptions".arr) AS total_arr
FROM analytics.subscriptions AS "subscriptions"
GROUP BY DATE_TRUNC('month', "subscriptions".start_date)
```

### Query with joins

Transpile queries joining multiple models:

```bash
vulcan transpile --format sql "SELECT users.industry, MEASURE(total_arr) FROM subscriptions CROSS JOIN users GROUP BY users.industry"
```

**Generated SQL:**

```sql
SELECT "users".industry, sum("subscriptions".arr) AS total_arr
FROM analytics.subscriptions AS "subscriptions"
CROSS JOIN analytics.users AS "users"
WHERE "subscriptions".user_id = "users".user_id
GROUP BY "users".industry
```

## Transpiling REST API payloads

### Minimal query

Transpile a basic REST API query:

```bash
vulcan transpile --format json '{"query": {"measures": ["users.total_users"]}}'
```

**Generated SQL:**

```sql
SELECT sum("users".user_id) AS total_users
FROM analytics.users AS "users"
```

### Query with dimensions

Transpile queries with dimensions:

```bash
vulcan transpile --format json '{"query": {"measures": ["subscriptions.total_arr"], "dimensions": ["subscriptions.plan_type"]}}'
```

**Generated SQL:**

```sql
SELECT "subscriptions".plan_type, sum("subscriptions".arr) AS total_arr
FROM analytics.subscriptions AS "subscriptions"
GROUP BY "subscriptions".plan_type
```

### Query with time dimensions

Transpile time-based queries:

```bash
vulcan transpile --format json '{"query": {"measures": ["orders.total_revenue"], "timeDimensions": [{"dimension": "orders.order_date", "dateRange": ["2024-01-01", "2024-12-31"], "granularity": "month"}]}}'
```

**Generated SQL:**

```sql
SELECT DATE_TRUNC('month', "orders".order_date) AS orders_order_date_month,
       sum("orders".amount) AS total_revenue
FROM analytics.orders AS "orders"
WHERE "orders".order_date >= '2024-01-01T00:00:00.000'
  AND "orders".order_date <= '2024-12-31T23:59:59.999'
GROUP BY DATE_TRUNC('month', "orders".order_date)
```

### Query with filters

Transpile queries with filters:

```bash
vulcan transpile --format json '{"query": {"measures": ["subscriptions.total_arr"], "filters": [{"member": "subscriptions.status", "operator": "equals", "values": ["active"]}]}}'
```

**Generated SQL:**

```sql
SELECT sum("subscriptions".arr) AS total_arr
FROM analytics.subscriptions AS "subscriptions"
WHERE "subscriptions".status = 'active'
```

### Query with segments

Transpile queries using segments:

```bash
vulcan transpile --format json '{"query": {"measures": ["subscriptions.total_arr"], "segments": ["subscriptions.active_subscriptions"]}}'
```

**Generated SQL:**

```sql
SELECT sum("subscriptions".arr) AS total_arr
FROM analytics.subscriptions AS "subscriptions"
WHERE "subscriptions".status = 'active'
  AND "subscriptions".end_date IS NULL
```

### Complex query

Transpile complex queries with multiple components:

```bash
vulcan transpile --format json '{"query": {"measures": ["subscriptions.total_arr", "subscriptions.total_seats"], "dimensions": ["subscriptions.plan_type", "users.industry"], "filters": [{"member": "subscriptions.status", "operator": "equals", "values": ["active"]}], "timeDimensions": [{"dimension": "subscriptions.start_date", "dateRange": ["2024-01-01", "2024-12-31"], "granularity": "month"}], "order": {"subscriptions.total_arr": "desc"}, "limit": 100}}'
```

**Generated SQL:**

```sql
SELECT DATE_TRUNC('month', "subscriptions".start_date) AS subscriptions_start_date_month,
       "subscriptions".plan_type,
       "users".industry,
       sum("subscriptions".arr) AS total_arr,
       sum("subscriptions".seats) AS total_seats
FROM analytics.subscriptions AS "subscriptions"
CROSS JOIN analytics.users AS "users"
WHERE "subscriptions".status = 'active'
  AND "subscriptions".start_date >= '2024-01-01T00:00:00.000'
  AND "subscriptions".start_date <= '2024-12-31T23:59:59.999'
  AND "subscriptions".user_id = "users".user_id
GROUP BY DATE_TRUNC('month', "subscriptions".start_date),
         "subscriptions".plan_type,
         "users".industry
ORDER BY sum("subscriptions".arr) DESC
LIMIT 100
```

## Transpiling MySQL payloads

The Vulcan MySQL wire protocol service lets you query your semantic layer from any standard MySQL client or business intelligence (BI) tool. Semantic queries are transpiled to native SQL on the server side: you write standard SQL against your semantic models, and Vulcan handles the translation.

### Connecting to Vulcan MySQL

Connect using any MySQL client:

```bash
mysql -h <host> -P <port> -u <username> -p'<api-key>' --enable-cleartext-plugin <tenant_name>.<data_product_name>
```

**Parameters:**

| Parameter                           | Description                               | Example                                                     |
| ----------------------------------- | ----------------------------------------- | ----------------------------------------------------------- |
| `-h <host>`                         | Vulcan MySQL host                         | `127.0.0.1` (local) or `tcp.my-context.dataos.app` (remote) |
| `-P <port>`                         | MySQL port                                | `3307` (local) or `3306` (remote)                           |
| `-u <username>`                     | Your DataOS username                      | `johndoe`                                                   |
| `-p'<api-key>'`                     | Your DataOS API key (no space after `-p`) | `-p'dG9rZW4xMjM0...'`                                       |
| `<tenant_name>.<data_product_name>` | Database to connect to                    | `marketing.sales_analytics`                                 |

**Example: local connection.**

```bash
mysql -h 127.0.0.1 -P 3307 -u johndoe -p'dG9rZW4xMjM0NTY3ODk=' --ssl-mode=REQUIRED --enable-cleartext-plugin
```

**Example: remote connection.**

```bash
mysql -h tcp.my-context.dataos.app -P 3306 -u johndoe -p'dG9rZW4xMjM0NTY3ODk=' --enable-cleartext-plugin marketing.sales_analytics
```

**On successful connection:**

```
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 42
Server version: 8.0.0 Vulcan MySQL Wire Protocol

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql>
```

### Discovering available models

List all available semantic models (tables):

```sql
mysql> SHOW TABLES;
+---------------------------+
| Tables_in_sales_analytics |
+---------------------------+
| users                     |
| subscriptions             |
| orders                    |
+---------------------------+
3 rows in set (0.10 sec)
```

Inspect a model's columns (dimensions and measures):

```sql
mysql> DESCRIBE users;
+----------------+--------------+------+-----+
| Field          | Type         | Null | Key |
+----------------+--------------+------+-----+
| user_id        | varchar(255) | YES  |     |
| plan_type      | varchar(255) | YES  |     |
| industry       | varchar(255) | YES  |     |
| total_users    | bigint       | YES  |     |
+----------------+--------------+------+-----+
4 rows in set (0.08 sec)
```

### Basic query

Query a single measure:

```sql
mysql> SELECT MEASURE(total_users) FROM users;
+-------------+
| total_users |
+-------------+
|        4528 |
+-------------+
1 row in set (0.45 sec)
```

### Query with dimensions

Query measures grouped by a dimension:

```sql
mysql> SELECT users.plan_type, MEASURE(total_users)
    -> FROM users
    -> GROUP BY users.plan_type;
+-----------+-------------+
| plan_type | total_users |
+-----------+-------------+
| free      |        2841 |
| starter   |        1024 |
| pro       |         512 |
| enterprise|         151 |
+-----------+-------------+
4 rows in set (0.62 sec)
```

### Query with filters

Filter results using WHERE conditions:

```sql
mysql> SELECT MEASURE(total_arr)
    -> FROM subscriptions
    -> WHERE subscriptions.status = 'active';
+-----------+
| total_arr |
+-----------+
| 2450000.0 |
+-----------+
1 row in set (0.38 sec)
```

### Query with time grouping

Group results by time intervals:

```sql
mysql> SELECT DATE_TRUNC('month', subscriptions.start_date) AS month,
    ->        MEASURE(total_arr)
    -> FROM subscriptions
    -> GROUP BY month
    -> ORDER BY month DESC
    -> LIMIT 5;
+------------+-----------+
| month      | total_arr |
+------------+-----------+
| 2024-12-01 |  285000.0 |
| 2024-11-01 |  272000.0 |
| 2024-10-01 |  268500.0 |
| 2024-09-01 |  254000.0 |
| 2024-08-01 |  241000.0 |
+------------+-----------+
5 rows in set (1.12 sec)
```

### Query with joins

Join multiple semantic models:

```sql
mysql> SELECT users.industry, MEASURE(total_arr)
    -> FROM subscriptions
    -> CROSS JOIN users
    -> GROUP BY users.industry
    -> ORDER BY MEASURE(total_arr) DESC;
+----------------+-----------+
| industry       | total_arr |
+----------------+-----------+
| Technology     |  820000.0 |
| Finance        |  645000.0 |
| Healthcare     |  480000.0 |
| Retail         |  312000.0 |
| Education      |  193000.0 |
+----------------+-----------+
5 rows in set (1.34 sec)
```

### Complex query

Combine multiple dimensions, filters, time grouping, and joins:

```sql
mysql> SELECT DATE_TRUNC('month', subscriptions.start_date) AS month,
    ->        subscriptions.plan_type,
    ->        users.industry,
    ->        MEASURE(total_arr),
    ->        MEASURE(total_seats)
    -> FROM subscriptions
    -> CROSS JOIN users
    -> WHERE subscriptions.status = 'active'
    -> GROUP BY month, subscriptions.plan_type, users.industry
    -> ORDER BY MEASURE(total_arr) DESC
    -> LIMIT 10;
+------------+-----------+------------+-----------+-------------+
| month      | plan_type | industry   | total_arr | total_seats |
+------------+-----------+------------+-----------+-------------+
| 2024-12-01 | enterprise| Technology |  125000.0 |         480 |
| 2024-12-01 | pro       | Finance    |   98000.0 |         320 |
| 2024-11-01 | enterprise| Technology |  118000.0 |         460 |
| 2024-11-01 | enterprise| Finance    |   95000.0 |         310 |
| 2024-12-01 | pro       | Healthcare |   72000.0 |         240 |
| 2024-10-01 | enterprise| Technology |  112000.0 |         440 |
| 2024-11-01 | pro       | Finance    |   88000.0 |         290 |
| 2024-12-01 | starter   | Technology |   54000.0 |         180 |
| 2024-10-01 | enterprise| Finance    |   91000.0 |         300 |
| 2024-11-01 | pro       | Healthcare |   68000.0 |         225 |
+------------+-----------+------------+-----------+-------------+
10 rows in set (2.18 sec)
```

### Exit session

```sql
mysql> EXIT;
Bye
```

## Use cases

### Query validation

Validate semantic queries before execution:

```bash
# Check if query syntax is correct
vulcan transpile --format sql "SELECT MEASURE(total_users) FROM users"
```

If the query is invalid, you'll get an error message. Better than finding out at runtime. Catch errors early, fix them, then execute.

### Debugging query behavior

Inspect generated SQL to understand how semantic queries are translated. When queries return unexpected results, transpile them to see what's happening:

```bash
# See how measures are aggregated
vulcan transpile --format sql "SELECT users.plan_type, MEASURE(total_users) FROM users GROUP BY users.plan_type"
```

This shows how Vulcan interprets your semantic query. The generated SQL often reveals unexpected issues.

### Performance analysis

Review generated SQL to find optimization opportunities. The generated SQL shows exactly what the database will execute, so you can spot performance issues:

```bash
# Check join conditions and filter placement
vulcan transpile --format sql "SELECT users.industry, MEASURE(total_arr) FROM subscriptions CROSS JOIN users WHERE subscriptions.status = 'active' GROUP BY users.industry"
```

Look at the generated SQL. Are joins efficient? Are filters in the right place? Optimize before execution.

### Documentation

Generate SQL examples for documentation or training. Use transpilation to create SQL examples that show how semantic queries translate:

```bash
# Create SQL reference from semantic queries
vulcan transpile --format sql "SELECT MEASURE(total_arr) FROM subscriptions WHERE subscriptions.status = 'active'"
```

Use this for documentation. Show both the semantic query (easy to understand) and the generated SQL (what runs).

## Common errors and solutions

### Error: "Unknown member: X"

**Cause:** member doesn't exist in semantic model or is misspelled.

**Solution:**

* Verify member exists in your semantic model.
* Check spelling and casing (case-sensitive). `users.plan_type` is different from `users.Plan_Type`.
* Use fully qualified format: `alias.member_name`.

Double-check your semantic model.

### Error: "Measure not found: X"

**Cause:** measure referenced without proper qualification or doesn't exist.

**Solution:**

* Use `MEASURE(measure_name)` wrapper for SQL format.
* Use fully qualified format: `alias.measure_name` for JSON format.
* Confirm the measure is defined in the semantic model.

The format differs between SQL and JSON, so use the right syntax for each.

### Error: "Model not found: X"

**Cause:** alias doesn't match any semantic model.

**Solution:**

* Check semantic model aliases in your `models/semantics/` directory.
* Verify alias spelling and casing.
* Confirm semantic models are defined.

### Error: "Invalid JSON format"

**Cause:** JSON payload is malformed.

**Solution:**

* Validate JSON syntax.
* Use proper quoting of strings.
* Check array and object structure.

### Error: "Projection references non-aggregate values"

**Cause:** non-aggregated columns not in GROUP BY, or measures missing MEASURE() wrapper.

**Solution:**

* Add all non-aggregated columns to GROUP BY.
* Use MEASURE() wrapper for all measures in SQL format.

You can't mix aggregated and non-aggregated columns without GROUP BY. The error tells you exactly what's wrong.

## Best practices

### Validate before execution

Transpile queries before running them in production:

```bash
# Good: Validate first
vulcan transpile --format sql "SELECT MEASURE(total_users) FROM users"
# Review output, then execute - make sure the SQL looks right

# Bad: Execute without validation
# Direct execution without checking generated SQL - don't do this
```

Transpilation catches errors early.

### Use transpilation for debugging

When queries return unexpected results, transpile to inspect generated SQL. The generated SQL often reveals what's happening:

```bash
# Debug query behavior
vulcan transpile --format sql "SELECT users.plan_type, MEASURE(total_users) FROM users GROUP BY users.plan_type"
# Compare generated SQL with expected behavior - does it match what you think should happen?
```

Sometimes the issue isn't with your semantic query, it's with how it's translated. Transpilation shows you the translation.

### Document query patterns

Use transpilation output to document common query patterns:

```bash
# Generate SQL examples for documentation
vulcan transpile --format sql "SELECT MEASURE(total_arr) FROM subscriptions WHERE subscriptions.status = 'active'"
```

### Test both formats

When building applications, test both SQL and JSON formats:

```bash
# Test SQL format
vulcan transpile --format sql "SELECT MEASURE(total_users) FROM users"

# Test equivalent JSON format
vulcan transpile --format json '{"query": {"measures": ["users.total_users"]}}'
```

### Choose appropriate mode

Select post-processing or pushdown mode based on needs:

* **Post-processing (default)**: use for queries that benefit from pre-aggregations and caching.
* **Pushdown (`--disable-post-processing`)**: use when you need CTEs or complex SQL structures.

## Integration with development workflow

### Pre-commit validation

Add transpilation checks to your development workflow:

```bash
# Validate semantic queries in CI/CD
vulcan transpile --format sql "SELECT MEASURE(total_users) FROM users"
```

### Query testing

Use transpilation to generate test SQL:

```bash
# Generate SQL for testing
vulcan transpile --format sql "SELECT users.plan_type, MEASURE(total_users) FROM users GROUP BY users.plan_type"
# Use output in test assertions
```

### Performance tuning

Analyze generated SQL for optimization:

```bash
# Review join conditions and filter placement
vulcan transpile --format sql "SELECT users.industry, MEASURE(total_arr) FROM subscriptions CROSS JOIN users WHERE subscriptions.status = 'active' GROUP BY users.industry"
```

## Next steps

* Learn about [Semantic Models](../components/model/types/models.md) that define the queryable members
* Explore [Business Metrics](../components/semantics/business_metrics.md) for time-series analysis
* See the [Semantics Overview](../components/semantics/) for the complete picture
