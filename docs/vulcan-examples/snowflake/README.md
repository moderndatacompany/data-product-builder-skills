# Snowflake Data Products — Vulcan Examples

A catalog of **Vulcan data products** that run on **Snowflake**. Use this page to decide which DP fits your use case before you clone the folder.

Counts legend: `M` = SQL models · `Py` = Python models · `S` = Semantic models · `C` = Checks · `A` = Audits · `T` = Tests · `Sd` = Seeds.

---

## complex/

### `complex/sgws-web-analytics` — SGWS Web Analytics
**Domain:** engineering_analytics
**About:** Web + e-commerce analytics combining Adobe Analytics hit-level data with EFDP sales / order / customer / product data.
**Use cases:** web traffic & user-behavior analysis · customer journey & conversion tracking · checkout-funnel optimization · sales transaction reporting · product performance · customer segmentation & RFM · multi-channel sales attribution.
**Hierarchy:** `seeds → bronze → silver → gold → semantics` (full 4-layer medallion).
**Counts:** `M=76 · Py=0 · S=6 · C=6 · A=0 · T=0 · Sd=35`.
**Output models you'd query:** `web_analytics_gold.{SALES, CUSTOMER, ORDERS, PRODUCT, WEB_HEARTBEAT, ADOBE_CHECKOUT}` — 100+ measures in the semantic layer.
**Explore this when:** you want the richest end-to-end reference of a Vulcan DP on Snowflake.

---

### `complex/ldo` — Lenovo Device Operations
**Domain:** it_operations
**About:** Device-fleet operations DP processing telemetry, warranty, system updates, and license consumption with CDC patterns.
**Use cases:** device lifecycle & inventory tracking · license consumption & compliance · warranty status & expiration tracking.
**Hierarchy:** `seeds (with *_cdc + *_non_cdc twins) → flattend/`.
**Counts:** `M≈36 · Py=0 · S=16 (largest semantic catalog) · C=5 · A=0 · T=0 · Sd=30`.
**Output models you'd query:** `devices, battery, storage, system_update_v2, schedules_app, consumed_licenses, device_warranty, …`
**Explore this when:** you need CDC-style ingestion and the largest semantic catalog for an IT-ops use case.

---

### `complex/gensler-qualitrics-cu` — Qualtrics Survey Analytics
**Domain:** marketing_analytics
**About:** Survey-response analytics flattening Qualtrics JSON into question / respondent / survey models.
**Use cases:** employee engagement surveys · customer satisfaction tracking · office-space planning · department feedback aggregation · survey response-rate quality monitoring · question-level distribution.
**Hierarchy:** `raw → flattening (response/, questions/, survey_list/) → views → semantics`.
**Counts:** `M=16 · Py=1 · S=4 · C=4 · A=1 · T=0 · Sd=1`.
**Output models you'd query:** `survey_metrics, respondents, question_response_summary, active_surveys_detail`.
**Explore this when:** you need SQL + Python models, audits, and JSON flattening in one project.

---

### `complex/analytics-user-01` — User Engagement Analytics
**Domain:** sales_operations
**About:** Consumer-analytics events analyzed across product, hardware, and software dimensions for Power BI dashboards.
**Use cases:** device engagement across roll-up periods (7/30/90/180/365 days) · regional BU analytics · user segmentation · hardware component usage · software OS adoption · multi-tab views.
**Hierarchy:** sub-domain folders `models/{hardware_tab, product_tab, software_tab}/` + `flattened_main_base_table` + `models/{metrics, semantics, dq}/`.
**Counts:** `M=23 · Py=0 · S=4 · C=5 · A=1 · T=0 · Sd=3`.
**Output models you'd query:** `flattened_main_base_table, geo_mapping, model_brand_mapping, os_family` plus `hardware_*`, `product_*`, `software_*` groups.
**Extras:** `external_models.yaml` for source contracts, dedicated `models/dq/` quality folder.
**Explore this when:** you want sub-domain model organization plus external-model declarations for a Power BI–facing engagement DP.

---

### `complex/snowflake-tpch-02` — Snowflake TPC-H Demo
**Domain:** system / benchmark
**About:** Reference DP that points 8 VIEW models at `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.*`. Benchmark / smoke-test, not a business use case.
**Hierarchy:** flat (`models/` + `models/dq/` + `models/metrics/` + `models/semantics/`).
**Counts:** `M=8 · Py=0 · S=8 · C=8 · A=0 · T=0 · Sd=0`.
**Output models you'd query:** TPCH `customer, lineitem, nation, orders, part, partsupp, region, supplier`.
**Extras:** `keys/` folder for key-pair auth setup; 18 pre-built metric YAMLs (`avg_acctbal`, `gross_revenue`, `total_lineitems`, …).
**Explore this when:** you want the cleanest 1:1:1 (model : semantic : check) example plus a Snowflake key-pair auth recipe — the canonical TPC-H reference for Snowflake.

