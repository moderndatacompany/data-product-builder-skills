MODEL (
  name qcommerce_returns_ext_raw.orders,
  kind SEED (
    path '../../seeds/raw_orders.csv'
  ),
  owner 'shreyasikarwartmdcio',
  grains [order_id],
  description 'Raw order seed input for return and refund intelligence.',
  tags ('seed', 'ext-raw', 'orders', 'refunds'),
  terms ('orders', 'raw_orders', 'source_input'),
  columns (
    order_id STRING,
    customer_id STRING,
    city STRING,
    order_ts TIMESTAMP,
    order_amount DOUBLE,
    order_status STRING,
    payment_status STRING,
    delivery_mode STRING
  )
)
