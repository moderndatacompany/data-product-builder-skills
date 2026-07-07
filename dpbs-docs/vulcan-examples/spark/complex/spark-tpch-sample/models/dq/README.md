# Data Quality Checks

Soda-style checks for TPC-H Spark models. All checks reference **existing models** in this project (`lhs3ny001depot.tpch_sparkv3.*`).

| File | Model(s) | Check types |
|------|----------|-------------|
| `01-filters-and-variables.yaml` | tpch_orders_sf1 | completeness, validity, uniqueness |
| `02-freshness.yaml` | view_order_line_summary_sf1 | timeliness (freshness on o_orderdate) |
| `03-group-by.yaml` | region_daily_orders_sf1 | group by (order_count by region) |
| `04-group-evolution.yaml` | tpch_region_sf1 | group evolution (region names) |
| `05-missing-metrics.yaml` | tpch_customer_sf1 | missing_count, missing_percent |
| `06-numeric-metrics.yaml` | tpch_part_sf1 | row_count, min, max, avg |
| `07-user-defined-failed-rows.yaml` | tpch_orders_sf1 | failed rows (negative price, invalid status) |
| `08-validity-metrics.yaml` | tpch_customer_sf1, full_customer_orders_sf1 | validity (failed rows), uniqueness |

Model names use the full identifier: `lhs3ny001depot.tpch_sparkv3.<model_name>`.