---

### `complex/techfab-production-ops` — TechFab Production Operations
**Domain:** manufacturing_operations
**About:** Manufacturing intelligence across 10 plants — production volume, equipment OEE, downtime, and quality metrics.
**Use cases:** production volume & efficiency · OEE analysis · quality (scrap / rework / first-pass yield) · downtime + MTTR/MTBF · plant benchmarking · shift productivity · preventive-maintenance planning · work-order cycle time.
**Hierarchy:** `seeds → silver → gold` + `models/dq/`.
**Counts:** `M=6 · Py=0 · S=2 · C=3 · A=0 · T=0 · Sd=2`.
**Output models you'd query:** `fct_production_daily, fct_equipment_oee`.
**Explore this when:** you need an industrial / IoT manufacturing analytics template.

---

### `complex/cobs` — Customer Order Behavior Segmentation
**Domain:** sales_operations
**About:** Behavioral analytics DP segmenting customers into 8 RFM-based cohorts (Outperformers, Web Loyalist, Promising, Newly Activated, Novice, Infrequent, Lapsed, Lost) with churn detection.
**Use cases:** RFM segmentation · churn prediction & at-risk detection · proof-product wallet share · marketing campaign targeting · customer lifecycle & retention.
**Hierarchy:** `seeds → models/{aggregated, ml}` + `yamls/` for RFM rule sets.
**Counts:** `M=6 · Py=0 (+ 7 utility scripts) · S=1 · C=2 · A=0 · T=0 · Sd=3`.
**Output models you'd query:** `rfm_customer_segments_ml, rfm_segment_1_month_data, rfm_segment_12_month_data`.
**Explore this when:** you want an ML-flavoured Vulcan DP with a documented business methodology.

---

### `complex/customer-intelligence` — Customer Intelligence (RFM + CLV)
**Domain:** sales_operations
**About:** Customer intelligence demo joining orders, transactions, and customer data into RFM segmentation + Customer Lifetime Value facts.
**Hierarchy:** `models/seeds → gold (fct_customer_rfm, fct_customer_lifetime_value)`.
**Counts:** `M=3 · Py=0 · S=2 · C=2 · A=0 · T=0 · Sd=1`.
**Output models you'd query:** `fct_customer_rfm, fct_customer_lifetime_value`.
**Explore this when:** you want a compact CLV + RFM demo using external source tables.

---

### `complex/delivery-performance` — Delivery Performance (Snowflake)
**Domain:** delivery_operations
**About:** Quick-commerce delivery performance DP for city SLA monitoring, customer-tier delay tracking, rider efficiency, and issue root-cause analysis.
**Hierarchy:** `seeds → models/seeds → bronze → silver → gold → python_models → semantics`.
**Counts:** `M=7 · Py=1 · S=4 · C=5 · A=0 · T=0 · Sd=1`.
**Output models you'd query:** `daily_delivery_kpis, delivery_issue_summary, customer_experience_kpis, rider_efficiency_kpis`.
**Explore this when:** you want the Snowflake sibling of the Spark `complex/delivery-performance` DP.

---

### `complex/ecommerce-digital-experience` — E-commerce Digital Experience
**Domain:** ecommerce
**About:** Digital-experience demo tracking user sessions, page views, and conversion across an e-commerce funnel.
**Counts:** `M=3 · Py=0 · S=2 · C=2 · A=0 · T=0 · Sd=1`.
**Explore this when:** you need a small e-commerce funnel example with semantic layer.

---

### `complex/quality-management-spc` — Quality Management (SPC)
**Domain:** quality_management
**About:** Statistical Process Control demo tracking control-chart metrics, capability indices, and defect tracking.
**Counts:** `M=3 · Py=0 · S=2 · C=2 · A=0 · T=0 · Sd=1`.
**Explore this when:** you need an SPC / control-chart example with semantics.

---

### `complex/supply-chain-inventory-optimization` — Supply Chain Inventory Optimization
**Domain:** supply_chain
**About:** Supply-chain inventory optimization demo tracking supplier performance, inventory levels, and reorder-point analytics.
**Counts:** `M=3 · Py=0 · S=2 · C=2 · A=0 · T=0 · Sd=1`.
**Output models you'd query:** `fct_supplier_performance`.
**Explore this when:** you need a supply-chain / inventory analytics template.

---

## easy/

