# Data quality

A **DQ check** (a declarative quality rule pack) monitors your data quality over time without blocking your models. It warns you when something looks off but doesn't stop execution.

Unlike [assertions](./assertions.md), which block model execution when their audit fails, DQ checks run separately or alongside your models and provide non-blocking validation. Use them to track trends, detect anomalies, and build a historical picture of data quality. In the triplet, **audits define, assertions attach, DQ checks watch.**

**What makes a DQ check different:**

* Configured in simple YAML files in `dq/`, using `kind: dq`
* One rule pack per file, each targeting a single model via `depends_on:`
* Don't block models (your models keep running even if a rule fails)
* Track historical patterns and trends
* Support complex statistical analysis
* Integrate with Activity API for monitoring and alerting

## Data Quality vs assertions vs profiles

Assertions, Data Quality rule packs, and profiles all watch your data, but they answer different questions. Pick the wrong one and you'll either block a run that should have shipped or let bad rows reach production.

| Feature                 | Assertions                     | Data Quality rule packs                 | Profiles                               |
| ----------------------- | ------------------------------ | --------------------------------------- | -------------------------------------- |
| **Purpose**             | Critical validation            | Monitoring and analysis                 | Observation and tracking               |
| **When runs**           | With model (inline)            | Separately or with models               | With model                             |
| **Blocks models?**      | Yes (always)                   | No                                      | No                                     |
| **Configuration**       | In MODEL DDL or .sql files     | YAML files in `dq/` (`kind: dq`)        | Under `profiles:` in a `kind: dq` file |
| **Output**              | Pass/fail                      | Pass/fail + samples                     | Statistical metrics                    |
| **Best for**            | Business rules, data integrity | Trend monitoring, anomalies             | Understanding data                     |
| **Historical tracking** | No                             | Yes (Activity API)                      | Yes (`_check_profiles`)                |

**The Three-Layer Strategy:**

A layered approach to data quality:

```
┌─────────────────────────────────────────┐
│  AUDITS (Critical: Blocks models)       │
│  • Primary keys must be unique          │
│  • Revenue must be non-negative         │
│  • Foreign key relationships valid      │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  DATA QUALITY (Monitoring: Non-Blocking) │
│  • Row count within expected range      │
│  • Anomaly detection on metrics         │
│  • Cross-table consistency              │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  PROFILES (Observation: Metrics)        │
│  • Track null percentages               │
│  • Monitor column distributions         │
│  • Detect data drift                    │
└─────────────────────────────────────────┘
```

Assertions stop bad data at the door. Data Quality rule packs watch for problems but don't interfere. Profiles observe patterns and help you understand what's normal.

## When to use Data Quality

**Use Data Quality rule packs for:**

* Monitoring data quality trends over time (is completeness getting worse?)
* Statistical anomaly detection (did revenue suddenly spike?)
* Cross-model validation (do orders match customers?)
* Non-critical validation (warnings, not blockers)
* Complex validation requiring historical context
* Building data quality dashboards

**Use assertions instead for:**

