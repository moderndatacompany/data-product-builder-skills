MODEL (
  name s3depot.qcommerce_delivery_bronze.orders_clean,
  kind FULL,
  owner 'shreyasikarwartmdcio',
  grains [order_id],
  description 'Cleaned order master combining external order events with customer attributes for downstream delivery analytics.',
  tags ('bronze', 'orders', 'delivery', 'customer'),
  terms ('orders_clean', 'order_master', 'customer_tier'),
  columns (
    order_id STRING,
    customer_id STRING,
    city STRING,
    order_ts TIMESTAMP,
    order_date DATE,
    order_amount DECIMAL(12, 2),
    payment_status STRING,
    normalized_payment_status STRING,
    delivery_mode STRING,
    customer_name STRING,
    customer_tier STRING,
    signup_city STRING,
    is_active BOOLEAN
  ),
  assertions (
    not_null(columns := (order_id, customer_id, city, order_ts)),
    unique_values(columns := (order_id)),
    accepted_range(column := order_amount, min_v := 0, max_v := 100000)
  )
);

WITH orders_base AS (
  SELECT
    CAST(order_id AS STRING) AS order_id,
    CAST(customer_id AS STRING) AS customer_id,
    INITCAP(TRIM(CAST(city AS STRING))) AS city,
    CAST(order_ts AS TIMESTAMP) AS order_ts,
    CAST(order_amount AS DECIMAL(12, 2)) AS order_amount,
    LOWER(TRIM(CAST(payment_status AS STRING))) AS payment_status,
    LOWER(TRIM(CAST(delivery_mode AS STRING))) AS delivery_mode
  FROM s3depot.qcommerce_delivery_bronze.raw_orders
),
customers_base AS (
  SELECT
    CAST(customer_id AS STRING) AS customer_id,
    CAST(customer_name AS STRING) AS customer_name,
    UPPER(TRIM(CAST(customer_tier AS STRING))) AS customer_tier,
    INITCAP(TRIM(CAST(signup_city AS STRING))) AS signup_city,
    CAST(is_active AS BOOLEAN) AS is_active
  FROM s3depot.qcommerce_delivery_bronze.raw_customers
)
SELECT
  o.order_id,
  o.customer_id,
  o.city,
  o.order_ts,
  TO_DATE(o.order_ts) AS order_date,
  o.order_amount,
  o.payment_status,
  CASE
    WHEN o.payment_status IN ('paid', 'captured', 'settled') THEN 'paid'
    WHEN o.payment_status IN ('failed', 'declined') THEN 'failed'
    WHEN o.payment_status IN ('refunded', 'partial_refund') THEN 'refunded'
    WHEN o.payment_status IN ('pending', 'authorized') THEN 'pending'
    ELSE 'unknown'
  END AS normalized_payment_status,
  o.delivery_mode,
  c.customer_name,
  COALESCE(c.customer_tier, 'STANDARD') AS customer_tier,
  c.signup_city,
  COALESCE(c.is_active, TRUE) AS is_active
FROM orders_base o
LEFT JOIN customers_base c
  ON o.customer_id = c.customer_id;
