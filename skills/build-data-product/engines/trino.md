# Trino

## Identifier casing

Lowercase snake_case — same convention as Postgres/Databricks.

## Physical models (`models/*.sql`)

- Declares an explicit `columns()` block with native Trino types
  (`VARCHAR`, `DECIMAL(38,0)`, `INTEGER`) rather than relying on inferred
  types — do this for Trino models even though Postgres/Databricks skip it.
- No `::` casts in the SELECT — the `columns()` contract handles typing.
- The reviewed example uses `INCREMENTAL_BY_UNIQUE_KEY(unique_key
  order_id)` instead of `INCREMENTAL_BY_TIME_RANGE`, with no `start` and no
  `WHERE ... BETWEEN @start_date AND @end_date` filter. This is a modeling
  choice in that example (merge-on-key vs. time-partitioned load), not a
  Trino limitation — decide explicitly per model which load strategy fits;
  don't assume Trino requires unique-key merge.
- External/Iceberg-catalog tables referenced in `inputs.yaml` /
  `external_models.yaml` often need fully-qualified **quoted** identifiers
  when the catalog name isn't a bare lowercase word, e.g.
  `'"testawslhnewdepot"."tpch_sf1v1"."customer"'` — quote each of the three
  parts individually if the catalog/schema name needs it.

## Semantic layer (`models/semantics/*.yml`)

Date/time functions:

| Need | Trino syntax |
|---|---|
| Last N days | `CURRENT_DATE - INTERVAL '7' DAY` — note the quoted **numeral** with unquoted unit (`INTERVAL 'N' DAY`), which differs from Postgres's quoted phrase `INTERVAL 'N days'` |
| Truncate to day/week/month | `DATE_TRUNC('day', col)` |
| Current date | `CURRENT_DATE` |

Don't copy Postgres's `INTERVAL '7 days'` form verbatim — Trino wants the
number and unit as separate tokens (`INTERVAL '7' DAY`).

## DQ, audits, tests

Portable — no engine-specific handling needed.
