MODEL (
  name s3depot.qcommerce_delivery_bronze.raw_customers,
  kind SEED (
    path '../../seeds/raw_customers.csv'
  ),
  owner 'shreyasikarwartmdcio',
  grains [customer_id],
  description 'Raw customer master sourced from the bundled seed CSV. Provides customer attributes such as tier, signup city, and active flag for downstream delivery analytics.',
  tags ('seed', 'bronze', 'customers', 'raw'),
  terms ('raw_customers', 'customer_master', 'customer_tier'),
  columns (
    customer_id STRING,
    customer_name STRING,
    customer_tier STRING,
    signup_city STRING,
    is_active BOOLEAN
  ),
  assertions (
    not_null(columns := (customer_id)),
    unique_values(columns := (customer_id))
  )
);
