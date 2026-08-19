# Databricks

## Identifier casing

Lowercase snake_case throughout — same convention as Postgres.

## Physical models (`models/*.sql`)

- No explicit `columns()` block — types inferred from the SELECT, same as
  Postgres.
- No `::` casts. Databricks runs on Spark SQL, which does **not** support
  the `::` cast operator used by Postgres/Snowflake/Redshift — use
  `CAST(col AS TYPE)` if a cast is genuinely needed. This matters most when
  reusing a shared `macros/*.py` file across engines: a macro like
  `safe_divide` that emits `({denominator})::FLOAT` will fail on Databricks;
  the macro body needs a dialect-neutral `CAST(... AS FLOAT)` or a
  per-engine branch.
- Time-series facts default to `INCREMENTAL_BY_TIME_RANGE(time_column ...)`,
  same shape as Postgres.

## Semantic layer (`models/semantics/*.yml`)

Date/time functions — Spark SQL family, distinct from ANSI interval syntax:

| Need | Databricks syntax |
|---|---|
| Last N days | `DATE_SUB(CURRENT_DATE(), N)` — integer days, no `INTERVAL` keyword |
| Truncate to day/week/month | `DATE_TRUNC('day', col)` |
| Current date | `CURRENT_DATE()` — note the parens, unlike Postgres/Snowflake's bare `CURRENT_DATE` |
| Add days | `DATE_ADD(CURRENT_DATE(), N)` |

Do not port a Postgres/Snowflake `CURRENT_DATE - INTERVAL 'N days'` segment
expression here verbatim — it will fail to parse.

## DQ, audits, tests

Portable — no engine-specific handling needed.
