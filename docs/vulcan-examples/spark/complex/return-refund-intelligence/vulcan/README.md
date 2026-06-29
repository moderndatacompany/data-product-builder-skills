# Return and Refund Intelligence

Spark-based quick-commerce refund analytics example for Vulcan.

This data product keeps the medallion pattern from `demo/delivery-performance`, but shifts the business story from delivery reliability to return and refund intelligence.

## Business Questions

- Which cities have the highest refund rate?
- Which refund reasons are most common?
- Are premium customers asking for more refunds than standard customers?
- Which product categories are driving refund leakage?
- Are refunds caused more by delivery issues or product quality issues?

## Project Shape

- `external_models.yaml`: source contracts for `orders`, `refunds`, `order_items`, and `customers`
- `seeds/`: static source CSVs plus the refund reason mapping seed
- `models/bronze/`: cleaned source models and mapping seed model
- `models/silver/`: canonical enriched refund fact
- `models/gold/`: semantic-ready KPI aggregates
- `models/python_models/`: Python-based severity monitor model
- `models/semantics/`: reusable metrics, segments, and joins
- `models/dq/`: focused data quality rules
- `tests/`: lightweight regression-style model tests

## Demo Data

The project intentionally does not generate random data.

Instead, the repo includes static source CSV seeds:

- `seeds/raw_orders.csv`
- `seeds/raw_refunds.csv`
- `seeds/raw_order_items.csv`
- `seeds/raw_customers.csv`
- `seeds/refund_reason_mapping.csv`

Use your preferred ingestion path to load the raw CSV seeds into the external source tables declared in `external_models.yaml`. The mapping CSV is consumed directly as a Vulcan seed model.
