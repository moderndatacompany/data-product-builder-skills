MODEL (
  name sales.products,
  kind FULL,
  dialect postgres,
  grains (product_id),
  description 'Minimal placeholder products model (DELETE LATER)',
  columns (
    product_id      VARCHAR,
    product_name    VARCHAR,
    category        VARCHAR,
    subcategory     VARCHAR,
    brand           VARCHAR,
    color           VARCHAR,
    size            VARCHAR,
    price           NUMERIC(10, 2),
    rating          NUMERIC(2, 1),
    stock_quantity  INT,
    discontinued    BOOLEAN
  )
);

SELECT
  product_id::VARCHAR         AS product_id,
  product_name::VARCHAR       AS product_name,
  category::VARCHAR           AS category,
  subcategory::VARCHAR        AS subcategory,
  brand::VARCHAR              AS brand,
  color::VARCHAR              AS color,
  size::VARCHAR               AS size,
  price::NUMERIC(10, 2)       AS price,
  rating::NUMERIC(2, 1)       AS rating,
  stock_quantity::INT         AS stock_quantity,
  discontinued::BOOLEAN       AS discontinued
FROM (
  VALUES
    ('P001', 'Wireless Mouse', 'Electronics', 'Accessories', 'TechPro',     'Black', 'OneSize', 29.99, 4.5, 150, FALSE),
    ('P002', 'Cotton T-Shirt', 'Clothing',    'Tops',        'ComfortWear', 'Blue',  'M',       24.99, 4.2, 300, FALSE),
    ('P003', 'Yoga Mat',       'Fitness',     'Mats',        'FlexFit',     'Green', 'Large',   39.99, 4.7,  80, FALSE)
) AS t (product_id, product_name, category, subcategory, brand, color, size, price, rating, stock_quantity, discontinued);
