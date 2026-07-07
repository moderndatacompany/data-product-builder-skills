MODEL (
  name raw.raw_products,
  kind SEED (
    path '../../seeds/raw_products.csv'
  ),
  description 'Seed model loading raw product data from CSV file',
  columns (
    product_id STRING,
    product_name STRING,
    category STRING,
    subcategory STRING,
    brand STRING,
    color STRING,
    size STRING,
    weight FLOAT64,
    material STRING,
    model_number STRING,
    sku STRING,
    upc STRING,
    price FLOAT64,
    cost FLOAT64,
    supplier STRING,
    warranty_period STRING,
    release_date DATE,
    rating FLOAT64,
    stock_quantity INT64,
    discontinued BOOL
  ),
  grain product_id
);

