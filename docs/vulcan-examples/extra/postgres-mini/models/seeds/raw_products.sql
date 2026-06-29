MODEL (
  name raw.raw_products,
  kind SEED (
    path '../../seeds/raw_products.csv'
  ),
  description 'Seed model loading raw product data from CSV file',
  columns (
    product_id VARCHAR,
    product_name VARCHAR,
    category VARCHAR,
    price FLOAT,
    stock_quantity INTEGER
  ),
  column_descriptions (
    product_id = 'Unique identifier for each product',
    product_name = 'Name of the product',
    category = 'Product category (Electronics, Clothing, Sports, Home, Food, Toys)',
    price = 'Product selling price in dollars',
    stock_quantity = 'Current inventory quantity available'
  ),
  assertions (
    unique_values(columns := (product_id)),
    not_null(columns := (product_id, product_name, category, price))  ),
  grain product_id
);
