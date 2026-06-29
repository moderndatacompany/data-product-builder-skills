MODEL (
  name sales.orders,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column order_date
  ),
  start '2024-01-01',
  cron '@daily',
  grain order_id,
  description 'Orders fact table with incremental loading by order date',
  assertions (
    not_null(columns := (order_id, order_date, customer_id)),
    unique_values(columns := (order_id)),
    forall(criteria := (shipping_cost >= 0))
  ),
  column_descriptions (
    order_id = 'Unique identifier for each order',
    order_date = 'Date when order was placed',
    customer_id = 'Reference to customer who placed the order',
    order_status = 'Current order lifecycle status (Completed, Shipped, Processing, Cancelled, Returned)',
    order_channel = 'Sales channel where order was placed (Web, Mobile, Store, Marketplace)',
    currency = 'Currency code for the order amounts',
    subtotal_amount = 'Sum of line item subtotals before discounts and taxes',
    discount_amount = 'Total discount amount across line items',
    tax_amount = 'Total tax amount across line items',
    shipping_cost = 'Shipping cost for the order',
    total_amount = 'Total order amount including shipping (subtotal - discount + tax + shipping)',
    shipping_country = 'Shipping country code',
    shipping_state = 'Shipping state/region',
    shipping_city = 'Shipping city',
    shipping_postal_code = 'Shipping postal code',
    payment_status = 'High-level payment status (Paid, Pending, Refunded)'
  )
);

WITH item_amounts AS (
  SELECT
    oi.order_id::VARCHAR AS order_id,
    SUM(@line_subtotal(oi.quantity, oi.unit_price)) AS subtotal_amount,
    SUM(@line_discount(oi.quantity, oi.unit_price, oi.discount_rate)) AS discount_amount,
    SUM(@line_tax(oi.quantity, oi.unit_price, oi.discount_rate, oi.tax_rate)) AS tax_amount
  FROM raw.raw_order_items AS oi
  GROUP BY oi.order_id
)
SELECT
  o.order_id::VARCHAR AS order_id,
  o.order_date::DATE AS order_date,
  o.customer_id::VARCHAR AS customer_id,
  o.order_status::VARCHAR AS order_status,
  o.order_channel::VARCHAR AS order_channel,
  o.currency::VARCHAR AS currency,
  COALESCE(ia.subtotal_amount, 0)::FLOAT AS subtotal_amount,
  COALESCE(ia.discount_amount, 0)::FLOAT AS discount_amount,
  COALESCE(ia.tax_amount, 0)::FLOAT AS tax_amount,
  o.shipping_cost::FLOAT AS shipping_cost,
  (COALESCE(ia.subtotal_amount, 0) - COALESCE(ia.discount_amount, 0) + COALESCE(ia.tax_amount, 0) + o.shipping_cost::FLOAT)::FLOAT AS total_amount,
  o.shipping_country::VARCHAR AS shipping_country,
  o.shipping_state::VARCHAR AS shipping_state,
  o.shipping_city::VARCHAR AS shipping_city,
  o.shipping_postal_code::VARCHAR AS shipping_postal_code,
  o.payment_status::VARCHAR AS payment_status
FROM raw.raw_orders AS o
LEFT JOIN item_amounts AS ia
  ON o.order_id = ia.order_id
WHERE o.order_date::DATE BETWEEN @start_date AND @end_date

