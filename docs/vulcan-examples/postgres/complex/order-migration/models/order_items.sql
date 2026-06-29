MODEL (
  name sales.order_items,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column order_date
  ),
  start '2024-01-01',
  cron '@daily',
  grain order_item_id,
  description 'Order line items fact table with incremental loading by order date',
  assertions (
    not_null(columns := (order_item_id, order_id, product_id, order_date)),
    unique_values(columns := (order_item_id)),
    forall(criteria := (quantity > 0 AND unit_price >= 0 AND discount_rate >= 0 AND discount_rate <= 1 AND tax_rate >= 0))
  ),
  column_descriptions (
    order_item_id = 'Unique identifier for each order item line',
    order_id = 'Reference to order header',
    order_date = 'Order date from the order header',
    customer_id = 'Customer who placed the order (from order header)',
    product_id = 'Product identifier',
    quantity = 'Quantity ordered for this line',
    unit_price = 'Unit price at time of order',
    discount_rate = 'Discount rate applied to the line (0.0-1.0)',
    tax_rate = 'Tax rate applied to the discounted line amount',
    line_subtotal = 'quantity * unit_price',
    line_discount = 'line_subtotal * discount_rate',
    line_tax = '(line_subtotal - line_discount) * tax_rate',
    line_total = 'line_subtotal - line_discount + line_tax'
  )
);

SELECT
  oi.order_item_id::VARCHAR AS order_item_id,
  oi.order_id::VARCHAR AS order_id,
  o.order_date::DATE AS order_date,
  o.customer_id::VARCHAR AS customer_id,
  oi.product_id::VARCHAR AS product_id,
  oi.quantity::INTEGER AS quantity,
  oi.unit_price::FLOAT AS unit_price,
  oi.discount_rate::FLOAT AS discount_rate,
  oi.tax_rate::FLOAT AS tax_rate,
  @line_subtotal(oi.quantity, oi.unit_price)::FLOAT AS line_subtotal,
  @line_discount(oi.quantity, oi.unit_price, oi.discount_rate)::FLOAT AS line_discount,
  @line_tax(oi.quantity, oi.unit_price, oi.discount_rate, oi.tax_rate)::FLOAT AS line_tax,
  @line_total(oi.quantity, oi.unit_price, oi.discount_rate, oi.tax_rate)::FLOAT AS line_total
FROM raw.raw_order_items AS oi
JOIN raw.raw_orders AS o
  ON oi.order_id = o.order_id
WHERE o.order_date::DATE BETWEEN @start_date AND @end_date

