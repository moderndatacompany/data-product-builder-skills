# MSSQL (SQL Server)

## Identifier casing

Lowercase snake_case — same convention as Postgres/Databricks/Trino.

## Physical models (`models/*.sql`)

- Declares an explicit `columns()` block with native T-SQL types
  (`VARCHAR(10)`, `DECIMAL(10,2)`, `INT`) rather than relying on inferred
  types — same approach as Trino.
- No `::` casts — T-SQL has never supported the `::` operator. Use
  `CAST(col AS TYPE)` if a cast is genuinely needed. Same portability trap
  as Databricks/Spark for any shared `macros/*.py` that emits `::FLOAT`
  etc. — it will fail here too.
- Time-series facts default to `INCREMENTAL_BY_TIME_RANGE(time_column ...)`
  with `start` and a `WHERE ... BETWEEN @start_date AND @end_date` filter —
  same shape as Postgres.

## Semantic layer (`models/semantics/*.yml`)

Date/time functions:

| Need | MSSQL syntax |
|---|---|
| Last N days | `DATEADD(DAY, -N, CAST(GETDATE() AS DATE))` |
| Current date (date only, no time) | `CAST(GETDATE() AS DATE)` |
| Truncate to day | `CAST(col AS DATE)` (no native `DATE_TRUNC`; use `DATEADD(month, DATEDIFF(month, 0, col), 0)`-style arithmetic for week/month truncation) |

Don't port Postgres/Snowflake's `CURRENT_DATE - INTERVAL 'N days'` or
Databricks's `DATE_SUB(CURRENT_DATE(), N)` — neither parses on T-SQL.

## DQ, audits, tests

Portable — no engine-specific handling needed.
