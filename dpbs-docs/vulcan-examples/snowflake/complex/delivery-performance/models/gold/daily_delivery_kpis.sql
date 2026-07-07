MODEL (
  name QCOMMERCE_PLATFORM.GOLD.DAILY_DELIVERY_KPIS,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column DS
  ),
  cron '*/15 * * * *',
  owner 'shreyasikarwartmdcio',
  grains [DS, CITY],
  description 'Daily city-level delivery performance KPIs used as the primary semantic hub for operations monitoring.',
  tags ('gold', 'delivery', 'daily-kpi', 'city'),
  terms ('daily_delivery_kpis', 'sla_breach_rate', 'gross_order_value'),
  profiles (CITY, TOTAL_ORDERS, SLA_BREACH_ORDERS, FAILED_ORDERS),
  columns (
    DS DATE,
    CITY VARCHAR(100),
    TOTAL_ORDERS INTEGER,
    DELIVERED_ORDERS INTEGER,
    LATE_ORDERS INTEGER,
    SLA_BREACH_ORDERS INTEGER,
    FAILED_ORDERS INTEGER,
    GROSS_ORDER_VALUE DECIMAL(14, 2),
    TOTAL_DELIVERY_MINUTES FLOAT
  ),
  column_descriptions (
    DS = 'Business date for the city-level delivery KPI snapshot',
    CITY = 'City for which delivery KPIs are aggregated',
    TOTAL_ORDERS = 'Total number of orders observed for the city-day',
    DELIVERED_ORDERS = 'Number of successfully delivered orders for the city-day',
    LATE_ORDERS = 'Number of orders classified as late deliveries',
    SLA_BREACH_ORDERS = 'Number of orders that breached the delivery SLA',
    FAILED_ORDERS = 'Number of orders that failed delivery',
    GROSS_ORDER_VALUE = 'Total gross order value for the city-day',
    TOTAL_DELIVERY_MINUTES = 'Total delivery minutes accumulated across all orders in the city-day'
  ),
  column_tags (
    DS = ('temporal', 'date', 'grain'),
    CITY = ('dimension', 'geography', 'grain'),
    TOTAL_ORDERS = ('measure', 'count', 'volume'),
    DELIVERED_ORDERS = ('measure', 'count', 'delivery'),
    LATE_ORDERS = ('measure', 'count', 'sla'),
    SLA_BREACH_ORDERS = ('measure', 'count', 'sla'),
    FAILED_ORDERS = ('measure', 'count', 'delivery_failure'),
    GROSS_ORDER_VALUE = ('measure', 'currency', 'revenue'),
    TOTAL_DELIVERY_MINUTES = ('measure', 'duration', 'delivery')
  ),
  column_terms (
    DS = ('ds', 'business_date', 'metric_date'),
    CITY = ('city', 'delivery_city', 'service_area'),
    TOTAL_ORDERS = ('total_orders', 'order_count', 'daily_orders'),
    DELIVERED_ORDERS = ('delivered_orders', 'successful_deliveries', 'completed_orders'),
    LATE_ORDERS = ('late_orders', 'sla_breach_orders', 'delayed_orders'),
    SLA_BREACH_ORDERS = ('sla_breach_orders', 'late_orders', 'sla_failures'),
    FAILED_ORDERS = ('failed_orders', 'delivery_failures', 'undelivered_orders'),
    GROSS_ORDER_VALUE = ('gross_order_value', 'gov', 'daily_order_value'),
    TOTAL_DELIVERY_MINUTES = ('total_delivery_minutes', 'delivery_minutes_total', 'summed_delivery_minutes')
  ),
  assertions (
    not_null(columns := (DS, CITY))
  ),
  allow_partials true
);

SELECT
  ORDER_DATE AS DS,
  CITY,
  COUNT(*) AS TOTAL_ORDERS,
  SUM(CASE WHEN DELIVERED_TS IS NOT NULL THEN 1 ELSE 0 END) AS DELIVERED_ORDERS,
  SUM(CASE WHEN ISSUE_TYPE = 'late_delivery' THEN 1 ELSE 0 END) AS LATE_ORDERS,
  SUM(CASE WHEN IS_SLA_BREACHED THEN 1 ELSE 0 END) AS SLA_BREACH_ORDERS,
  SUM(CASE WHEN IS_FAILED_DELIVERY THEN 1 ELSE 0 END) AS FAILED_ORDERS,
  ROUND(SUM(ORDER_AMOUNT), 2) AS GROSS_ORDER_VALUE,
  ROUND(SUM(DELIVERY_MINUTES), 2) AS TOTAL_DELIVERY_MINUTES
FROM QCOMMERCE_PLATFORM.SILVER.ORDER_FULFILLMENT_ENRICHED
WHERE ORDER_DATE BETWEEN @start_date AND @end_date
GROUP BY ORDER_DATE, CITY
ORDER BY DS DESC, CITY;
