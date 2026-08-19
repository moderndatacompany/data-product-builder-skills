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
    shipping_cost FLOAT,
    order_status VARCHAR,
    order_channel VARCHAR,
    currency VARCHAR,
    shipping_country VARCHAR,
    shipping_state VARCHAR,
    shipping_city VARCHAR,
    shipping_postal_code VARCHAR,
    payment_status VARCHAR
  ),
  grain order_id
);

