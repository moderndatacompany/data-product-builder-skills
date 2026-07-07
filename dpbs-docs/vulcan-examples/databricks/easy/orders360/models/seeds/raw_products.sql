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
    weight DOUBLE,
    material STRING,
    model_number STRING,
    sku STRING,
    upc STRING,
    price DOUBLE,
    cost DOUBLE,
    supplier STRING,
    warranty_period STRING,
    release_date DATE,
    rating DOUBLE,
    stock_quantity INT,
    discontinued BOOLEAN
  ),
  grain product_id,
  audits (
    not_null(columns := (product_id, product_name, price)),
    unique_values(columns := (product_id))
  )
);