### `easy/snowflake-sales-01` — Snowflake Sales Analytics
**Domain:** sales_operations
**About:** Compact sales-analytics DP with three dimensions / facts (customers, orders, products).
**Use cases:** customer profile analysis · product catalog management · sales transaction reporting · loyalty & segment analytics · product performance & pricing · order volume & discount tracking.
**Counts:** `M=3 · Py=0 · S=3 · C=3 · A=1 · T=3 · Sd=0`.
**Output models you'd query:** `customers, orders, products`.
**Explore this when:** you want the best teaching template — the only DP that ships `audits/` + `tests/` + `models/dq/` + `models/semantics/` together at small scale.

---

### `easy/sanityactivation` — Sanity Check
**Domain:** sanity
**About:** Smallest possible DP — its only purpose is to verify a fresh Vulcan + Snowflake setup works end-to-end.
**Counts:** `M=3 (full_model + seed_model + incremental_model) · Py=0 · S=1 · C=1 · A=0 · T=1 · Sd=1`.
**Explore this when:** you need a smoke-test DP to validate a new Snowflake depot or fresh local setup.

---

## At-a-glance summary

| Tier    | DP                                       |  M  | Py |  S |  C |  A |  T | Sd  | Hierarchy                   | Best for                              |
|---------|------------------------------------------|----:|---:|---:|---:|---:|---:|----:|-----------------------------|---------------------------------------|
| complex | sgws-web-analytics                       |  76 |  0 |  6 |  6 |  0 |  0 |  35 | 4-layer medallion           | End-to-end reference                  |
| complex | ldo                                      | ~36 |  0 | 16 |  5 |  0 |  0 |  30 | CDC seeds → flattend        | CDC + biggest semantic catalog        |
| complex | gensler-qualitrics-cu                    |  16 |  1 |  4 |  4 |  1 |  0 |   1 | raw → flattening → views    | SQL + Python + audits                 |
| complex | analytics-user-01                        |  23 |  0 |  4 |  5 |  1 |  0 |   3 | sub-domain folders          | Power BI engagement                   |
| complex | snowflake-tpch-02                        |   8 |  0 |  8 |  8 |  0 |  0 |   0 | flat                        | TPC-H + key-pair recipe               |
| complex | techfab-production-ops                   |   6 |  0 |  2 |  3 |  0 |  0 |   2 | silver → gold + dq          | Manufacturing / OEE                   |
| complex | cobs                                     |   6 |  0 |  1 |  2 |  0 |  0 |   3 | seeds → ml/aggregated       | ML / RFM segmentation                 |
| complex | customer-intelligence                    |   3 |  0 |  2 |  2 |  0 |  0 |   1 | seeds → gold                | CLV + RFM compact demo                |
| complex | delivery-performance                     |   7 |  1 |  4 |  5 |  0 |  0 |   1 | medallion + python          | Quick-commerce delivery KPIs          |
| complex | ecommerce-digital-experience             |   3 |  0 |  2 |  2 |  0 |  0 |   1 | flat                        | E-commerce funnel demo                |
| complex | quality-management-spc                   |   3 |  0 |  2 |  2 |  0 |  0 |   1 | flat                        | SPC / control charts                  |
| complex | supply-chain-inventory-optimization      |   3 |  0 |  2 |  2 |  0 |  0 |   1 | flat                        | Supply-chain / inventory              |
| easy    | snowflake-sales-01                       |   3 |  0 |  3 |  3 |  1 |  3 |   0 | flat                        | Best teaching template                |
| easy    | sanityactivation                         |   3 |  0 |  1 |  1 |  0 |  1 |   1 | flat                        | Smoke test                            |

---

## Pick a DP by your use case

| If your use case is… | Start with |
|---|---|
| Web / e-commerce / Adobe Analytics | `complex/sgws-web-analytics` |
| Device fleet / IT operations / CDC ingestion | `complex/ldo` |
| Surveys / experience analytics / SQL+Python | `complex/gensler-qualitrics-cu` |
| Product / hardware / software engagement (Power BI) | `complex/analytics-user-01` |
| TPC-H benchmark / Snowflake key-pair recipe | `complex/snowflake-tpch-02` |
| Manufacturing / IoT / OEE | `complex/techfab-production-ops` |
| Customer segmentation / RFM / churn / ML | `complex/cobs` |
| Customer lifetime value (CLV + RFM compact) | `complex/customer-intelligence` |
| Quick-commerce delivery analytics | `complex/delivery-performance` |
| E-commerce funnel / digital experience | `complex/ecommerce-digital-experience` |
| Statistical Process Control / quality charts | `complex/quality-management-spc` |
| Supply-chain / inventory optimization | `complex/supply-chain-inventory-optimization` |
| Learning Vulcan components in the smallest footprint | `easy/snowflake-sales-01` |
| Smoke-testing a fresh setup | `easy/sanityactivation` |

---