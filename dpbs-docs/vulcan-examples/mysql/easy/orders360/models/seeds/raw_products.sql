MODEL (
  name raw.raw_products,
  kind SEED (
    path '../../seeds/raw_products.csv'
  ),
  description 'Seed model loading raw product data from CSV file',
  columns (
    product_id VARCHAR(10),
    product_name VARCHAR(100),
    category VARCHAR(50),
    subcategory VARCHAR(50),
    brand VARCHAR(50),
    color VARCHAR(20),
    size VARCHAR(20),
    weight DECIMAL(10,2),
    material VARCHAR(50),
    model_number VARCHAR(50),
    sku VARCHAR(50),
    upc VARCHAR(20),
    price DECIMAL(10,2),
    cost DECIMAL(10,2),
    supplier VARCHAR(100),
    warranty_period VARCHAR(50),
    release_date DATE,
    rating DECIMAL(3,1),
    stock_quantity INT,
    discontinued BOOLEAN
  ),
  grain product_id
);

