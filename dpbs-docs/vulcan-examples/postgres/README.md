# PostgreSQL Data Products — Vulcan Examples

A catalog of **Vulcan data products** that run on **PostgreSQL**. PostgreSQL is the canonical learning ground for Vulcan: two minimal *easy* variants and four progressively richer *complex* DPs covering the full orders-analytics pipeline plus customer intelligence.

Counts legend: `M` = SQL models · `S` = Semantic models · `C` = Checks · `A` = Audits · `T` = Tests · `Sd` = Seeds.

---

## complex/

### `complex/order-migration` — Order Migration (richest postgres DP)
**Domain:** engineering / sales_operations
**About:** End-to-end orders-analytics DP with the **most complete folder layout** of any postgres DP — raw seed models, raw layer, root-level transformed entities, curated facts/dimensions, aggregated business models, custom Python macros, custom Python linter rules, and a full quality stack.
**Use cases:** daily & weekly sales reporting · customer segmentation & RFM · sales-funnel conversion tracking · product performance · regional sales · inventory & shipment tracking · cross-engine migration reference.
**Hierarchy:** `seeds → models/seeds → models/raw → models/{shipments, returns, products, payments, orders, order_items, customers} (root-level) → models/curated/ → models/aggregated/ → semantics`.
**Counts:** `M=29 (7 seed + 9 raw + 7 root + 4 curated + 2 aggregated) · S=13 (largest postgres semantic catalog) · C=18 (largest postgres check coverage) · A=2 · T=8 · Sd=7 csv`.
**Output models you'd query:** `fct_daily_sales, fct_weekly_sales, dim_customer_profile, dim_product_profile, sales_funnel_analysis, rfm_customer_segmentation` plus root-level `customers / orders / order_items / products / payments / returns / shipments`.
**Extras:** Python `macros/orders360.py` (Vulcan *Macros* component), `linter/linters.py` (custom Python lint rules), seed generator under `scripts/`, `external_models.yaml`, `domain-resource.yaml`.
**Explore this when:** you want the **richest postgres reference** that exercises macros, custom linter, multi-layer hierarchy, and full quality stack at once.

---

### `complex/orders-analytics-neptune` — Orders Analytics Platform V1
**Domain:** sales_operations
**About:** Production-style orders-analytics DP with a clean bronze→silver→gold split and the largest semantic catalog in postgres after `order-migration`.
**Use cases:** daily & weekly sales reporting · customer segmentation & RFM · sales-funnel conversion tracking · product performance · regional sales · inventory & shipment tracking.
**Hierarchy:** `seeds → bronze → silver (fct_*, dim_*) → gold (analyses) → semantics`.
**Counts:** `M=15 (8 bronze + 4 silver + 3 gold) · S=8 · C=12 · A=1 (under `audits00/`) · T=2 · Sd=9 csv`.
**Output models you'd query:** `fct_daily_sales, fct_weekly_sales, dim_customer_profile, dim_product_profile, sales_funnel_analysis, rfm_customer_segmentation, category_performance_analysis`.
**Extras:** `linter/linters.py`, seed generator under `scripts/`, `domain-resource.yaml`, **`artefacts/`** folder with DataOS-specific resource manifests, `queries_and_perspectives.md` and `rest_queries_and_perspectives.md` query catalogs.
**Explore this when:** you want a production-style bronze→silver→gold postgres DP with **DataOS deployment artefacts** included.

---

### `complex/customer-intelligence` — Customer Intelligence (CLV + RFM)
**Domain:** sales_operations
**About:** Postgres variant of the customer-intelligence demo joining orders, transactions, and customer data into RFM segmentation + Customer Lifetime Value facts.
**Hierarchy:** `seeds → models/seeds → models/gold (fct_customer_rfm, fct_customer_lifetime_value)`.
**Counts:** `M=5 (2 gold + 3 seed) · S=2 · C=2 · A=0 · T=0 · Sd=3 csv`.
**Output models you'd query:** `fct_customer_rfm, fct_customer_lifetime_value`.
**Explore this when:** you want a compact CLV + RFM demo on postgres.

---

