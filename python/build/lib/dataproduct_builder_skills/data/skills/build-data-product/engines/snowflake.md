# Snowflake

## Identifier casing

UPPERCASE throughout — table name, schema, columns, `column_descriptions`
keys, `column_tags`, `column_terms`, and every semantic-layer object
reference (`{orders.ORDER_ID}`, `{orders.TOTAL_AMOUNT}`). Semantic
measure/segment *names themselves* (`total_orders`, `recent_orders`) stay
lowercase business names — only the underlying column/model references are
uppercase. Snowflake folds unquoted identifiers to uppercase, so mixed-case
authoring silently produces mismatches at plan time.

FQNs are commonly 3-part (`VULCAN.RAW.ORDERS`), not 2-part — carry the
database segment through models, semantics, and test `inputs:` keys
consistently.

## Physical models (`models/*.sql`)

- Cast every column explicitly in the SELECT with `col::TYPE AS COL`,
  including inside `WHERE` predicates — e.g.
  `WHERE ORDER_DATE::DATE BETWEEN @start_date AND @end_date`. Snowflake
  examples treat the raw source as untyped and cast defensively rather than
  relying on a `columns()` contract.
- Time-series facts default to `INCREMENTAL_BY_TIME_RANGE(time_column ...)`,
  same shape as Postgres, just uppercase.

## Semantic layer (`models/semantics/*.yml`)

Date/time functions — same as Postgres (Snowflake supports ANSI interval
syntax), just applied to uppercase column refs:

| Need | Snowflake syntax |
|---|---|
| Last N days | `CURRENT_DATE - INTERVAL 'N days'` |
| Truncate to day/week/month | `DATE_TRUNC('day', COL)` |
| Current date | `CURRENT_DATE` |
| Add/subtract days | `DATEADD(day, -N, COL)` or `COL - INTERVAL 'N days'` |

## DQ, audits, tests

Structurally portable, but every column/table reference inside `fail
query:`, `AUDIT` SELECTs, and test `inputs:`/`outputs:` rows must be
uppercase to match the model — copying a lowercase example verbatim from
another engine will silently reference a nonexistent (differently-cased)
column.
