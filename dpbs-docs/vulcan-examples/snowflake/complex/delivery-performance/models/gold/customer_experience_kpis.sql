MODEL (
  name QCOMMERCE_PLATFORM.GOLD.CUSTOMER_EXPERIENCE_KPIS,
  kind FULL,
  cron '*/15 * * * *',
  owner 'shreyasikarwartmdcio',
  grains [DS, CITY, CUSTOMER_TIER],
  description 'Daily customer-tier delivery experience KPIs for understanding delays, failures, and refund risk across customer segments.',
  tags ('gold', 'customer-experience', 'delivery', 'tier'),
  terms ('customer_experience_kpis', 'customers_impacted', 'refund_rate', 'experience_risk_segment'),
  profiles (CITY, CUSTOMER_TIER, EXPERIENCE_RISK_SEGMENT, TOTAL_ORDERS, LATE_ORDERS),
  columns (
    DS DATE,
    CITY VARCHAR(100),
    CUSTOMER_TIER VARCHAR(50),
    TOTAL_ORDERS INTEGER,
    CUSTOMERS_IMPACTED INTEGER,
    LATE_ORDERS INTEGER,
    FAILED_ORDERS INTEGER,
    TOTAL_ORDER_VALUE DECIMAL(12, 2),
    REFUNDED_ORDERS INTEGER,
    TOTAL_REFUND_AMOUNT DECIMAL(12, 2),
    EXPERIENCE_RISK_SEGMENT VARCHAR(30)
  ),
  column_descriptions (
    DS = 'Business date for the customer experience KPI snapshot',
    CITY = 'City for which customer segment KPIs are aggregated',
    CUSTOMER_TIER = 'Customer segment such as STANDARD, PREMIUM, or VIP',
    TOTAL_ORDERS = 'Total orders observed for the city, date, and customer tier',
    CUSTOMERS_IMPACTED = 'Number of unique customers affected by lateness or failed delivery',
    LATE_ORDERS = 'Number of orders with late delivery for the customer tier slice',
    FAILED_ORDERS = 'Number of orders with failed delivery for the customer tier slice',
    TOTAL_ORDER_VALUE = 'Total order value for the customer tier slice',
    REFUNDED_ORDERS = 'Number of orders with refunded payment outcomes',
    TOTAL_REFUND_AMOUNT = 'Total order value associated with refunded payment outcomes',
    EXPERIENCE_RISK_SEGMENT = 'Derived categorical experience risk label based on order volume, impacted customers, delay, failure, and refund signals for the customer tier slice'
  ),
  column_tags (
    DS = ('temporal', 'date', 'grain'),
    CITY = ('dimension', 'geography', 'grain'),
    CUSTOMER_TIER = ('dimension', 'segment', 'grain'),
    TOTAL_ORDERS = ('measure', 'count', 'volume'),
    CUSTOMERS_IMPACTED = ('measure', 'count_distinct', 'impact'),
    LATE_ORDERS = ('measure', 'count', 'kpi'),
    FAILED_ORDERS = ('measure', 'count', 'kpi'),
    TOTAL_ORDER_VALUE = ('measure', 'currency', 'customer_value'),
    REFUNDED_ORDERS = ('measure', 'count', 'refund'),
    TOTAL_REFUND_AMOUNT = ('measure', 'currency', 'refund'),
    EXPERIENCE_RISK_SEGMENT = ('dimension', 'classification', 'risk')
  ),
  column_terms (
    DS = ('ds', 'business_date', 'metric_date'),
    CITY = ('city', 'delivery_city', 'service_area'),
    CUSTOMER_TIER = ('customer_tier', 'loyalty_tier', 'service_segment'),
    TOTAL_ORDERS = ('total_orders', 'tier_order_count', 'segment_orders'),
    CUSTOMERS_IMPACTED = ('customers_impacted', 'affected_customers', 'impacted_users'),
    LATE_ORDERS = ('late_delivery_orders', 'delay_order_count', 'late_order_count'),
    FAILED_ORDERS = ('failed_delivery_orders', 'failure_order_count', 'failed_order_count'),
    TOTAL_ORDER_VALUE = ('total_order_value', 'basket_value_total', 'segment_order_value'),
    REFUNDED_ORDERS = ('refunded_orders', 'refund_count', 'returned_payment_orders'),
    TOTAL_REFUND_AMOUNT = ('refund_amount_total', 'refunded_value_total', 'refund_value'),
    EXPERIENCE_RISK_SEGMENT = ('experience_risk_segment', 'customer_risk_band', 'experience_health_category')
  ),
  assertions (
    not_null(columns := (DS, CITY, CUSTOMER_TIER))
  )
);

WITH customer_experience_base AS (
  SELECT
    ORDER_DATE AS DS,
    CITY,
    CUSTOMER_TIER,
    COUNT(*) AS TOTAL_ORDERS,
    COUNT(DISTINCT CASE WHEN IS_SLA_BREACHED OR IS_FAILED_DELIVERY THEN CUSTOMER_ID END) AS CUSTOMERS_IMPACTED,
    SUM(CASE WHEN ISSUE_TYPE = 'late_delivery' THEN 1 ELSE 0 END) AS LATE_ORDERS,
    SUM(CASE WHEN IS_FAILED_DELIVERY THEN 1 ELSE 0 END) AS FAILED_ORDERS,
    ROUND(SUM(ORDER_AMOUNT), 2) AS TOTAL_ORDER_VALUE,
    SUM(CASE WHEN NORMALIZED_PAYMENT_STATUS = 'refunded' THEN 1 ELSE 0 END) AS REFUNDED_ORDERS,
    ROUND(SUM(CASE WHEN NORMALIZED_PAYMENT_STATUS = 'refunded' THEN ORDER_AMOUNT ELSE 0 END), 2) AS TOTAL_REFUND_AMOUNT
  FROM QCOMMERCE_PLATFORM.SILVER.ORDER_FULFILLMENT_ENRICHED
  GROUP BY ORDER_DATE, CITY, CUSTOMER_TIER
)
SELECT
  DS,
  CITY,
  CUSTOMER_TIER,
  TOTAL_ORDERS,
  CUSTOMERS_IMPACTED,
  LATE_ORDERS,
  FAILED_ORDERS,
  TOTAL_ORDER_VALUE,
  REFUNDED_ORDERS,
  TOTAL_REFUND_AMOUNT,
  CASE
    WHEN TOTAL_ORDERS = 0 THEN 'unknown'
    WHEN FAILED_ORDERS / NULLIF(TOTAL_ORDERS, 0) >= 0.12
      OR CUSTOMERS_IMPACTED / NULLIF(TOTAL_ORDERS, 0) >= 0.35
      OR TOTAL_REFUND_AMOUNT / NULLIF(TOTAL_ORDER_VALUE, 0) >= 0.10 THEN 'critical'
    WHEN LATE_ORDERS / NULLIF(TOTAL_ORDERS, 0) >= 0.20
      OR REFUNDED_ORDERS / NULLIF(TOTAL_ORDERS, 0) >= 0.08
      OR FAILED_ORDERS + REFUNDED_ORDERS >= 5 THEN 'high_risk'
    WHEN LATE_ORDERS / NULLIF(TOTAL_ORDERS, 0) >= 0.10
      OR CUSTOMERS_IMPACTED >= 3
      OR TOTAL_REFUND_AMOUNT / NULLIF(TOTAL_ORDER_VALUE, 0) >= 0.04 THEN 'watchlist'
    ELSE 'healthy'
  END AS EXPERIENCE_RISK_SEGMENT
FROM customer_experience_base
ORDER BY DS DESC, CITY, CUSTOMER_TIER;
