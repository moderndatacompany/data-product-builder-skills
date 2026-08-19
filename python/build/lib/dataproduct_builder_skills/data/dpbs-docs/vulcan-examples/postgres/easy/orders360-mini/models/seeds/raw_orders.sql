MODEL (
  name raw.raw_orders,
  kind SEED (
    path '../../seeds/raw_orders.csv'
  ),
  description 'Seed model loading raw order data from CSV file',
  columns (
    order_id VARCHAR,
    order_date DATE,
    customer_id VARCHAR,
    product_id VARCHAR,
    total_amount FLOAT
  ),
  column_descriptions (
    order_id = 'Unique identifier for each order',
    order_date = 'Date when the order was placed',
    customer_id = 'Reference to customer who placed the order',
    product_id = 'Reference to product that was ordered',
    total_amount = 'Total order amount in dollars'
  ),
  assertions (
    unique_values(columns := (order_id)),
    not_null(columns := (order_id, order_date, customer_id, product_id)),
    positive_values(column := total_amount)
  ),
  grain order_id
);
