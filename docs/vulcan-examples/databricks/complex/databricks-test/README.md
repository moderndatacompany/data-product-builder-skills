# Databricks Subscription Usage Analytics (`complex/databricks-test`)

Subscription-based usage-analytics data product modelling users, subscriptions, usage events, and sessions across plan types — full-shape Databricks reference with seeds, models, semantics, checks, and audits.

**Domain:** subscriptions / saas

**Use cases:**
- Subscription usage tracking
- Plan-level revenue & engagement
- Session analytics
- User enrichment
- Subscription-usage cross-analysis

**Counts:** `M=8 (incl. 6 seed models) · Py=0 · S=6 (incl. metrics.yml) · C=3 · A=1 (`business_rules.sql`) · T=0 · Sd=5 csv`

**Output models you'd query:** `users, users_enriched, subscriptions, subscription_plans, usage_events, usage_sessions, subscription_usage_analysis`.

**Hierarchy:** `seeds → models/seeds → models/ (users, subscriptions, usage_events, usage_sessions, subscription_plans, subscription_usage_analysis) → semantics`.

**Extras:** `metrics.yml` declarative metrics file.

## Project Structure

```
.
├── config.yaml          # Vulcan configuration
├── models/              # SQL models
├── seeds/               # Seed data (CSV)
├── semantics/           # Semantic layer
├── checks/              # Data quality checks
├── audits/              # Audit queries
└── tests/               # Tests
```

## Databricks-specific behavior notes

A few Databricks engine quirks to be aware of when querying the semantic layer:

### 1. Column name truncation in SQL semantic queries

Databricks truncates column names to 16 characters when SQL semantic queries omit explicit aliases — measure columns end up as `measure_users_to`, `measure_subscrip`, `measure_subscrip_1`, etc.

REST semantic queries are not affected; SQL semantic queries should always alias measures explicitly:

```sql
measure(users.total_users) AS total_users
```

### 2. `timeDimensions` in REST queries

Using `timeDimensions` in REST queries can trigger:

```
"error": "DATA_MANIPULATION_DETECTED",
"message": "Data manipulation not allowed: Replace"
```

Databricks SQL endpoints restrict certain date/time manipulation operations.

### 3. Don't wrap expressions in double quotes in semantic YAML

YAML interprets outer double quotes as string delimiters — the contents end up as a literal string in the generated SQL instead of a boolean expression, producing errors like:

```
[JOIN_CONDITION_IS_NOT_BOOLEAN_TYPE] ... has the invalid type "STRING", expected "BOOLEAN"
```

```
[DATATYPE_MISMATCH.UNEXPECTED_INPUT_TYPE] ... has the type "STRING"
```

Use single quotes or no outer quotes for join / filter / measure expressions.
