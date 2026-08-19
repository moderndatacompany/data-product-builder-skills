MODEL (
  name sales.products,
  kind FULL,
  cron '@daily',
  grain product_id,
  description 'Product dimension table with full refresh on each run',
  assertions (
    unique_values(columns := (product_id))
  ),
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
  )
);

SELECT
  product_id,
  product_name,
  category,
  subcategory,
  brand,
  color,
  size,
  weight,
  material,
  model_number,
  sku,
  upc,
  price,
  cost,
  supplier,
  warranty_period,
  release_date,
  rating,
  stock_quantity,
  discontinued
FROM raw.raw_products