### `complex/ordersanalyticsv3` — Orders Analytics V3
**Domain:** engineering
**About:** Variant of the orders pipeline where transformations live under `raw/`, `curated/`, and `aggregated/` instead of bronze/silver/gold. Includes Python macros, custom linter, and full quality stack.
**Use cases:** daily & weekly sales reporting · customer segmentation & RFM · sales-funnel conversion tracking · product performance · regional sales · inventory & shipment tracking.
**Hierarchy:** `seeds → models/raw → models/curated → models/aggregated → semantics`.
**Counts:** `M=15 (9 raw + 4 curated + 2 aggregated) · S=7 · C=18 (largest single-DP postgres check coverage tied with order-migration) · A=2 · T=8 · Sd=7 csv`.
**Output models you'd query:** `fct_daily_sales, fct_weekly_sales, dim_customer_profile, dim_product_profile, sales_funnel_analysis, rfm_customer_segmentation`.
**Extras:** Python `macros/orders360.py`, `linter/linters.py`, seed generator under `scripts/`, `external_models.yaml`, `domain-resource.yaml`.
**Explore this when:** you want the **raw → curated → aggregated** naming variant (instead of medallion bronze/silver/gold), with macros and a custom linter.

---

## easy/

### `easy/orders360` — Orders 360 (depot/local)
**Domain:** sales
**About:** Minimal Orders 360 reference where Vulcan reads CSV seeds and exposes them through a semantic layer — no `models/` folder, semantics declared directly on top of the seeds.
**Counts:** `M=0 (semantics on top of seeds) · S=3 · C=3 · A=1 · T=3 · Sd=3 csv`.
**Output models you'd query:** `customers, orders, products`.
**Explore this when:** you want the **smallest possible postgres DP** that still demonstrates audits + checks + tests + semantics on raw CSV seeds.

---

### `easy/orders360-mini` — Orders 360 Mini (daily-sales aggregation)
**Domain:** sales
**About:** Lightweight pipeline that ingests three raw CSVs (customers, orders, products) and produces a single `daily_sales` aggregation with a metric catalog — designed as the *user-story* teaching example.
**Counts:** `M=4 (1 daily_sales + 3 seed) · S=5 (1 daily_sales + 1 metrics + 3 seed semantics) · C=1 · A=1 (`positive_values.sql`) · T=1 (`test_daily_sales`) · Sd=3 csv`.
**Output models you'd query:** `daily_sales` (with `total_orders`, `total_daily_revenue`, etc.).
**Extras:** `README.md` written as a user story — best onboarding doc in the repo.
**Explore this when:** you want the **clearest narrative example** of how a Vulcan DP answers business questions ("How many orders yesterday?", "Revenue last week?", "Days exceeding $100 target?").

---

## At-a-glance summary

| Tier    | DP                       |  M  |  S |  C |  A |  T | Sd | Hierarchy                                       | Best for                                  |
|---------|--------------------------|----:|---:|---:|---:|---:|---:|-------------------------------------------------|-------------------------------------------|
| complex | order-migration          |  29 | 13 | 18 |  2 |  8 |  7 | seeds → raw → root → curated → aggregated       | Richest postgres DP (macros + linter)     |
| complex | orders-analytics-neptune |  15 |  8 | 12 |  1 |  2 |  9 | bronze → silver → gold                          | Production with DataOS artefacts          |
| complex | customer-intelligence    |   5 |  2 |  2 |  0 |  0 |  3 | seeds → gold                                    | CLV + RFM on postgres                     |
| complex | ordersanalyticsv3        |  15 |  7 | 18 |  2 |  8 |  7 | raw → curated → aggregated                      | Naming-variant + macros                   |
| easy    | orders360                |   0 |  3 |  3 |  1 |  3 |  3 | seeds → semantics (no models/)                  | Smallest reference                        |
| easy    | orders360-mini           |   4 |  5 |  1 |  1 |  1 |  3 | daily_sales aggregation                         | Best teaching narrative                   |

---

## Pick a DP by your use case

| If your use case is… | Start with |
|---|---|
| Richest postgres reference (macros + custom linter + every layer) | `complex/order-migration` |
| Production bronze → silver → gold + DataOS artefacts | `complex/orders-analytics-neptune` |
| Customer lifetime value + RFM on postgres | `complex/customer-intelligence` |
| Raw → curated → aggregated naming variant | `complex/ordersanalyticsv3` |
| Smallest postgres DP (seeds only, no models) | `easy/orders360` |
| Best onboarding / user-story teaching example | `easy/orders360-mini` |

---