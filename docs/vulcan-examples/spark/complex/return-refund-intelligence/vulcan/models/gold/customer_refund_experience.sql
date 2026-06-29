MODEL (
  name qcommerce_returns_gold.customer_refund_experience,
  kind FULL,
  owner 'shreyasikarwartmdcio',
  grains [ds, customer_tier],
  description 'Customer-tier refund experience and refund-rate monitoring for finance and support analytics.',
  tags ('gold', 'refunds', 'customer-experience', 'tier'),
  terms ('customer_refund_experience', 'affected_customers', 'avg_refund_value'),
  columns (
    ds DATE,
    customer_tier STRING,
    total_orders INT,
    refunded_orders INT,
    affected_customers INT,
    total_refund_amount DECIMAL(14, 2),
    avg_refund_value DECIMAL(14, 2),
    avg_order_value DECIMAL(14, 2),
    refund_rate DOUBLE
  )
);

WITH order_base AS (
  SELECT
    order_date AS ds,
    customer_tier,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(AVG(order_amount), 2) AS avg_order_value
  FROM qcommerce_returns_bronze.orders_clean
  GROUP BY
    order_date,
    customer_tier
),

refund_base AS (
  SELECT
    refund_date AS ds,
    customer_tier,
    COUNT(DISTINCT order_id) AS refunded_orders,
    COUNT(DISTINCT customer_id) AS affected_customers,
    ROUND(SUM(refund_amount), 2) AS total_refund_amount,
    ROUND(AVG(refund_amount), 2) AS avg_refund_value
  FROM qcommerce_returns_silver.refund_enriched
  GROUP BY
    refund_date,
    customer_tier
)

SELECT
  o.ds,
  o.customer_tier,
  o.total_orders,
  COALESCE(r.refunded_orders, 0) AS refunded_orders,
  COALESCE(r.affected_customers, 0) AS affected_customers,
  COALESCE(r.total_refund_amount, 0) AS total_refund_amount,
  COALESCE(r.avg_refund_value, 0) AS avg_refund_value,
  o.avg_order_value,
  CASE
    WHEN o.total_orders = 0 THEN 0
    ELSE ROUND(COALESCE(r.refunded_orders, 0) / o.total_orders, 4)
  END AS refund_rate
FROM order_base o
LEFT JOIN refund_base r
  ON o.ds = r.ds
  AND o.customer_tier = r.customer_tier