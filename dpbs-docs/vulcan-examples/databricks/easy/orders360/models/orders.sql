MODEL (
  name sales.orders,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column order_date
  ),
  start '2024-01-01',
  cron '@daily',
  grain order_id,
  description 'Orders fact table with incremental loading by order date',
  column_descriptions (
    order_id = 'Unique identifier for each order',
    order_date = 'Date when order was placed',
    customer_id = 'Reference to customer who placed the order',
    product_id = 'Reference to product ordered',
    quantity = 'Quantity of items ordered',
    unit_price = 'Price per unit at time of order',
    discount = 'Discount rate applied (0.0-1.0)',
    tax = 'Tax amount charged',
    shipping_cost = 'Shipping cost for the order',
    total_amount = 'Total order amount including tax and shipping'
  )
);

SELECT
  order_id,
  order_date,
  customer_id,
  product_id,
  quantity,
  unit_price,
  discount,
  tax,
  shipping_cost,
  total_amount
FROM raw.raw_orders
WHERE order_date BETWEEN @start_date AND @end_date

