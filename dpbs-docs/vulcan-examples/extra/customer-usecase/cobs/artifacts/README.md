# COBS artifacts

Sample data for **optional** Snowflake ingestion. Vulcan’s RFM models do **not** depend on these files; they use seed-based staging (`seeds/v_d_customer_stage.csv`, `seeds/v_fact_sales_stage.csv`) by default.

## `redshift/`

- **`v_d_customer.csv`** – Used only by `scripts/fast_create_insert_customer.py` when populating `onesourceplus.v_d_customer` in Snowflake. Not required for `vulcan plan` with seed-based staging.
