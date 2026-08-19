# Spark

Applies to Spark/Iceberg lakehouse projects (typically DataOS depot-backed —
`gateways.default.connection: {type: depot, address: dataos://<depot>}`
rather than raw host/port creds).

## Identifier casing

No single enforced convention — Spark inherits the source's casing. Real
examples show TPC-H-sourced models keeping UPPERCASE source columns
(`O_ORDERKEY`, `L_EXTENDEDPRICE`) while the schema/table path stays
lowercase (`s3lhyddepot.tpch_analytics.order_line_revenue`). Match whatever
casing the upstream source table already uses — don't force lowercase or
uppercase across the board like Postgres/Snowflake.

## Physical models (`models/*.sql`)

- No explicit `columns()` block, no casts — same as Databricks (Spark SQL
  family). Same `::` cast caveat as Databricks applies: use
  `CAST(col AS TYPE)`, not `col::TYPE`.
- Model kind is not automatically incremental-by-time in these examples —
  several gold aggregations use `kind FULL` even for daily-refreshed
  outputs. Decide FULL vs INCREMENTAL the normal way (data volume /
  refresh pattern), don't default to time-range incremental just because
  other engines' examples do.
- `grain (COL)` — parens are used even for a single-column grain in these
  examples; both `grain COL` and `grain (COL)` are valid, this is a style
  choice, not a Spark-specific requirement.

## Semantic layer (`models/semantics/*.yml`)

Date/time functions — same Spark SQL family as Databricks (`DATE_SUB`,
`CURRENT_DATE()` with parens, `DATE_TRUNC`) — see
[databricks.md](databricks.md)'s table.

`ai_context` is used more heavily in Spark examples than other engines —
routinely present at both the model level and on individual measures, not
just as an afterthought. Treat this as validation that the `ai_context`
step in `design-data-product` Step 2.6 is worth doing thoroughly here, not
as a Spark-specific requirement.

One example was seen with an empty `dimensions: includes:` (no dimensions
listed) on a measures-only semantic file — don't copy this as a pattern;
`build-data-product`'s own rule stands: `dimensions:` must be non-empty and
include every column a measure `expression` references.

## DQ, audits, tests

No DQ/audit/test examples were found alongside the Spark semantic examples
reviewed — fall back to the general Vulcan syntax rules and Postgres's
portable patterns; nothing Spark-specific has been observed to differ.
