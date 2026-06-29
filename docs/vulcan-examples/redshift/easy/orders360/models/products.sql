MODEL (
  name sales.products,
  kind FULL,
  cron '@daily',
  grain product_id,
  description 'Product dimension table with full refresh on each run',
  assertions (
    unique_values(columns := (product_id))
  ),
  column_descriptions (
    product_id = 'Unique identifier for each product',
    product_name = 'Product name',
    category = 'Product category (Electronics, Home, Clothing, Sports, Food, Toys)',
    subcategory = 'Product subcategory',
    brand = 'Product brand name',
    color = 'Product color',
    size = 'Product size (XS, S, M, L, XL, OneSize)',
    weight = 'Product weight',
    material = 'Product material (Metal, Plastic, Wood, Fabric, Glass)',
    model_number = 'Product model number',
    sku = 'Stock keeping unit code',
    upc = 'Universal product code',
    price = 'Product selling price',
    cost = 'Product cost price',
    supplier = 'Product supplier name',
    warranty_period = 'Product warranty period',
    release_date = 'Product release date',
    rating = 'Product rating (1.0-5.0)',
    stock_quantity = 'Current stock quantity available',
    discontinued = 'Whether product is discontinued'
  )
);

SELECT
  product_id::VARCHAR AS product_id,
  product_name::VARCHAR AS product_name,
  category::VARCHAR AS category,
  subcategory::VARCHAR AS subcategory,
  brand::VARCHAR AS brand,
  color::VARCHAR AS color,
  size::VARCHAR AS size,
  weight::FLOAT AS weight,
  material::VARCHAR AS material,
  model_number::VARCHAR AS model_number,
  sku::VARCHAR AS sku,
  upc::VARCHAR AS upc,
  price::FLOAT AS price,
  cost::FLOAT AS cost,
  supplier::VARCHAR AS supplier,
  warranty_period::VARCHAR AS warranty_period,
  release_date::DATE AS release_date,
  rating::FLOAT AS rating,
  stock_quantity::INTEGER AS stock_quantity,
  discontinued::BOOLEAN AS discontinued
FROM raw.raw_products

