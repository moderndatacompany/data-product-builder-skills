MODEL (
  name sales.orders,
  kind INCREMENTAL_BY_UNIQUE_KEY (
    unique_key order_id
  ),
  cron '@daily',
  grain order_id,
  description 'Orders fact table with incremental loading by unique key',
  columns (
    order_id VARCHAR,
    order_date DATE,
    customer_id VARCHAR,
    product_id VARCHAR,
    quantity INTEGER,
    unit_price DECIMAL(10,2),
    discount DECIMAL(5,2),
    tax DECIMAL(10,2),
    shipping_cost DECIMAL(10,2),
    total_amount DECIMAL(10,2)
  )
);

SELECT
  order_id,
  order_date,
  customer_id,
  product_id,
  quantity,
  unit_price,
  discount,
  tax,
  shipping_cost,
  total_amount
FROM raw.raw_orders