* Critical business rules that must pass (revenue can't be negative)
* Model-specific validation (runs inline with the model)
* Simple SQL assertions
* Blocking invalid data from flowing downstream

**Use profiles instead for:**

* Understanding data characteristics (what does this column look like?)
* Discovering patterns (not validation)
* Detecting data drift over time
* Informing which Data Quality rules and assertions to add

**Example: Revenue validation strategy**

Here's how you'd layer all three for a revenue table:

```sql
-- AUDIT (Critical: blocks if it fails)
-- This stops the model if revenue is invalid
MODEL (
  name analytics.revenue,
  assertions (
    not_null(columns := (customer_id, revenue)),
    accepted_range(column := revenue, min_v := 0, max_v := 100000000)
  )
);
```

```yaml
# DATA QUALITY (Monitoring + observation)
# dq/revenue.yml
# Profiles watch and record. Rules warn if something looks unusual.
# Neither blocks the model.
kind: dq
name: revenue_dq
depends_on: analytics.revenue

profiles:
  - revenue
  - order_count
  - customer_tier

rules:
  - anomaly detection for avg(revenue):
      name: revenue_anomaly_detection
      dimension: accuracy
  - change for row_count >= -30%:
      name: row_count_drop_alert
      dimension: timeliness
```

## Quick start

### Your first Data Quality rule pack

Create your first rule pack. It's simpler than you might think.

Create a file `dq/customers.yml`:

```yaml
kind: dq
name: customers_dq
depends_on: analytics.customers

rules:
  - missing_count(email) = 0:
      name: no_missing_emails
      dimension: completeness
      description: "All customers must have an email address"
```

This rule ensures every customer has an email address. When you run your models, the rule runs automatically and warns you if any emails are missing.

**What happens when it runs:**

Rule packs and profiles run automatically when models execute, either through a **plan** or **run** command. Here's what the execution output looks like:

```bash
Check Executions (1 Models)
└── hello.subscriptions
    ├── completeness (4/4)
    ├── uniqueness (1/1)
    └── validity (3/3)

Profiled 1 model (3 columns):
  warehouse.hello.subscriptions: 3 columns
```

Here are common patterns you'll use:

### Common rule patterns

The patterns you'll use most often. Copy them, tweak for your tables, and go.

#### Pattern 1: completeness rules

Make sure required data is present:

```yaml
kind: dq
name: orders_completeness
depends_on: analytics.orders

rules:
  - missing_count(customer_id) = 0:
      name: customer_id_required
      dimension: completeness

  - missing_percent(email) < 5:
      name: email_mostly_complete
      dimension: completeness

  - row_count > 1000:
      name: sufficient_orders
      dimension: completeness
```

The first rule ensures every order has a customer ID (zero tolerance). The second allows up to 5% missing emails. The third makes sure you have enough data to work with.

#### Pattern 2: validity rules

Validate data format and values:

```yaml
kind: dq
name: users_validity
depends_on: analytics.users

rules:
  - failed rows:
      name: invalid_emails
      dimension: validity
      fail query: |
        SELECT user_id, email
        FROM analytics.users
        WHERE email NOT LIKE '%@%'
      samples limit: 10

  - failed rows:
      name: invalid_ages
      dimension: validity
      fail query: |
        SELECT user_id, age
        FROM analytics.users
        WHERE age < 0 OR age > 120
```

The `failed rows` rule type is flexible. You can write any SQL query. If it returns rows, the rule fails and captures those rows as samples.

#### Pattern 3: uniqueness rules

Ensure no duplicates:

```yaml
kind: dq
name: customers_uniqueness
depends_on: analytics.customers

rules:
  - duplicate_count(email) = 0:
      name: unique_emails
      dimension: uniqueness

  - duplicate_count(customer_id, order_date) = 0:
      name: unique_customer_date_combination
      dimension: uniqueness
```

The second example shows composite keys: maybe a customer can have multiple orders, but only one per day.

#### Pattern 4: anomaly detection

Detect unusual patterns automatically:

```yaml
kind: dq
name: daily_revenue_anomaly
depends_on: analytics.daily_revenue

rules:
  - anomaly detection for row_count:
      name: row_count_anomaly
      dimension: accuracy

  - anomaly detection for avg(revenue):
      name: revenue_anomaly
      dimension: accuracy
```

Anomaly detection learns from historical data and flags when something looks unusual. It needs to run a few times first to build a baseline, then it starts detecting problems.

#### Pattern 5: change monitoring

Track changes over time:

```yaml
kind: dq
name: orders_timeliness
depends_on: analytics.orders

rules:
  - change for row_count >= -50%:
      name: row_count_drop_alert
      dimension: timeliness
      description: "Alert if row count drops more than 50%"
```

This compares the current value to the previous run and alerts you if it changes too much. Use it to catch sudden drops or spikes.

## Data Quality configuration

### File structure

Data Quality rule packs live in YAML files in `dq/`. **Each file is one rule pack and targets exactly one model** via `depends_on:`. Organize them however makes sense for your project:

```
project/
├── models/
│   ├── dq/
│   │   ├── users.yml           # Rules for analytics.users
│   │   ├── orders.yml          # Rules for analytics.orders
│   │   ├── revenue.yml         # Rules for analytics.revenue
│   │   └── cross_model.yml     # Rules anchored on one model, joining others via SQL
│   ├── semantics/
│   ├── metrics/
│   └── *.sql
└── config.yaml
```

**File naming:**

* Must end with `.yml` or `.yaml`
* The file name doesn't matter (Vulcan reads all files in `dq/`)
* Convention: name files after the model they target (e.g. `subscriptions.yml` for `hello.subscriptions`)

### Basic Data Quality syntax

A rule pack has a pack-level header followed by a list of `rules:`.

```yaml
kind: dq                          # Required: file kind
name: <rule_pack_name>            # Required: unique name for this pack
depends_on: <fully.qualified.model>  # Required: the model this pack validates

# Optional pack-level fields:
filter: "<sql_predicate>"         # Applied to every rule in this pack
profiles:                         # Columns to profile alongside the rules
  - <column_1>
  - <column_2>

rules:
  - <rule_expression>:            # e.g. missing_count(col) = 0, failed rows, etc.
      name: <rule_name>
      dimension: <dimension>      # completeness | validity | accuracy | ...
      description: <human_readable_description>
      # ...other per-rule fields (see below)
```

`kind: dq` declares the file as a Data Quality rule pack. `name` identifies the pack. `depends_on` ties every rule in the file to a single model.

**Example:**

```yaml
kind: dq
name: customers_dq
depends_on: analytics.customers

rules:
  - row_count > 100:
      name: sufficient_customers
      dimension: completeness
      description: "At least 100 customers expected in production"
      tags: [critical, daily]
```

### Rule forms: shorthand and full

A rule can be a bare expression (no metadata) or an expression with a metadata block.

**Shorthand:** just the expression, no metadata. Vulcan auto-names the rule and skips the optional fields:

```yaml
rules:
  - missing_count(user_id) = 0
  - missing_count(event_date) = 0
  - duplicate_count(event_id) = 0
```

**Full form:** the expression is a YAML key and the metadata is its value:

```yaml
rules:
  - missing_count(event_type) = 0:
      name: no_missing_event_types
      dimension: completeness
      description: "All events must have an event type"
```

You can mix both in the same `rules:` list. Use shorthand for obvious rules, full form whenever you want a stable name, a dimension tag, a description, severity, etc.

### Rule attributes

All rule metadata is **flat**: keys sit directly under the rule expression, not nested under an `attributes:` block.

| Field           | Description                                                                                                                             |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `name`          | Stable identifier for the rule. Required when you want to look it up in the Activity API.                                               |
| `dimension`     | Data-quality dimension: `completeness`, `validity`, `accuracy`, `consistency`, `uniqueness`, `timeliness`, `conformity`, or `coverage`. |
| `description`   | Human-readable explanation.                                                                                                             |
| `filter`        | SQL predicate applied to this rule only. Overlays the pack-level `filter:`.                                                             |
| `warn`          | Threshold expression for emitting a warning (e.g. `when < 10`).                                                                         |
| `fail`          | Threshold expression for failing the rule (e.g. `when > 100`).                                                                          |
| `warn_only`     | `true` to downgrade any failure to a warning.                                                                                           |
| `fail query`    | SQL `SELECT` returning bad rows. Only used with `failed rows`.                                                                          |
| `samples limit` | Number of failed sample rows to capture (default `5`).                                                                                  |
| `tags`          | List of tags for filtering and organisation, e.g. `[critical, daily]`.                                                                  |
| `owner`         | Team or person responsible.                                                                                                             |
| `severity`      | `error` (default) or `warning`.                                                                                                         |

**Example using `warn` / `fail` / `warn_only` / `filter`:**

```yaml
kind: dq
name: usage_events_dq
depends_on: b2b_saas.usage_events

rules:
  - row_count > 10:
      name: sufficient_events
      dimension: completeness
      warn: when < 10
      fail: when > 100
      description: "At least 10 events captured"

  - row_count > 0:
      name: events_in_run_window
      dimension: completeness
      filter: "event_date >= CAST('${execution_dt}' AS DATE) - INTERVAL '7 days'"
      warn_only: true
      description: "Events exist in the run window"
```

### Data Quality dimensions

Rules are classified by the `dimension:` field. Vulcan supports 8 standard dimensions (based on ODPS v3.1). Each dimension focuses on a different aspect of data quality:

#### 1. Completeness

No missing required data. The most common dimension.

```yaml
rules:
  - missing_count(customer_id) = 0:
      dimension: completeness
  - missing_percent(email) < 5:
      dimension: completeness
  - row_count > 1000:
      dimension: completeness
```

#### 2. Validity

Data conforms to format/syntax. Is that email actually an email? Is that date in the right format?

```yaml
rules:
  - failed rows:
      dimension: validity
      fail query: |
        SELECT * FROM analytics.users
        WHERE email NOT LIKE '%@%'
```

#### 3. Accuracy

Data matches reality. Is the average age reasonable? Is revenue in the expected range?

```yaml
rules:
  - anomaly detection for avg(revenue):
      dimension: accuracy
  - avg(age) between 18 and 65:
      dimension: accuracy
```

#### 4. Consistency

Data agrees across sources. Do orders match customers? Are totals consistent?

```yaml
rules:
  - failed rows:
      dimension: consistency
      fail query: |
        SELECT *
        FROM analytics.orders o
        LEFT JOIN analytics.customers c ON o.customer_id = c.customer_id
        WHERE c.customer_id IS NULL
```

#### 5. Uniqueness

No duplicates. Is that email really unique? Can customers have multiple orders per day?

```yaml
rules:
  - duplicate_count(email) = 0:
      dimension: uniqueness
  - duplicate_count(order_id) = 0:
      dimension: uniqueness
```

#### 6. Timeliness

Data is current. Is the data fresh? Are updates happening on time?

```yaml
rules:
  - change for row_count >= -30%:
      dimension: timeliness
  - failed rows:
      dimension: timeliness
      fail query: |
        SELECT *
        FROM analytics.orders
        WHERE updated_at < CURRENT_DATE - INTERVAL '7 days'
```

#### 7. Conformity

Follows standards. Does the zip code have the right format? Are codes valid?

```yaml
rules:
  - failed rows:
      dimension: conformity
      fail query: |
        SELECT *
        FROM analytics.addresses
        WHERE LENGTH(zip_code) != 5
```

#### 8. Coverage

All records are present. Did we get all the data we expected?

```yaml
rules:
  - row_count >= 95% of historical_avg(row_count):
      dimension: coverage
```

### Filtering rules

You can apply a SQL predicate at two levels.

**Pack-level filter:** applied to every rule in the file.

```yaml
kind: dq
name: completed_recent_orders_dq
depends_on: analytics.orders

filter: "status = 'completed' AND order_date >= CURRENT_DATE - INTERVAL '30 days'"

rules:
  - missing_count(customer_id) = 0:
      name: completed_orders_have_customers
      dimension: completeness
  - row_count > 0:
      name: completed_orders_exist
      dimension: completeness
```

**Per-rule filter:** applied only to that rule. Overlays the pack-level filter.

```yaml
rules:
  - row_count > 500:
      name: sufficient_active_users
      dimension: completeness
      filter: "status = 'active'"
```

Need different expectations for different slices of the same model (e.g. US vs EU customers)? Create a separate file per slice. Each rule pack has a single `depends_on:` and its own `filter:`.

### Per-rule metadata example

```yaml
kind: dq
name: revenue_dq
depends_on: analytics.revenue

rules:
  - row_count > 1000:
      name: sufficient_revenue_data
      dimension: completeness
      description: "Revenue table must have at least 1000 rows for analysis"
      tags: [critical, daily, revenue]
      owner: data-team
      severity: error
```

**Standard fields recap:**

* `description`: human-readable explanation.
* `severity`: `error` (default) or `warning`.
* `tags`: list of tags for filtering and organisation, e.g. find every `critical` rule.
* `owner`: team or person responsible.

## Built-in rule types

Vulcan provides several built-in rule types that cover most common scenarios.

### Missing data rules

#### `missing_count(column)`

Count of NULL values. Simple and straightforward:

```yaml
rules:
  - missing_count(email) = 0:
      name: no_missing_emails
      dimension: completeness

  - missing_count(phone) <= 100:
      name: phone_mostly_complete
      dimension: completeness
```

The first ensures zero missing emails (strict). The second allows up to 100 missing phone numbers.

#### `missing_percent(column)`

Percentage of NULL values. Useful when you care about proportions rather than absolute counts:

```yaml
rules:
  - missing_percent(email) < 5:
      name: email_95_percent_complete
      dimension: completeness

  - missing_percent(optional_field) < 50:
      name: optional_field_half_complete
      dimension: completeness
```

Useful when table sizes vary. 5% missing might be fine for a million-row table but concerning for a hundred-row table.

### Row count rules

#### `row_count`

Total rows in table. Ensure you have enough data:

```yaml
rules:
  - row_count > 1000:
      name: sufficient_data
      dimension: completeness

  - row_count between 1000 and 100000:
      name: expected_row_range
      dimension: completeness
```

The second example is a range check: if you know the table should land between 1K and 100K rows, anything outside that range is suspicious.

#### `row_count` with filter

You can also check row counts on filtered data:

```yaml
rules:
  - row_count > 500:
      name: sufficient_active_users
      dimension: completeness
      filter: "status = 'active'"
```

This checks that you have at least 500 active users, regardless of how many total users you have.

### Duplicate count rules

#### `duplicate_count(column)`

Count of duplicate values. Ensures uniqueness:

```yaml
rules:
  - duplicate_count(email) = 0:
      name: unique_emails
      dimension: uniqueness

  - duplicate_count(customer_id) = 0:
      name: unique_customer_ids
      dimension: uniqueness
```

If this returns anything greater than zero, you've got duplicates. The rule fails and you can investigate.

#### `duplicate_count(column1, column2)`

Composite key duplicates. Check combinations of columns:

```yaml
rules:
  - duplicate_count(customer_id, order_date) = 0:
      name: unique_customer_date
      dimension: uniqueness
      description: "Each customer can have at most one order per day"
```

Maybe customers can have multiple orders, but only one per day. This rule enforces that business rule.

### Failed rows rules

#### SQL-based validation with samples

This is the most flexible rule type. Write any SQL query that returns the rows you consider invalid:

```yaml
rules:
  - failed rows:
      name: invalid_revenue
      dimension: validity
      fail query: |
        SELECT customer_id, revenue, order_date
        FROM analytics.orders
        WHERE revenue < 0 OR revenue > 10000000
      samples limit: 20
      description: "Revenue must be between 0 and 10M"
```

**How it works:**

* `fail query`: a `SELECT` statement that returns invalid rows.
* `samples limit`: how many example rows to capture when the rule fails (default: 5).
* Empty result: the rule passes (no invalid rows found).
* One or more rows: the rule fails, and Vulcan captures samples so you can see what's wrong.

**Complex validation:**

You can get fancy with joins and CTEs:

```yaml
rules:
  - failed rows:
      name: orphaned_orders
      dimension: consistency
      fail query: |
        SELECT o.order_id, o.customer_id
        FROM analytics.orders o
        LEFT JOIN analytics.customers c ON o.customer_id = c.customer_id
        WHERE c.customer_id IS NULL
      samples limit: 10
```

This finds orders that reference customers that don't exist: a classic referential integrity check.

### Threshold rules

#### Numeric aggregations

Check aggregated values against thresholds:

```yaml
rules:
  - avg(revenue) between 100 and 10000:
      name: revenue_in_expected_range
      dimension: accuracy

  - sum(amount) > 1000000:
      name: sufficient_total_revenue
      dimension: accuracy

  - max(age) <= 120:
      name: age_within_human_range
      dimension: validity

  - min(price) >= 0:
      name: non_negative_prices
      dimension: validity
```

You can use any aggregation function: `avg`, `sum`, `min`, `max`, `count`, `distinct_count`, etc.

#### Statistical rules

Use statistical functions:

```yaml
rules:
  - stddev(revenue) < 5000:
      name: revenue_low_variance
      dimension: accuracy

  - percentile(revenue, 95) < 50000:
      name: revenue_95th_percentile_check
      dimension: accuracy
```

These detect when your data distribution changes unexpectedly.

### Anomaly detection

#### ML-based anomaly detection

Anomaly detection rules learn what "normal" looks like from previous runs of the same rule, then flag the next value when it falls outside that range. There's no model to train and no thresholds to set, you just declare the metric to watch:

```yaml
rules:
  - anomaly detection for row_count:
      name: row_count_anomaly
      dimension: accuracy
      description: "Detect unusual changes in row count"

  - anomaly detection for avg(revenue):
      name: revenue_anomaly
      dimension: accuracy

  - anomaly detection for distinct_count(customer_id):
      name: customer_count_anomaly
      dimension: accuracy
```

**How it works:**

1. Collects historical metric values over time (every time the rule runs)
2. Builds a statistical model (mean, standard deviation, trends)
3. Compares current value to expected range
4. Flags significant deviations (typically > 3 standard deviations)

**Requirements:**

* Needs historical data (runs multiple times to build a baseline)
* Works best with regular schedules (daily, hourly)
* More accurate after 30+ data points (the more history, the better)

Anomaly detection needs history before it's useful. Expect the first \~30 runs to be no-ops while the baseline fills in. After that it catches drifts you wouldn't have thought to write a threshold rule for.

### Change over time rules

#### Monitor changes compared to previous run

Track how metrics change between runs:

```yaml
rules:
  - change for row_count >= -50%:
      name: row_count_drop_alert
      dimension: timeliness
      description: "Alert if row count drops more than 50% from last week"

  - change for avg(revenue) >= -20%:
      name: revenue_drop_alert
      dimension: timeliness

  - change for distinct_count(customer_id) >= 10%:
      name: customer_growth_check
      dimension: timeliness
```

**Change calculation:**

```
change = (current_value - previous_value) / previous_value * 100
```

**Examples:**

* `change >= -30%`: alert if the metric drops more than 30%.
* `change >= 10%`: alert if the metric grows more than 10%.
* `change between -10% and 10%`: alert if the metric moves more than 10% in either direction.

This catches sudden changes that might indicate a problem or an opportunity.

## Data profiling

### What is profiling?

**Profiles automatically collect statistical metrics about your data over time.**

Unlike rules (which validate), profiles **observe and track** data characteristics. They're like a data scientist watching your tables and taking notes.

Profiling is enabled in a `kind: dq` rule pack via the top-level `profiles:` list. Add the columns you want to track alongside (or instead of) the rules for the same model:

```yaml
# dq/customers.yml
kind: dq
name: customers_dq
depends_on: analytics.customers

profiles:
  - revenue
  - signup_date
  - customer_tier
  - order_count

rules:
  - missing_count(email) = 0:
      dimension: completeness
```

A rule pack can be profile-only (omit `rules:`), rules-only (omit `profiles:`), or both. Vulcan collects the listed metrics every time the model in `depends_on:` runs.

**What gets profiled:**

**Table-level metrics:**

* Row count

**Column-level metrics (all listed columns):**

* Null count & percentage
* Distinct count
* Duplicate count
* Uniqueness percentage

**Numeric columns:**

* Min, max, avg, sum
* Standard deviation, variance
* Histogram buckets

**Text columns:**

* Min, max, avg length
* Most frequent values

Profiles track how things change over time so you can spot trends and drift.

### Profile storage

Profiles are stored in the `_check_profiles` table, which you can query like any other table:

| Column         | Meaning                                                                                                       |
| -------------- | ------------------------------------------------------------------------------------------------------------- |
| `id`           | Unique identifier for this metric row                                                                         |
| `run_id`       | Identifies which profiling run this metric belongs to                                                         |
| `table_name`   | Name of the table being profiled                                                                              |
| `column_name`  | Name of the column being profiled (NULL for table-level metrics like row\_count)                              |
| `profile_type` | The type of metric, e.g., row\_count, distinct, missing\_count, frequent\_values, min, max, avg\_length, etc. |
| `value_number` | Numeric metric value (for metrics like row\_count, distinct, min, max, avg, etc.)                             |
| `value_text`   | Used for text values (rare)                                                                                   |
| `value_json`   | JSON-encoded metric (for histograms, frequent values, etc.)                                                   |
| `value_type`   | Type of value stored (number, json, etc.)                                                                     |
| `profiled_at`  | When the profiling was performed (epoch ms)                                                                   |
| `created_ts`   | When the row was inserted                                                                                     |

### Querying profiles

#### Track missing count over time

See how null percentages change:

```sql
SELECT
  to_timestamp(profiled_at/1000)::date AS date,
  value_number AS missing_count
FROM _check_profiles
WHERE table_name = 'warehouse.hello.subscriptions'
  AND column_name = 'mrr'
  AND profile_type = 'missing_count'
ORDER BY profiled_at DESC
LIMIT 30;  -- Last 30 days
```

Shows a time series of missing values for spotting trends.

#### Monitor data drift

Compare current values to historical averages:

```sql
WITH latest_profile AS (
  -- Pick the most recent profiling timestamp for that table/column
  SELECT profiled_at
  FROM _check_profiles
  WHERE table_name = 'warehouse.hello.subscriptions'
    AND column_name = 'mrr'
  ORDER BY profiled_at DESC
  LIMIT 1
),

current AS (
  -- Get the most recent distinct count and average value from that profiling run
  SELECT
    MAX(CASE WHEN profile_type = 'distinct' THEN value_number END)     AS distinct_count,
    MAX(CASE WHEN profile_type IN ('avg', 'mean', 'average', 'avg_value') THEN value_number END) AS avg_value
  FROM _check_profiles p
  JOIN latest_profile l ON p.profiled_at = l.profiled_at
  WHERE p.table_name = 'warehouse.hello.subscriptions'
    AND p.column_name = 'mrr'
),

historical AS (
  -- 30-day historical averages (profiled_at stored as epoch ms → convert to timestamp)
  SELECT
    AVG(CASE WHEN profile_type = 'distinct' THEN value_number END)      AS avg_distinct,
    AVG(CASE WHEN profile_type IN ('avg', 'mean', 'average', 'avg_value') THEN value_number END) AS avg_mrr
  FROM _check_profiles
  WHERE table_name = 'warehouse.hello.subscriptions'
    AND column_name = 'mrr'
    AND to_timestamp(profiled_at/1000) >= CURRENT_DATE - INTERVAL '30 days'
)

SELECT
  c.distinct_count,
  h.avg_distinct,
  CASE
    WHEN h.avg_distinct IS NULL THEN NULL
    ELSE (c.distinct_count - h.avg_distinct) / NULLIF(h.avg_distinct, 0) * 100
  END AS distinct_change_pct,
  c.avg_value,
  h.avg_mrr,
  CASE
    WHEN h.avg_mrr IS NULL THEN NULL
    ELSE (c.avg_value - h.avg_mrr) / NULLIF(h.avg_mrr, 0) * 100
  END AS mrr_change_pct
FROM current c, historical h;
```

This query compares current metrics to 30-day historical averages and calculates percentage changes. Use it to detect drift.

### Using profiles to inform rules

**Workflow:**

1. **Enable profiling** on new models (add a `profiles:` list to the `kind: dq` file for that model)
2. **Observe patterns** for 30+ days (let profiles collect data)
3. **Identify anomalies** in profile data (query `_check_profiles` and look for trends)
4. **Create rules** based on observed patterns (now you know what's normal)

**Example:**

```yaml
# Step 1: Enable profiling alongside the rule pack
kind: dq
name: orders_dq
depends_on: analytics.orders

profiles:
  - order_count
  - revenue
  - customer_tier

rules:
  - row_count > 0:
      dimension: completeness
```

```sql
-- Step 2: Query profiles after 30 days
SELECT
    MIN(value_number) AS min_revenue,
    MAX(value_number) AS max_revenue,
    AVG(value_number) AS typical_revenue,
    STDDEV(value_number) AS revenue_stddev
FROM _check_profiles
WHERE table_name = 'warehouse.analytics.orders'
  AND column_name = 'revenue'
  AND profile_type IN ('avg', 'mean', 'average', 'avg_value')
  AND to_timestamp(profiled_at/1000) >= CURRENT_DATE - INTERVAL '30 days';

-- Results:
--   min_revenue:     45000
--   max_revenue:     75000
--   typical_revenue: 58000
--   revenue_stddev:  6000
```

```yaml
# Step 3: Add rules informed by what you observed
kind: dq
name: orders_dq
depends_on: analytics.orders

profiles:
  - order_count
  - revenue
  - customer_tier

rules:
  - avg(revenue) between 40000 and 80000:
      name: revenue_within_observed_range
      dimension: accuracy
      description: "Based on 30-day historical analysis"

  - anomaly detection for avg(revenue):
      name: revenue_anomaly_detection
      dimension: accuracy
```

Now your rules are informed by actual data patterns, not guesses.

### Profile best practices

**DO:**

* Profile high-value production tables (the ones that matter)
* Profile columns used in downstream analysis (if it's important, profile it)
* Use profiles to understand new data sources (what does this data look like?)
* Query profiles to detect data drift (is something changing?)
* Use profiles to inform rule thresholds (data-driven thresholds are better)

**DON'T:**

* Profile sensitive/PII columns (privacy risk, be careful)
* Profile every column (performance overhead, pick what matters)
* Profile temporary/experimental models (waste of resources)
* Use profiles as a replacement for rules (they serve different purposes)
* Profile very high-frequency models (storage cost adds up)

**When to use profiles:**

* Building new models (understand the data first)
* Monitoring production tables (watch for changes)
* Detecting data drift (is the data changing?)
* Informing assertion/rule strategy (what should we check?)
* Debugging data quality issues (what's normal vs abnormal?)

**When to skip profiles:**

* Temporary models (they won't be around long)
* Models with sensitive data (privacy concerns)
* Very high-frequency models (> 100 runs/day, storage costs)
* Models where you only need pass/fail validation (profiles are overkill)

## Advanced patterns

### Cross-model validation

Each rule pack targets a single model via `depends_on:`, but `failed rows` queries can reference any model in your warehouse. Anchor the pack on the model whose quality is at stake, then JOIN to the related models in SQL.

```yaml
# dq/orders_cross_model.yml
kind: dq
name: orders_cross_model_dq
depends_on: analytics.orders

rules:
  - failed rows:
      name: orphaned_orders
      dimension: consistency
      fail query: |
        SELECT o.order_id, o.customer_id
        FROM analytics.orders o
        LEFT JOIN analytics.customers c ON o.customer_id = c.customer_id
        WHERE c.customer_id IS NULL
      samples limit: 10
      description: "All orders must have a valid customer"

  - failed rows:
      name: revenue_mismatch
      dimension: consistency
      fail query: |
        SELECT
          o.order_id,
          o.revenue AS order_revenue,
          r.revenue AS revenue_table_revenue
        FROM analytics.orders o
        JOIN analytics.revenue r ON o.order_id = r.order_id
        WHERE ABS(o.revenue - r.revenue) > 0.01
```

The first rule finds orders without valid customers (orphaned records). The second ensures revenue matches across tables (consistency check). Both belong to the `orders` pack because that's the model whose quality they describe.

### Time-based validation

Ensure data timeliness. Is your data fresh? Are updates happening on schedule?

```yaml
kind: dq
name: orders_timeliness_dq
depends_on: analytics.orders

rules:
  - failed rows:
      name: stale_data
      dimension: timeliness
      fail query: |
        SELECT *
        FROM analytics.orders
        WHERE updated_at < CURRENT_TIMESTAMP - INTERVAL '24 hours'
          AND status != 'completed'
      description: "Pending orders should update within 24 hours"

  - failed rows:
      name: future_dates
      dimension: timeliness
      fail query: |
        SELECT *
        FROM analytics.orders
        WHERE order_date > CURRENT_DATE
```

The first rule finds stale pending orders. The second catches future dates (data entry errors).

### Statistical outlier detection

Custom outlier detection using SQL. Use this when you need more control than anomaly detection provides:

```yaml
kind: dq
name: revenue_outliers_dq
depends_on: analytics.revenue

rules:
  - failed rows:
      name: revenue_outliers
      dimension: accuracy
      fail query: |
        WITH stats AS (
          SELECT
            AVG(revenue) AS mean,
            STDDEV(revenue) AS stddev
          FROM analytics.revenue
        )
        SELECT r.*,
          (r.revenue - s.mean) / s.stddev AS z_score
        FROM analytics.revenue r, stats s
        WHERE ABS((r.revenue - s.mean) / s.stddev) > 3
      samples limit: 20
```

This finds rows where revenue is more than 3 standard deviations from the mean (classic outlier detection). The z-score tells you how extreme each outlier is.

## Best practices

### Rule pack organization

Organize your Data Quality rule packs in a way that makes sense for your team. Here are two common approaches:

**By domain:**

```
dq/
├── customers/
│   ├── customers_completeness.yml
│   ├── customers_validity.yml
│   └── customers_consistency.yml
├── orders/
│   ├── orders_completeness.yml
│   └── orders_timeliness.yml
└── revenue/
    └── revenue_accuracy.yml
```

**By priority:**

```
dq/
├── customers_critical.yml      # Must never fail
├── customers_important.yml     # Should rarely fail
├── customers_monitoring.yml    # Track trends
└── customers_experimental.yml  # Testing new rules
```

Each file still maps to a single model via `depends_on:`. Splitting by dimension or priority is just a way to keep individual files small and ownership clear.

### Naming conventions

**Use descriptive names:**

```yaml
# Bad: what does "check1" tell you?
kind: dq
name: customers_dq
depends_on: analytics.customers

rules:
  - missing_count(email) = 0:
      name: check1
      dimension: completeness

# Good: clear and descriptive
kind: dq
name: customers_dq
depends_on: analytics.customers

rules:
  - missing_count(email) = 0:
      name: no_missing_customer_emails
      dimension: completeness
      description: "All customers must have an email for marketing"
```

**Naming pattern:**

* `<dimension>_<what>_<constraint>` or `<what>_<constraint>`
* Examples:
  * `completeness_email_required` or `no_missing_emails`
  * `validity_email_format` or `valid_email_format`
  * `uniqueness_email_no_duplicates` or `unique_emails`
  * `timeliness_order_within_24hrs` or `orders_update_daily`

The key is that someone reading the name should understand what it checks without looking at the code.

### Threshold selection

**Start conservative, adjust based on data:**

```yaml
# Step 1: Start with a wide range
kind: dq
name: orders_dq
depends_on: analytics.orders

rules:
  - row_count > 100:
      name: sufficient_orders_v1
      dimension: completeness

# Step 2: Monitor for 30 days, see actual range: 5000-10000

# Step 3: Tighten based on observed patterns
kind: dq
name: orders_dq
depends_on: analytics.orders

rules:
  - row_count between 4000 and 12000:
      name: sufficient_orders_v2
      dimension: completeness
      description: "Based on 30-day historical analysis"
```

Don't set thresholds from guesses. Run profiles for a few weeks first, read the observed `min`, `max`, and `stddev`, then set rules from what you see.

**Use profiles to inform thresholds:**

```sql
-- Query profiles to understand your data
SELECT
  MIN(value_number) AS min_observed,
  MAX(value_number) AS max_observed,
  AVG(value_number) AS typical,
  STDDEV(value_number) AS stddev
FROM _check_profiles
WHERE table_name = 'warehouse.analytics.orders'
  AND profile_type = 'row_count'
  AND to_timestamp(profiled_at/1000) >= CURRENT_DATE - INTERVAL '90 days';

-- Set threshold as: typical ± 3*stddev
```

This gives you data-driven thresholds instead of wild guesses.

### Integration strategy

**Layer validation:**

```sql
-- LAYER 1: Audits (critical - blocks)
-- Stop bad data at the door
MODEL (
  name analytics.orders,
  assertions (
    not_null(columns := (order_id, customer_id)),
    unique_values(columns := (order_id))
  )
);
```

```yaml
# LAYER 2 + 3: Data Quality rule pack (monitoring + observation)
# dq/orders.yml
# Profiles observe trends, rules warn on issues. Neither blocks the model.
kind: dq
name: orders_dq
depends_on: analytics.orders

profiles:
  - order_count
  - revenue
  - customer_tier

rules:
  - row_count between 5000 and 15000:
      name: order_count_in_range
      dimension: completeness

  - change for row_count >= -30%:
      name: order_count_stable
      dimension: timeliness
```

Three layers, each with a clear job: assertions stop bad rows, Data Quality rules raise non-blocking warnings, and profiles record what "normal" looks like. The two monitoring layers share the same `kind: dq` file, so a single file describes everything Vulcan should watch for one model.

## Troubleshooting

### Rule failures

#### Investigate a failed rule

When a rule fails, you'll want to dig into why:

```bash
# Run a specific rule with verbose output
vulcan check --select analytics.customers.invalid_emails --verbose
```

Shows more details about what went wrong.

#### Query failed samples

If your rule captures samples (like `failed rows` rules do), you can query them:

```sql
-- Get samples from last failed run
SELECT *
FROM check_samples
WHERE check_name = 'invalid_emails'
  AND status = 'failed'
ORDER BY executed_at DESC
LIMIT 10;
```

This shows you actual rows that failed for debugging.

### Performance Issues

#### Slow rule queries

**Problem:** A rule takes too long to run.

**Solution 1: Add filters**

```yaml
# Slow: scans entire table
kind: dq
name: orders_dq
depends_on: analytics.orders

rules:
  - failed rows:
      dimension: validity
      fail query: |
        SELECT * FROM analytics.orders
        WHERE email NOT LIKE '%@%'

# Fast: pack-level filter scopes everything to recent data
kind: dq
name: orders_dq
depends_on: analytics.orders

filter: "order_date >= CURRENT_DATE - INTERVAL '30 days'"

rules:
  - failed rows:
      dimension: validity
      fail query: |
        SELECT * FROM analytics.orders
        WHERE email NOT LIKE '%@%'
```

Filtering reduces the amount of data the rule needs to scan, which makes it faster.

**Solution 2: Add indexes**

```sql
-- Add index on frequently checked columns
CREATE INDEX idx_orders_email ON analytics.orders(email);
CREATE INDEX idx_orders_order_date ON analytics.orders(order_date);
```

Indexes help queries run faster, especially for `failed rows` rules that filter on specific columns.

### False Positives

#### Threshold too strict

**Problem:** Rule fails during normal variance.

```yaml
# Too strict: exact match is unrealistic
kind: dq
name: orders_dq
depends_on: analytics.orders

rules:
  - row_count = 10000:        # Exact match
      dimension: completeness

# Allow variance: more realistic
kind: dq
name: orders_dq
depends_on: analytics.orders

rules:
  - row_count between 9000 and 11000:   # ±10% variance
      dimension: completeness
```

Real data has variance. Strict thresholds just produce false positives.

#### Use anomaly detection instead

Sometimes strict thresholds aren't the right approach:

```yaml
# Replace strict threshold with ML-based detection
kind: dq
name: orders_dq
depends_on: analytics.orders

rules:
  - anomaly detection for row_count:
      name: row_count_anomaly
      dimension: accuracy
```

Anomaly detection learns what's normal and adapts to variance, which reduces false positives.

## Summary

Data Quality rule packs give you a way to monitor data quality over time without blocking your models. Here's what we covered:

### Core Concepts

**1. Data Quality Rule Packs**

* YAML files in `dq/` with `kind: dq`
* One pack per file, targeting a single model via `depends_on:`
* Top-level fields: `kind`, `name`, `depends_on`, optional `filter:` and `profiles:`, then `rules:`
* Non-blocking (don't stop models)
* Track trends over time
* Integrate with Activity API

**2. Rule Forms and Attributes**

* Shorthand: bare expression (`- missing_count(col) = 0`)
* Full form: expression as YAML key with flat metadata block (`name`, `dimension`, `description`, `filter`, `warn`, `fail`, `warn_only`, `tags`, `owner`, `severity`)
* `failed rows` rules use `fail query: |` and optional `samples limit:`

**3. Rule Types**

* Missing data rules (`missing_count`, `missing_percent`)
* Row count rules (`row_count`)
* Duplicate rules (`duplicate_count`)
* Failed rows (SQL-based, flexible)
* Anomaly detection (ML-based, learns from history)
* Change monitoring (compare to previous runs)

**4. Data Profiling**

* Automatic statistical metric collection
* Enabled via the `profiles:` list at the top of a `kind: dq` file
* Stored in `_check_profiles` table
* Observe patterns without validation
* Inform rule threshold selection

**5. Data Quality Strategy**

* **Assertions**: Critical, blocking (stop bad data)
* **Data Quality rule packs**: Monitoring, non-blocking (watch for problems)
* **Profiles**: Observation, tracking (understand what's normal)

Start simple. Use profiles to understand your data, then write rules based on what you learn. If a rule is throwing too many false positives, adjust the threshold or switch to anomaly detection. The goal is better data quality, not perfect rule scores.
