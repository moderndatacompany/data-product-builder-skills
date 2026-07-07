MODEL (
  name s3depot.qcommerce_delivery_gold.daily_delivery_kpis,
  kind FULL,
  owner 'shreyasikarwartmdcio',
  grains [ds, city],
  description 'Daily city-level delivery performance KPIs used as the primary semantic hub for operations monitoring.',
  tags ('gold', 'delivery', 'daily-kpi', 'city'),
  terms ('daily_delivery_kpis', 'sla_breach_rate', 'gross_order_value'),
  columns (
    ds DATE,
    city STRING,
    total_orders INT,
    delivered_orders INT,
    late_orders INT,
    sla_breach_orders INT,
    failed_orders INT,
    gross_order_value DECIMAL(14, 2),
    total_delivery_minutes DOUBLE
  ),
  assertions (
    not_null(columns := (ds, city))
  )
);

SELECT
  order_date AS ds,
  city,
  COUNT(*) AS total_orders,
  SUM(CASE WHEN delivered_ts IS NOT NULL THEN 1 ELSE 0 END) AS delivered_orders,
  SUM(CASE WHEN issue_type = 'late_delivery' THEN 1 ELSE 0 END) AS late_orders,
  SUM(CASE WHEN is_sla_breached THEN 1 ELSE 0 END) AS sla_breach_orders,
  SUM(CASE WHEN is_failed_delivery THEN 1 ELSE 0 END) AS failed_orders,
  ROUND(SUM(order_amount), 2) AS gross_order_value,
  ROUND(SUM(delivery_minutes), 2) AS total_delivery_minutes
FROM s3depot.qcommerce_delivery_silver.order_fulfillment_enriched
GROUP BY order_date, city
ORDER BY ds DESC, city;
