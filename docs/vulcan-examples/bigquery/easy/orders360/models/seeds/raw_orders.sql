MODEL (
  name raw.raw_orders,
  kind SEED (
    path '../../seeds/raw_orders.csv'
  ),
  description 'Seed model loading raw order data from CSV file',
  columns (
    order_id STRING,
    order_date DATE,
    customer_id STRING,
    product_id STRING,
    quantity INT64,
    unit_price FLOAT64,
    discount FLOAT64,
    tax FLOAT64,
    shipping_cost FLOAT64,
    total_amount FLOAT64
  ),
  grain order_id,
  audits (
    not_null(columns := (order_id, order_date, customer_id, product_id)),
    unique_values(columns := (order_id))
  )
);

