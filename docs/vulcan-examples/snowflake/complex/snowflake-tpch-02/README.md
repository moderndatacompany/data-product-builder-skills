# Snowflake TPC-H Demo (`complex/snowflake-tpch-02`)

Reference data product that points 8 VIEW models at `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.*`. Benchmark / smoke-test rather than a real business use case — the cleanest 1:1:1 (model : semantic : check) example in the Snowflake catalog.

**Domain:** system / benchmark

**Counts:** `M=8 · Py=0 · S=8 · C=8 · A=0 · T=0 · Sd=0`

**Output models you'd query:** TPCH `customer, lineitem, nation, orders, part, partsupp, region, supplier`.

**Hierarchy:** flat (`models/` + `models/dq/` + `models/metrics/` + `models/semantics/`).

**Extras:** `keys/` folder for key-pair auth setup; 18 pre-built metric YAMLs (`avg_acctbal`, `gross_revenue`, `total_lineitems`, …).

Explore this when you want the canonical TPC-H reference for Snowflake plus a key-pair auth recipe.
