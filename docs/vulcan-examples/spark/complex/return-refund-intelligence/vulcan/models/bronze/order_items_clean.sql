MODEL (
  name qcommerce_returns_bronze.order_items_clean,
  kind FULL,
  owner 'shreyasikarwartmdcio',
  grains [order_item_id],
  description 'Normalized order item level detail linking refunds to products, categories, and SKUs.',
  tags ('bronze', 'order-items', 'refunds', 'products'),
  terms ('order_items_clean', 'order_item_detail', 'product_category'),
  columns (
    order_item_id STRING,
    order_id STRING,
    sku_id STRING,
    product_name STRING,
    product_category STRING,
    quantity INT,
    item_amount DECIMAL(12, 2),
    fulfillment_status STRING
  )
);

SELECT
  CAST(order_item_id AS STRING) AS order_item_id,
  CAST(order_id AS STRING) AS order_id,
  CAST(sku_id AS STRING) AS sku_id,
  LOWER(TRIM(CAST(product_name AS STRING))) AS product_name,
  LOWER(TRIM(CAST(product_category AS STRING))) AS product_category,
  CAST(quantity AS INT) AS quantity,
  CAST(item_amount AS DECIMAL(12, 2)) AS item_amount,
  LOWER(TRIM(CAST(fulfillment_status AS STRING))) AS fulfillment_status
FROM qcommerce_returns_ext_raw.order_items