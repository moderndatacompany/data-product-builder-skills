MODEL (
  name qcommerce_returns_gold.daily_refund_kpis,
  kind FULL,
  owner 'shreyasikarwartmdcio',
  grains [ds, city],
  columns (
    ds DATE,
    city STRING,
    total_orders INT,
    refunded_orders INT,
    refund_events INT,
    total_refund_amount DECIMAL(14,2),
    avg_refund_amount DECIMAL(14,2),
    affected_customers INT,
    refund_rate DOUBLE
  )
);

WITH order_base AS (
  SELECT
    order_date AS ds,
    city,
    COUNT(DISTINCT order_id) AS total_orders
  FROM qcommerce_returns_bronze.orders_clean
  GROUP BY order_date, city
),

refund_base AS (
  SELECT
    refund_date AS ds,
    city,
    COUNT(DISTINCT order_id) AS refunded_orders,
    COUNT(DISTINCT refund_id) AS refund_events,
    ROUND(SUM(refund_amount), 2) AS total_refund_amount,
    ROUND(AVG(refund_amount), 2) AS avg_refund_amount,
    COUNT(DISTINCT customer_id) AS affected_customers
  FROM qcommerce_returns_silver.refund_enriched
  GROUP BY refund_date, city
)

SELECT
  o.ds,
  o.city,
  o.total_orders,
  COALESCE(r.refunded_orders, 0) AS refunded_orders,
  COALESCE(r.refund_events, 0) AS refund_events,
  COALESCE(r.total_refund_amount, 0) AS total_refund_amount,
  COALESCE(r.avg_refund_amount, 0) AS avg_refund_amount,
  COALESCE(r.affected_customers, 0) AS affected_customers,
  ROUND(
    COALESCE(r.refunded_orders, 0) / o.total_orders,
    4
  ) AS refund_rate
FROM order_base o
LEFT JOIN refund_base r
  ON o.ds = r.ds
 AND o.city = r.city;