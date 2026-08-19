# Fabric (Microsoft Fabric Warehouse)

Same SQL surface as [mssql.md](mssql.md) — Fabric's warehouse endpoint is
T-SQL (accessed over ODBC in these examples: `driver_name: "ODBC Driver 18
for SQL Server"`). Read `mssql.md` for the date/time function table and the
`::` cast trap; this file only notes what actually differs.

## Identifier casing

Lowercase snake_case — same as MSSQL.

## Physical models (`models/*.sql`)

Identical pattern to MSSQL: explicit `columns()` block with native T-SQL
types, no `::` casts (use `CAST(col AS TYPE)`), `INCREMENTAL_BY_TIME_RANGE`
with `start` + `BETWEEN @start_date AND @end_date` for time-series facts.

## Semantic layer (`models/semantics/*.yml`)

Same date/time functions as MSSQL — `DATEADD(DAY, -N, CAST(GETDATE() AS
DATE))` for "last N days", etc. See [mssql.md](mssql.md)'s table.

## DQ, audits, tests

Portable, same as MSSQL. One example difference observed (not a syntax
constraint, just what that example's author chose): the reviewed Fabric
`checks/orders.yml` asserted `total_amount <= 0 OR quantity <= 0 OR
unit_price <= 0` (a positive-value check) rather than the negative-value
check (`quantity < 0 OR ... < 0`) used in the Postgres/MSSQL/Trino/etc.
examples for the same model — don't read this as a Fabric requirement, just
pick whichever check direction matches the actual business rule and verify
the operator direction against the rule's plain-English name.
