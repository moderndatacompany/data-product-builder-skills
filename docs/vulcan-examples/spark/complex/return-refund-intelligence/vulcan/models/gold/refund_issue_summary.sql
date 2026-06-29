MODEL (
  name qcommerce_returns_gold.refund_issue_summary,
  kind FULL,
  owner 'shreyasikarwartmdcio',
  grains [ds, city, issue_group],
  description 'Daily refund issue-group summary for operational root-cause and finance leakage analysis.',
  tags ('gold', 'refunds', 'issues', 'root-cause'),
  terms ('refund_issue_summary', 'issue_group', 'affected_orders'),
  columns (
    ds DATE,
    city STRING,
    issue_group STRING,
    affected_orders INT,
    affected_customers INT,
    total_refund_amount DECIMAL(14, 2),
    issue_rate DOUBLE
  )
);

WITH city_totals AS (
  SELECT
    order_date AS ds,
    city,
    COUNT(DISTINCT order_id) AS total_orders
  FROM qcommerce_returns_bronze.orders_clean
  GROUP BY
    order_date,
    city
),

issue_base AS (
  SELECT
    refund_date AS ds,
    city,
    issue_group,
    COUNT(DISTINCT order_id) AS affected_orders,
    COUNT(DISTINCT customer_id) AS affected_customers,
    ROUND(SUM(refund_amount), 2) AS total_refund_amount
  FROM qcommerce_returns_silver.refund_enriched
  GROUP BY
    refund_date,
    city,
    issue_group
)

SELECT
  i.ds,
  i.city,
  i.issue_group,
  i.affected_orders,
  i.affected_customers,
  i.total_refund_amount,
  CASE
    WHEN c.total_orders = 0 THEN 0
    ELSE ROUND(i.affected_orders / c.total_orders, 4)
  END AS issue_rate
FROM issue_base i
LEFT JOIN city_totals c
  ON i.ds = c.ds
  AND i.city = c.city