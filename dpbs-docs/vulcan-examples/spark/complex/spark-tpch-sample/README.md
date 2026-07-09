# Spark TPC-H Sample (`complex/spark-tpch-sample`)

TPC-H benchmark data product at SF1 scale with the **largest single-DP check coverage** in the Spark catalog (23 quality checks).

**Domain:** system / benchmark

**Counts:** `M=16 · Py=0 · S=3 · C=23 · A=0 · T=0 · Sd=0`

**Output models you'd query:** `tpch_customer_sf1, tpch_lineitem_sf1, tpch_orders_sf1, …` plus aggregates like `region_daily_orders_sf1, emb_active_customers_sf1`.

**Hierarchy:** flat.

**Layout:**
- `config.yaml` — Vulcan config (Snowflake gateway, state on statestore, object store on minio, linter, model defaults)
- `models/` — TPC-H base (VIEW): customer, lineitem, nation, orders, part, partsupp, region, supplier; orders = `INCREMENTAL_BY_TIME_RANGE`, nation = `SCD_TYPE_2_BY_TIME`, part = `SCD_TYPE_2_BY_COLUMN`; staging VIEW; `view_order_line_summary`; `full_customer_orders_sf1` (FULL); `customer_snapshot_sf1` (INCREMENTAL_BY_UNIQUE_KEY); `region_daily_orders_sf1` (INCREMENTAL_BY_PARTITION); `seed_segment_sf1` (SEED); Python FULL models in `python_models/`
- `audits/` — Custom audits (e.g. `assert_positive_order_keys`)
- `models/dq/`, `models/semantics/`, `tests/` — Data quality checks, semantics, unit tests
- `macros/`, `linter/`, `seeds/` — Macros, custom linter rules, seed CSV

Explore this when you want a TPC-H benchmark example with **maximal data-quality check coverage** to evaluate Vulcan's `models/dq/` capability.
