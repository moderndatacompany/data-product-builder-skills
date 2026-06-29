MODEL (
  name raw.raw_order_items,
  kind SEED (
    path '../../seeds/raw_order_items.csv'
  ),
  description 'Seed model loading raw order item data from CSV file',
  columns (
    order_item_id VARCHAR,
    order_id VARCHAR,
    product_id VARCHAR,
    quantity INTEGER,
    unit_price FLOAT,
    discount_rate FLOAT,
    tax_rate FLOAT
  ),
  grain order_item_id
);

