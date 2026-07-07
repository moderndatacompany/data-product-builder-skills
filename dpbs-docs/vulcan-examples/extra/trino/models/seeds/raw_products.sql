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
    subcategory VARCHAR,
    brand VARCHAR,
    color VARCHAR,
    size VARCHAR,
    weight DECIMAL(10,2),
    material VARCHAR,
    model_number VARCHAR,
    sku VARCHAR,
    upc VARCHAR,
    price DECIMAL(10,2),
    cost DECIMAL(10,2),
    supplier VARCHAR,
    warranty_period VARCHAR,
    release_date DATE,
    rating DECIMAL(3,1),
    stock_quantity INTEGER,
    discontinued BOOLEAN
  ),
  grain product_id
);

