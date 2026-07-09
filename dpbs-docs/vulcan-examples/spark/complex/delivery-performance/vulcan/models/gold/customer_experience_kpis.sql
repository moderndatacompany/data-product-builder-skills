MODEL (
  name s3depot.qcommerce_delivery_gold.customer_experience_kpis,
  kind FULL,
  owner 'shreyasikarwartmdcio',
  grains [ds, city, customer_tier],
  description 'Daily customer-tier delivery experience KPIs for understanding delays, failures, and refund risk across customer segments.',
  tags ('gold', 'customer-experience', 'delivery', 'tier'),
  terms ('customer_experience_kpis', 'customers_impacted', 'refund_rate', 'experience_risk_segment'),
  columns (
    ds DATE,
    city STRING,
    customer_tier STRING,
    total_orders INT,
    customers_impacted INT,
    late_orders INT,
    failed_orders INT,
    total_order_value DECIMAL(14, 2),
    refunded_orders INT,
    total_refund_amount DECIMAL(14, 2),
    experience_risk_segment STRING
  ),
  assertions (
    not_null(columns := (ds, city, customer_tier))
  )
);

WITH customer_experience_base AS (
  SELECT
    order_date AS ds,
    city,
    customer_tier,
    COUNT(*) AS total_orders,
    COUNT(DISTINCT CASE WHEN is_sla_breached OR is_failed_delivery THEN customer_id END) AS customers_impacted,
    SUM(CASE WHEN issue_type = 'late_delivery' THEN 1 ELSE 0 END) AS late_orders,
    SUM(CASE WHEN is_failed_delivery THEN 1 ELSE 0 END) AS failed_orders,
    ROUND(SUM(order_amount), 2) AS total_order_value,
    SUM(CASE WHEN normalized_payment_status = 'refunded' THEN 1 ELSE 0 END) AS refunded_orders,
    ROUND(SUM(CASE WHEN normalized_payment_status = 'refunded' THEN order_amount ELSE 0 END), 2) AS total_refund_amount
  FROM s3depot.qcommerce_delivery_silver.order_fulfillment_enriched
  GROUP BY order_date, city, customer_tier
)
SELECT
  ds,
  city,
  customer_tier,
  total_orders,
  customers_impacted,
  late_orders,
  failed_orders,
  total_order_value,
  refunded_orders,
  total_refund_amount,
  CASE
    WHEN total_orders = 0 THEN 'unknown'
    WHEN CAST(failed_orders AS DOUBLE) / NULLIF(total_orders, 0) >= 0.12
      OR CAST(customers_impacted AS DOUBLE) / NULLIF(total_orders, 0) >= 0.35
      OR CAST(total_refund_amount AS DOUBLE) / NULLIF(total_order_value, 0) >= 0.10 THEN 'critical'
    WHEN CAST(late_orders AS DOUBLE) / NULLIF(total_orders, 0) >= 0.20
      OR CAST(refunded_orders AS DOUBLE) / NULLIF(total_orders, 0) >= 0.08
      OR failed_orders + refunded_orders >= 5 THEN 'high_risk'
    WHEN CAST(late_orders AS DOUBLE) / NULLIF(total_orders, 0) >= 0.10
      OR customers_impacted >= 3
      OR CAST(total_refund_amount AS DOUBLE) / NULLIF(total_order_value, 0) >= 0.04 THEN 'watchlist'
    ELSE 'healthy'
  END AS experience_risk_segment
FROM customer_experience_base
ORDER BY ds DESC, city, customer_tier;
