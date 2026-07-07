# Orders360 (VDE Disabled) — `snowflake/easy/orders360-vdefalse`

Rich, layered Snowflake sales analytics data product. **`vde: false`**, **no
semantics**, **no seeds**. Materializes into the **`SALES_ANALYTICS`** schema.

## What this DP demonstrates

- A **5-model layered build** on Snowflake: dimensions, a fact, a curated join,
  and an aggregate, all powered by plain SQL.
- **All Vulcan SQL-side functionalities** at scale: rich MODEL DDL with
  `column_descriptions` / `column_tags` / `column_terms`, `assertions`,
  `models/dq/`, `audits/`, `tests/`.
- **`vde: false`** so each applied plan writes directly into
  `SALES_ANALYTICS`. No virtual schema preview - use this DP as the reference
  for teams that want zero abstractions.

## Domain

`sales_operations`

## Counts

`M=5 · Py=0 · S=0 · C=5 · A=3 · T=5 · Sd=0 · Sem=0 · Met=0`

| Asset | Count | Notes |
|-------|-------|-------|
| Models | 5 | `customers`, `products` (FULL dims); `orders` (INCREMENTAL fact); `customer_orders` (FULL join); `daily_sales_summary` (INCREMENTAL aggregate) |
| Semantic models | 0 | omitted by design |
| Business metrics | 0 | omitted by design (require semantics) |
| DQ check files | 5 | one per model |
| Audits | 3 | `validate_customer_id`, `validate_order_id`, `validate_product_id` |
| Tests | 5 | one per model |
| Seeds | 0 | omitted by design |

## Models

| Model | Kind | Schema | Upstream | Purpose |
|-------|------|--------|----------|---------|
| `customers` | `FULL` | `DEMODB.VDEFALSE.CUSTOMERS` | `VULCAN.RAW.CUSTOMERS` | Customer dimension with normalised name, email, address line, segment, status, loyalty score |
| `products` | `FULL` | `DEMODB.VDEFALSE.PRODUCTS` | `VULCAN.RAW.PRODUCTS` | Product catalog dimension with category, brand, price, cost, stock, rating |
| `orders` | `INCREMENTAL_BY_TIME_RANGE` on `ORDER_DATE` | `DEMODB.VDEFALSE.ORDERS` | `VULCAN.RAW.ORDERS` | Orders fact, daily incremental load |
| `customer_orders` | `FULL` | `DEMODB.VDEFALSE.CUSTOMER_ORDERS` | `DEMODB.VDEFALSE.CUSTOMERS` + `DEMODB.VDEFALSE.ORDERS` | Curated join exposing customer attributes alongside each order |
| `daily_sales_summary` | `INCREMENTAL_BY_TIME_RANGE` on `SALES_DATE` | `DEMODB.VDEFALSE.DAILY_SALES_SUMMARY` | `DEMODB.VDEFALSE.ORDERS` | Daily aggregate of order count, unique customers, revenue, AOV, tax, shipping |

## Lineage

```text
VULCAN.RAW.CUSTOMERS  ──►  DEMODB.VDEFALSE.CUSTOMERS  ──┐
                                                        ├──►  DEMODB.VDEFALSE.CUSTOMER_ORDERS
VULCAN.RAW.ORDERS     ──►  DEMODB.VDEFALSE.ORDERS  ─────┤
                                                        └──►  DEMODB.VDEFALSE.DAILY_SALES_SUMMARY

VULCAN.RAW.PRODUCTS   ──►  DEMODB.VDEFALSE.PRODUCTS         (dimension - referenced by SQL consumers)
```

## Key differences vs the other two `snowflake/easy/` DPs

| Aspect | `snowflake-sales-01` | `orders360-vdetrue` | `orders360-vdefalse` (this) |
|--------|----------------------|---------------------|-----------------------------|
| `vde` | `false` | `true` | **`false`** |
| Schema | `SALES.*` | `DEMODB.*` | **`DEMODB.VDEFALSE.*`** |
| Models | 3 | 3 | **5 (layered)** |
| Semantics | yes (3) | yes (3) | **none** |
| Metrics | yes (12) | yes (4) | **none** |
| Seeds | none | 1 (12 segments) | **none** |
| DQ | 3 | 3 | **5** |
| Audits | 1 | 1 | **3** |
| Tests | 3 | 2 | **5** |

## Local run

```bash
# from this folder
export SNOWFLAKE_ACCOUNT="your_account.region"
export SNOWFLAKE_USER="your_user"
export SNOWFLAKE_PASSWORD="your_password"
export SNOWFLAKE_ROLE="your_role"
export SNOWFLAKE_WAREHOUSE="your_warehouse"

vulcan info             # verify connection
vulcan plan             # writes directly to SALES_ANALYTICS (no VDE)
vulcan plan --auto-apply
vulcan run              # incrementally loads orders + daily_sales_summary
```

More: [Vulcan Documentation](https://tmdc-io.github.io/vulcan-book/).
