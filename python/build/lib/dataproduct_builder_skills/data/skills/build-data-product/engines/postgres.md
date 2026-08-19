# Postgres

## Identifier casing

Lowercase snake_case throughout — table names, column names,
`column_descriptions` keys, semantic `dimensions`/`measures`/`segments`
names. Postgres folds unquoted identifiers to lowercase, so this is also
the safe default if the source table casing is unknown.

## Physical models (`models/*.sql`)

- No explicit `columns()` block needed — types are inferred from the SELECT.
  Only add `columns()` if a column's inferred type is ambiguous (e.g. a
  literal `NULL` column).
- Casts are optional when the source is already typed (e.g. a seed with a
  typed CSV). If the source is untyped text, cast in the SELECT with
  `col::TYPE AS col` — Postgres's `::` cast operator is idiomatic here.
- Time-series facts default to `INCREMENTAL_BY_TIME_RANGE(time_column ...)`
  with `start` set and a `WHERE <time_col> BETWEEN @start_date AND @end_date`
  filter in the SELECT.

## Semantic layer (`models/semantics/*.yml`)

Date/time functions seen in `segments:`/measure `expression:` fields — use
these, not another engine's syntax:

| Need | Postgres syntax |
|---|---|
| Last N days | `CURRENT_DATE - INTERVAL 'N days'` |
| Truncate to day/week/month | `DATE_TRUNC('day', col)` |
| Current date | `CURRENT_DATE` |
| Add/subtract days | `col + INTERVAL 'N days'` / `col - INTERVAL 'N days'` |

No other quirks — this is the reference dialect the other engine notes are
diffed against.

## DQ, audits, tests

Portable — no engine-specific handling needed. `fail query` bodies using
only ANSI comparisons/`IS NULL` run unmodified.
