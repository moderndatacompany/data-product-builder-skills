MODEL (
  name sales.orders,
  kind FULL,
  dialect postgres,
  grains (order_id),
  description 'Minimal placeholder orders model (DELETE LATER)',
  columns (
    order_id      VARCHAR,
    order_date    DATE,
    customer_id   VARCHAR,
    product_id    VARCHAR,
    quantity      INT,
    unit_price    NUMERIC(10, 2),
    discount      NUMERIC(5, 2),
    tax           NUMERIC(10, 2),
    shipping_cost NUMERIC(10, 2),
    total_amount  NUMERIC(12, 2)
  )
);

SELECT
  order_id::VARCHAR              AS order_id,
  order_date::DATE               AS order_date,
  customer_id::VARCHAR           AS customer_id,
  product_id::VARCHAR            AS product_id,
  quantity::INT                  AS quantity,
  unit_price::NUMERIC(10, 2)     AS unit_price,
  discount::NUMERIC(5, 2)        AS discount,
  tax::NUMERIC(10, 2)            AS tax,
  shipping_cost::NUMERIC(10, 2)  AS shipping_cost,
  total_amount::NUMERIC(12, 2)   AS total_amount
FROM (
  VALUES
    ('O001', DATE '2024-01-05', 'C001', 'P001', 2, 29.99, 0.00, 4.80, 5.99,  70.77),
    ('O002', DATE '2024-01-10', 'C002', 'P003', 1, 39.99, 0.10, 3.24, 4.99,  44.22),
    ('O003', DATE '2024-01-15', 'C003', 'P002', 3, 24.99, 0.05, 6.75, 7.50,  85.97)
) AS t (order_id, order_date, customer_id, product_id, quantity, unit_price, discount, tax, shipping_cost, total_amount);
