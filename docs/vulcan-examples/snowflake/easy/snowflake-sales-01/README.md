# Snowflake Sales Analytics (`easy/snowflake-sales-01`)

Compact sales-analytics data product on Snowflake with three dimensions / facts (customers, orders, products).

**Domain:** sales_operations

**Use cases:**
- Customer profile analysis
- Product catalog management
- Sales transaction reporting
- Loyalty & segment analytics
- Product performance & pricing
- Order volume & discount tracking

**Counts:** `M=3 · Py=0 · S=3 · C=3 · A=1 · T=3 · Sd=0`

**Output models you'd query:** `customers, orders, products`

**Hierarchy:** flat — models + semantics + checks + audits + tests side by side.

This is the best teaching template in the Snowflake catalog — the only DP that ships `audits/` + `tests/` + `models/dq/` + `models/semantics/` together at small scale.
