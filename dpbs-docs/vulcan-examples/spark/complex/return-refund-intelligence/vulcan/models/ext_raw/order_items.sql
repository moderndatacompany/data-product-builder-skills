MODEL (
  name qcommerce_returns_ext_raw.order_items,
  kind SEED (
    path '../../seeds/raw_order_items.csv'
  ),
  owner 'shreyasikarwartmdcio',
  grains [order_item_id],
  description 'Raw order item seed input for return and refund intelligence.',
  tags ('seed', 'ext-raw', 'order-items', 'products'),
  terms ('order_items', 'raw_order_items', 'source_input'),
  columns (
    order_item_id STRING,
    order_id STRING,
    sku_id STRING,
    product_name STRING,
    product_category STRING,
    quantity INT,
    item_amount DOUBLE,
    fulfillment_status STRING
  )
)
