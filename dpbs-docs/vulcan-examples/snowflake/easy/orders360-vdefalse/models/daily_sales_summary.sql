MODEL (
  name DEMODB.VDEFALSE.DAILY_SALES_SUMMARY,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column SALES_DATE
  ),
  start '2025-01-01',
  cron '@daily',
  grain SALES_DATE,
  tags ('aggregate', 'sales', 'daily', 'incremental', 'reporting', 'vde_disabled'),
  terms ('sales.daily_summary', 'reporting.daily_kpi'),
  description 'Daily sales summary aggregate built incrementally from the orders fact. Emits one row per ORDER_DATE with order count, distinct customer count, total quantity, gross revenue, average order value, total tax, and total shipping.',
  assertions (
    not_null(columns := (SALES_DATE, TOTAL_ORDERS))
  ),
  column_descriptions (
    SALES_DATE       = 'Sales day (incremental time column)',
    TOTAL_ORDERS     = 'Count of distinct orders placed on this day',
    UNIQUE_CUSTOMERS = 'Count of distinct customers who placed orders on this day',
    TOTAL_QUANTITY   = 'Sum of item quantity across all orders on this day',
    TOTAL_REVENUE    = 'Sum of order totals on this day (gross revenue including tax and shipping)',
    AVG_ORDER_VALUE  = 'Average order total on this day',
    TOTAL_TAX        = 'Sum of tax collected on this day',
    TOTAL_SHIPPING   = 'Sum of shipping cost on this day'
  ),
  column_tags (
    SALES_DATE       = ('temporal', 'date', 'time_column', 'grain'),
    TOTAL_ORDERS     = ('measure', 'metric', 'count'),
    UNIQUE_CUSTOMERS = ('measure', 'metric', 'count'),
    TOTAL_QUANTITY   = ('measure', 'inventory', 'count'),
    TOTAL_REVENUE    = ('measure', 'financial', 'revenue'),
    AVG_ORDER_VALUE  = ('measure', 'financial', 'average'),
    TOTAL_TAX        = ('measure', 'financial', 'amount'),
    TOTAL_SHIPPING   = ('measure', 'financial', 'amount')
  ),
  column_terms (
    SALES_DATE       = ('sales.date', 'reporting.date'),
    TOTAL_ORDERS     = ('sales.order_count', 'metric.daily_orders'),
    UNIQUE_CUSTOMERS = ('sales.unique_customer_count', 'metric.daily_unique_customers'),
    TOTAL_REVENUE    = ('sales.gross_revenue', 'finance.daily_revenue'),
    AVG_ORDER_VALUE  = ('sales.aov', 'finance.average_order_value')
  )
);

SELECT
  ORDER_DATE::DATE AS SALES_DATE,
  COUNT(DISTINCT ORDER_ID)::INTEGER AS TOTAL_ORDERS,
  COUNT(DISTINCT CUSTOMER_ID)::INTEGER AS UNIQUE_CUSTOMERS,
  SUM(QUANTITY)::INTEGER AS TOTAL_QUANTITY,
  SUM(TOTAL_AMOUNT)::FLOAT AS TOTAL_REVENUE,
  AVG(TOTAL_AMOUNT)::FLOAT AS AVG_ORDER_VALUE,
  SUM(TAX)::FLOAT AS TOTAL_TAX,
  SUM(SHIPPING_COST)::FLOAT AS TOTAL_SHIPPING
FROM DEMODB.VDEFALSE.ORDERS
WHERE ORDER_DATE::DATE BETWEEN @start_date AND @end_date
GROUP BY ORDER_DATE
