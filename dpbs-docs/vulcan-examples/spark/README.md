# Spark Data Products — Vulcan Examples

A catalog of **Vulcan data products** that run on **Apache Spark** (with Apache Iceberg + MinIO + PostgreSQL state store, or a DataOS `s3depot` lakehouse).

Counts legend: `M` = SQL models · `Py` = Python models · `S` = Semantic models · `C` = Checks · `A` = Audits · `T` = Tests · `Sd` = Seeds.


> **Layout convention — flat vs. nested `vulcan/`:**
> Three of the five DPs in this catalog use a **flat layout** at the DP root
> (`config.yaml`, `models/`, `seeds/` all live directly under the DP folder).
>
> The two DPs marked with the DataOS bundle pattern — **`complex/delivery-performance`**
> and **`complex/return-refund-intelligence`** — intentionally use a **nested layout**:
>
> - **DP root** holds *infrastructure provisioning* manifests (`bundle.yaml`,
>   `lakehouse.yaml`, `lh_depot.yaml`, `lh_secret.yaml`, `pg_secret.yaml`).
>   These are applied once via `dataos-ctl` to provision the lakehouse + depot.
> - **`vulcan/` subfolder** holds the actual *Vulcan pipeline* (`config.yaml`,
>   `models/`, `seeds/`, `Makefile`). This is what runs on every `vulcan plan/run`.
>
> Two lifecycles, two folders. The other Spark DPs in this catalog don't ship
> DataOS deployment artifacts and therefore stay flat.

---

## complex/

### `complex/delivery-performance` — Delivery Performance Analytics
**Domain:** delivery_operations
**About:** Quick-commerce delivery performance DP for city SLA monitoring, customer experience analysis, rider efficiency, and issue root-cause tracking. Spark sibling of the Snowflake `complex/delivery-performance` DP.
**Use cases:** daily city-level delivery KPI monitoring · customer tier delay & failure analysis · rider efficiency benchmarking · delivery issue categorization & business-impact analysis · semantic-ready Gold layer for dashboards and self-serve analytics.
**Hierarchy:** `seeds (csv) → models/seeds (SEED-kind) → bronze → silver → gold → python_models → semantics`.
**Counts:** `M=10 (4 seed + 2 bronze + 1 silver + 3 gold) · Py=1 · S=4 · C=5 · A=0 · T=0 · Sd=4`.
**Output models you'd query:** `daily_delivery_kpis, delivery_issue_summary, customer_experience_kpis, rider_efficiency_kpis, order_fulfillment_enriched`.
**Extras:** DataOS bundle deployment artefacts at DP root (`bundle.yaml`, `lakehouse.yaml`, `lh_depot.yaml`, `lh_secret.yaml`, `pg_secret.yaml`); Vulcan project nested under `vulcan/`; lakehouse depot (`dataos://s3depot`); `dialect: spark2`; 15-minute cron; demo data is fully self-contained.
**Explore this when:** you want a **complete medallion Spark DP** with Python models, lakehouse depot, and the DataOS bundle-deployment recipe.

---

### `complex/return-refund-intelligence` — Return and Refund Intelligence
**Domain:** quick_commerce_returns
**About:** Quick-commerce refund analytics DP for finance leakage control, return root-cause analysis, and customer segment impact monitoring. Keeps the medallion pattern from `delivery-performance` but shifts the story to refund intelligence.
**Use cases:** daily city-level refund KPI monitoring · refund reason & issue-group root-cause analysis · customer tier refund experience tracking · product category refund leakage monitoring · semantic-ready Gold layer for finance, operations, and support analytics.
**Hierarchy:** `seeds + external_models.yaml → ext_raw → bronze → silver → gold → python_models`.
**Counts:** `M=13 (4 ext_raw + 4 bronze + 1 silver + 4 gold) · Py=1 · S=0 (semantics published separately) · C=5 · A=0 · T=0 · Sd=5`.
**Output models you'd query:** `daily_refund_kpis, customer_refund_experience, product_refund_performance, refund_issue_summary, refund_severity_monitor`.
**Extras:** DataOS bundle deployment artefacts (`bundle.yaml`, `lakehouse.yaml`, `lh_depot.yaml`, `lh_secret.yaml`, `pg_secret.yaml`); Vulcan project nested under `vulcan/`; depot (`dataos://s3depot?purpose=rw`) + DuckDB state store; `dialect: spark2`. The semantic layer for these Gold models is published separately at `anushka-examples/rr-intel-trino/` as Trino views with full measures, segments, and joins.
**Explore this when:** you want a **Spark Gold pipeline paired with a downstream Trino semantic-serving layer** — the cleanest example of splitting transformation from serving across engines.

