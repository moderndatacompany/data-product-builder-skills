# Orders360 (VDE Enabled) — `snowflake/easy/orders360-vdetrue`

Compact Snowflake Orders360 data product with **Virtual Data Environments
(`vde: true`)** turned on. Materializes into the **`DEMODB`** schema.

## What this DP demonstrates

- **Seed → dimension → fact** in three models.
- **All Vulcan functionalities** at a small scale: `audits/`, `tests/`,
  `models/dq/`, `models/semantics/`, `models/metrics/`, `seeds/`.
- **VDE on**: every `vulcan plan` materializes into an isolated virtual schema
  (e.g. `DEMODB__dev_<branch>`) before promotion to `DEMODB`. Safe for previews
  and CI without touching production.

## Domain

`sales_operations`

## Counts

`M=3 · Py=0 · S=3 · C=3 · A=1 · T=2 · Sd=1`

| Asset | Count | Notes |
|-------|-------|-------|
| Models | 3 | `customer_segments` (SEED), `customers` (FULL), `orders` (INCREMENTAL_BY_TIME_RANGE) |
| Semantic models | 3 | one per model |
| Business metrics | 4 | total_customers, total_orders, total_revenue, average_order_value |
| DQ check files | 3 | one per model |
| Audits | 1 | `validate_customer_id` |
| Tests | 2 | `test_customers`, `test_orders` |
| Seeds | 1 | `customer_segments.csv` (segment lookup) |

## Models

| Model | Kind | Schema | Description |
|-------|------|--------|-------------|
| `customer_segments` | `SEED` | `DEMODB.VDETRUE.CUSTOMER_SEGMENTS` | Static lookup of segment tier + discount rate, loaded from `seeds/customer_segments.csv` |
| `customers` | `FULL` | `DEMODB.VDETRUE.CUSTOMERS` | Customer dimension enriched with segment tier and discount via left-join on the seed |
| `orders` | `INCREMENTAL_BY_TIME_RANGE` (time_column `ORDER_DATE`) | `DEMODB.VDETRUE.ORDERS` | Orders fact, incrementally loaded by order date |

## Output models you'd query

`DEMODB.VDETRUE.CUSTOMER_SEGMENTS`, `DEMODB.VDETRUE.CUSTOMERS`, `DEMODB.VDETRUE.ORDERS`

## Hierarchy

Flat — models + semantics + dq + metrics + audits + tests side-by-side, identical
in shape to the reference [`snowflake-sales-01`](../snowflake-sales-01/) DP but
trimmed to 3 models and with the seed wired in.

## Key differences vs `snowflake-sales-01`

| Aspect | `snowflake-sales-01` | `orders360-vdetrue` |
|--------|----------------------|---------------------|
| `vde` | `false` | **`true`** |
| Schema | `SALES.*` | **`DEMODB.VDETRUE.*`** |
| Models | 3 (`customers`, `orders`, `products`) | 3 (`customer_segments`, `customers`, `orders`) |
| Seeds | none | **`customer_segments.csv`** |
| Joins in semantics | customers ↔ orders ↔ products | customers ↔ orders ↔ customer_segments |
| Tests | 3 (`customers`, `orders`, `products`) | 2 (`customers`, `orders`) — seed loads from CSV directly |

## Local run

```bash
# from this folder
vulcan info             # verify connection
vulcan plan             # creates DEMODB__dev_<branch> (VDE) and shows the diff
vulcan plan --auto-apply
vulcan run              # runs orders incrementally
```

More: [Vulcan Documentation](https://tmdc-io.github.io/vulcan-book/).
