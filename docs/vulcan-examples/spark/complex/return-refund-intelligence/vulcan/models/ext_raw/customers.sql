MODEL (
  name qcommerce_returns_ext_raw.customers,
  kind SEED (
    path '../../seeds/raw_customers.csv'
  ),
  owner 'shreyasikarwartmdcio',
  grains [customer_id],
  description 'Raw customer seed input for return and refund intelligence.',
  tags ('seed', 'ext-raw', 'customers', 'reference-data'),
  terms ('customers', 'raw_customers', 'source_input'),
  columns (
    customer_id STRING,
    customer_name STRING,
    customer_tier STRING,
    signup_city STRING,
    segment_label STRING,
    is_active BOOLEAN
  )
)