---

### `complex/spark-tpch-lakehouse` — Spark TPC-H Lakehouse
**Domain:** system / benchmark / lakehouse
**About:** TPC-H benchmark DP built as a real Spark + Iceberg lakehouse pipeline with staging and gold layers — the largest Spark TPC-H reference in this repo.
**Hierarchy:** `staging → gold` over Iceberg tables.
**Counts:** `M=19 · Py=0 · S=4 · C=5 · A=0 · T=0 · Sd=0`.
**Output models you'd query:** `gold.customer_snapshot, gold.supplier_performance, gold.order_line_summary` plus 8 base + staging TPC-H tables.
**Explore this when:** you want a **production-style Spark + Iceberg TPC-H pipeline** with staging/gold layering and semantics.

---

### `complex/spark-tpch-sample` — Spark TPC-H Sample (heavy checks)
**Domain:** system / benchmark
**About:** TPC-H benchmark DP at `SF1` scale with the **largest single-DP check coverage** in the Spark catalog (23 quality checks).
**Counts:** `M=16 · Py=0 · S=3 · C=23 · A=0 · T=0 · Sd=0`.
**Output models you'd query:** `tpch_customer_sf1, tpch_lineitem_sf1, tpch_orders_sf1, …` plus aggregates like `region_daily_orders_sf1, emb_active_customers_sf1`.
**Explore this when:** you want a TPC-H benchmark example with **maximal data-quality check coverage** to evaluate Vulcan's `models/dq/` capability.

---

## easy/

### `easy/spark-lakehouse` — Spark Lakehouse Deployment Starter
**Domain:** analytics / deployment
**About:** Compact 2-model Spark + Iceberg scaffold showing the depot connection pattern with a small semantic layer (TPC-H customer + order lineitem revenue).
**Counts:** `M=2 · Py=0 · S=3 · C=0 · A=0 · T=0 · Sd=0`.
**Output models you'd query:** `customer_orders_summary, order_line_revenue`.
**Explore this when:** you need a minimal deployment-pattern starter for Spark with semantics already wired.

---

## At-a-glance summary

| Tier    | DP                          |  M  | Py |  S |  C |  A |  T | Sd | Hierarchy                                  | Best for                                  |
|---------|-----------------------------|----:|---:|---:|---:|---:|---:|---:|--------------------------------------------|-------------------------------------------|
| complex | delivery-performance        |  10 |  1 |  4 |  5 |  0 |  0 |  4 | seeds → bronze → silver → gold + python    | Full medallion + DataOS bundle recipe     |
| complex | return-refund-intelligence  |  13 |  1 |  0 |  5 |  0 |  0 |  5 | ext_raw → bronze → silver → gold + python  | Spark Gold + Trino serving split          |
| complex | spark-tpch-lakehouse        |  19 |  0 |  4 |  5 |  0 |  0 |  0 | staging → gold (Iceberg)                   | Production Spark+Iceberg TPC-H pipeline   |
| complex | spark-tpch-sample           |  16 |  0 |  3 | 23 |  0 |  0 |  0 | flat                                       | TPC-H with heavy check coverage           |
| easy    | spark-lakehouse             |   2 |  0 |  3 |  0 |  0 |  0 |  0 | flat                                       | Deployment-pattern starter with semantics |

---

## Pick a DP by your use case

| If your use case is… | Start with |
|---|---|
| Full medallion Spark DP with Python models and DataOS bundle deployment | `complex/delivery-performance` |
| Spark Gold pipeline paired with a downstream Trino semantic layer | `complex/return-refund-intelligence` |
| Production-style Spark + Iceberg TPC-H lakehouse | `complex/spark-tpch-lakehouse` |
| TPC-H with maximal data-quality check coverage | `complex/spark-tpch-sample` |
| Deployment-pattern starter (Spark + depot + semantics) | `easy/spark-lakehouse` |

---