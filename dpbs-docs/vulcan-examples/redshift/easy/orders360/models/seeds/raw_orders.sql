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
    quantity INTEGER,
    unit_price FLOAT,
    discount FLOAT,
    tax FLOAT,
    shipping_cost FLOAT,
    total_amount FLOAT
  ),
  grain order_id
);

