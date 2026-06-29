# Delivery Performance Analytics

Spark-based quick-commerce delivery performance example for Vulcan.

This data product mirrors the Snowflake `demo/delivery-performance` data product but is rebuilt the Spark way: lakehouse depots, Spark SQL dialect, static CSV source seeds wrapped as `SEED`-kind models, and a leaner medallion layout.

## Business Questions

- Which cities have the highest SLA breach rate?
- Which customer tiers experience the most delivery delays and failures?
- Which riders are most efficient and which need attention?
- What are the most common delivery issue types and where do they happen?

## Project Shape

- `seeds/`: static source CSVs (raw orders, shipments, customers, plus city SLA rules)
- `models/seeds/`: `SEED`-kind models that load the CSVs directly into the bronze layer
- `models/bronze/`: cleaned source models for orders and shipments
- `models/silver/`: canonical enriched fulfillment fact
- `models/gold/`: semantic-ready KPI aggregates
- `models/python_models/`: Python-based rider efficiency model
- `models/semantics/`: reusable metrics, segments, and joins
- `models/dq/`: focused data quality rules
- `tests/`: lightweight regression-style model tests

## Demo Data

The project is fully self-contained — no external sources need to be loaded before running. All raw data lives in `seeds/` and is materialized via `SEED`-kind Vulcan models in `models/seeds/`.

| Seed CSV | SEED model | Rows |
|----------|------------|------|
| `seeds/raw_customers.csv` | `s3depot.qcommerce_delivery_bronze.raw_customers` | 120 |
| `seeds/raw_orders.csv` | `s3depot.qcommerce_delivery_bronze.raw_orders` | 160 |
| `seeds/raw_shipments.csv` | `s3depot.qcommerce_delivery_bronze.raw_shipments` | 167 |
| `seeds/city_sla_rules.csv` | `s3depot.qcommerce_delivery_bronze.city_sla_rules` | 12 |

Order and shipment events span 2026-04-14 to 2026-04-20 across six Indian cities (Bengaluru, Mumbai, Delhi, Hyderabad, Chennai, Pune) and three customer tiers (`STANDARD`, `PREMIUM`, `VIP`). The data is shaped to exercise late deliveries, failed deliveries, missing scans, address issues, and the `R104` Hyderabad rider profile that drives the rider efficiency model.
