MODEL (
  name s3depot.qcommerce_delivery_bronze.raw_orders,
  kind SEED (
    path '../../seeds/raw_orders.csv'
  ),
  owner 'shreyasikarwartmdcio',
  grains [order_id],
  description 'Raw quick-commerce order events sourced from the bundled seed CSV. Acts as the single source of truth for downstream delivery analytics in this self-contained Spark example.',
  tags ('seed', 'bronze', 'orders', 'raw'),
  terms ('raw_orders', 'order_event', 'order_master'),
  columns (
    order_id STRING,
    customer_id STRING,
    city STRING,
    order_ts TIMESTAMP,
    order_amount DECIMAL(12, 2),
    payment_status STRING,
    delivery_mode STRING
  ),
  assertions (
    not_null(columns := (order_id, customer_id, city, order_ts)),
    unique_values(columns := (order_id)),
    accepted_range(column := order_amount, min_v := 0, max_v := 100000)
  )
);
