MODEL (
  name s3depot.qcommerce_delivery_gold.delivery_issue_summary,
  kind FULL,
  owner 'shreyasikarwartmdcio',
  grains [ds, city, issue_type],
  description 'Daily city-level issue breakdown summarizing operational causes of delivery problems for root-cause trending.',
  tags ('gold', 'delivery', 'issues', 'root-cause'),
  terms ('delivery_issue_summary', 'issue_count', 'affected_orders'),
  columns (
    ds DATE,
    city STRING,
    issue_type STRING,
    issue_count INT,
    affected_orders INT,
    total_orders INT
  )
);

WITH city_totals AS (
  SELECT
    order_date AS ds,
    city,
    COUNT(*) AS total_orders
  FROM s3depot.qcommerce_delivery_silver.order_fulfillment_enriched
  GROUP BY order_date, city
)
SELECT
  f.order_date AS ds,
  f.city,
  f.issue_type,
  COUNT(*) AS issue_count,
  COUNT(DISTINCT f.order_id) AS affected_orders,
  MAX(t.total_orders) AS total_orders
FROM s3depot.qcommerce_delivery_silver.order_fulfillment_enriched f
JOIN city_totals t
  ON f.order_date = t.ds
 AND f.city = t.city
WHERE f.issue_type <> 'on_time'
GROUP BY f.order_date, f.city, f.issue_type
ORDER BY ds DESC, city, issue_type;
