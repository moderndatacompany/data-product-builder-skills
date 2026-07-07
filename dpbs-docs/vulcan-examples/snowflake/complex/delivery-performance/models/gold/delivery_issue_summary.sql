MODEL (
  name QCOMMERCE_PLATFORM.GOLD.DELIVERY_ISSUE_SUMMARY,
  kind FULL,
  cron '*/15 * * * *',
  owner 'shreyasikarwartmdcio',
  grains [DS, CITY, ISSUE_TYPE],
  description 'Daily city-level issue breakdown summarizing operational causes of delivery problems for root-cause trending.',
  tags ('gold', 'delivery', 'issues', 'root-cause'),
  terms ('delivery_issue_summary', 'issue_count', 'affected_orders'),
  profiles (CITY, ISSUE_TYPE, ISSUE_COUNT, TOTAL_ORDERS),
  columns (
    DS DATE,
    CITY VARCHAR(100),
    ISSUE_TYPE VARCHAR(50),
    ISSUE_COUNT INTEGER,
    AFFECTED_ORDERS INTEGER,
    TOTAL_ORDERS INTEGER
  ),
  column_descriptions (
    DS = 'Business date for the delivery issue summary snapshot',
    CITY = 'City where the delivery issues were observed',
    ISSUE_TYPE = 'Operational issue category such as late_delivery or missing_scan',
    ISSUE_COUNT = 'Total number of issue rows contributing to the category',
    AFFECTED_ORDERS = 'Number of distinct orders affected by the issue category',
    TOTAL_ORDERS = 'Total number of orders in the city-day used as the issue-rate denominator'
  ),
  column_tags (
    DS = ('temporal', 'date', 'grain'),
    CITY = ('dimension', 'geography', 'grain'),
    ISSUE_TYPE = ('dimension', 'classification', 'grain'),
    ISSUE_COUNT = ('measure', 'count', 'issue'),
    AFFECTED_ORDERS = ('measure', 'count', 'impact'),
    TOTAL_ORDERS = ('measure', 'count', 'volume')
  ),
  column_terms (
    DS = ('ds', 'business_date', 'metric_date'),
    CITY = ('city', 'delivery_city', 'service_area'),
    ISSUE_TYPE = ('issue_type', 'delivery_issue_category', 'root_cause_type'),
    ISSUE_COUNT = ('issue_count', 'issue_volume', 'problem_count'),
    AFFECTED_ORDERS = ('affected_orders', 'impacted_orders', 'orders_with_issue'),
    TOTAL_ORDERS = ('city_order_count', 'daily_order_count', 'issue_rate_denominator')
  )
);

WITH city_totals AS (
  SELECT
    ORDER_DATE AS DS,
    CITY,
    COUNT(*) AS TOTAL_ORDERS
  FROM QCOMMERCE_PLATFORM.SILVER.ORDER_FULFILLMENT_ENRICHED
  GROUP BY ORDER_DATE, CITY
)
SELECT
  f.ORDER_DATE AS DS,
  f.CITY,
  f.ISSUE_TYPE,
  COUNT(*) AS ISSUE_COUNT,
  COUNT(DISTINCT f.ORDER_ID) AS AFFECTED_ORDERS,
  MAX(t.TOTAL_ORDERS) AS TOTAL_ORDERS
FROM QCOMMERCE_PLATFORM.SILVER.ORDER_FULFILLMENT_ENRICHED f
JOIN city_totals t
  ON f.ORDER_DATE = t.DS
 AND f.CITY = t.CITY
WHERE f.ISSUE_TYPE <> 'on_time'
GROUP BY f.ORDER_DATE, f.CITY, f.ISSUE_TYPE
ORDER BY DS DESC, CITY, ISSUE_TYPE;
