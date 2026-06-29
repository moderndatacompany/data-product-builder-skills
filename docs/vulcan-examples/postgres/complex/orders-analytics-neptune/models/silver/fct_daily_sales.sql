-- Daily sales fact table aggregating orders and revenue metrics by day
-- Provides daily-level sales analytics for reporting and trend analysis
MODEL (
  name silver_v1.fct_daily_sales,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column order_date
  ),
  start '2025-01-01',
  cron '@daily',
  grains (order_date, region_id, customer_id, product_id),
  tags ('fact', 'aggregated', 'sales', 'daily', 'silver'),
  terms ('sales.daily_metrics', 'analytics.daily_sales'),
  description 'Daily sales fact table containing aggregated order and revenue metrics by date and region for sales performance tracking and trend analysis',
  column_descriptions (
    order_date = 'Date of orders (aggregation grain) - stored as TIMESTAMP',
    day_of_week = 'Day of the week (Monday, Tuesday, etc.) for trend analysis',
    is_weekend = 'Boolean flag indicating if date falls on weekend (Saturday/Sunday)',
    region_id = 'Foreign key to regions table - geographic region (aggregation grain)',
    region_name = 'Name of the region for easier reporting',
    customer_id = 'Foreign key to customers table - customer who placed orders (aggregation grain)',
    product_id = 'Foreign key to products table - product that was ordered (aggregation grain)',
    total_orders = 'Total number of orders placed on this date in this region by this customer for this product',
    total_items_sold = 'Total quantity of items sold across all orders',
    total_revenue = 'Total revenue (sum of quantity * unit_price) in USD',
    avg_order_value = 'Average order value (total_revenue / total_orders)',
    total_shipments = 'Number of shipments dispatched',
    shipment_rate = 'Percentage of orders that were shipped (total_shipments / total_orders)'
  ),
  column_tags (
    order_date = ('temporal', 'date', 'grain', 'partition_key'),
    day_of_week = ('temporal', 'dimension', 'label'),
    is_weekend = ('temporal', 'dimension', 'flag'),
    region_id = ('foreign_key', 'reference', 'grain'),
    region_name = ('dimension', 'label'),
    customer_id = ('foreign_key', 'reference', 'grain'),
    product_id = ('foreign_key', 'reference', 'grain'),
    total_orders = ('measure', 'metric', 'count'),
    total_items_sold = ('measure', 'metric', 'sum'),
    total_revenue = ('measure', 'financial', 'metric'),
    avg_order_value = ('measure', 'financial', 'metric'),
    total_shipments = ('measure', 'metric', 'count'),
    shipment_rate = ('measure', 'metric', 'percentage')
  ),
  column_terms (
    order_date = ('time.date', 'sales.order_date'),
    day_of_week = ('time.day_name', 'calendar.weekday'),
    is_weekend = ('time.weekend_flag', 'calendar.is_weekend'),
    region_id = ('geography.region_id', 'reference.region_id'),
    total_orders = ('sales.order_count', 'metric.total_orders'),
    total_revenue = ('sales.revenue', 'finance.total_revenue'),
    avg_order_value = ('sales.aov', 'finance.average_order_value')
  ),
  -- assertions (
  --   not_null(columns := (order_date, region_id, region_name, customer_id, product_id)),
  --   forall(criteria := (
  --     total_orders >= 0,
  --     total_items_sold >= 0,
  --     total_revenue >= 0,
  --     total_shipments >= 0,
  --     customer_id > 0,
  --     product_id > 0
  --   ))
  -- ),
  profiles (region_name, day_of_week, is_weekend, customer_id, product_id, total_orders, total_revenue, avg_order_value)
);

WITH order_metrics AS (
  SELECT
    DATE(o.order_date) AS order_date,
    c.region_id,
    r.region_name,
    o.customer_id,
    oi.product_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_items_sold,
    SUM(oi.quantity * oi.unit_price) AS total_revenue
  FROM bronze_v1.orders AS o
  INNER JOIN bronze_v1.customers AS c
    ON o.customer_id = c.customer_id
  INNER JOIN bronze_v1.regions AS r
    ON c.region_id = r.region_id
  INNER JOIN bronze_v1.order_items AS oi
    ON o.order_id = oi.order_id
  WHERE DATE(o.order_date) BETWEEN @start_date AND @end_date
  GROUP BY DATE(o.order_date), c.region_id, r.region_name, o.customer_id, oi.product_id
),
shipment_metrics AS (
  SELECT
    DATE(o.order_date) AS order_date,
    c.region_id,
    o.customer_id,
    oi.product_id,
    COUNT(DISTINCT s.shipment_id) AS total_shipments
  FROM bronze_v1.orders AS o
  INNER JOIN bronze_v1.customers AS c
    ON o.customer_id = c.customer_id
  INNER JOIN bronze_v1.order_items AS oi
    ON o.order_id = oi.order_id
  LEFT JOIN bronze_v1.shipments AS s
    ON o.order_id = s.order_id
  WHERE DATE(o.order_date) BETWEEN @start_date AND @end_date
  GROUP BY DATE(o.order_date), c.region_id, o.customer_id, oi.product_id
)
SELECT
  CAST(om.order_date AS TIMESTAMP) AS order_date,
  -- Day pattern analysis fields
  TO_CHAR(om.order_date, 'Day') AS day_of_week,
  CASE 
    WHEN EXTRACT(ISODOW FROM om.order_date) IN (6, 7) THEN TRUE
    ELSE FALSE
  END AS is_weekend,
  om.region_id,
  om.region_name,
  om.customer_id,
  om.product_id,
  om.total_orders,
  om.total_items_sold,
  ROUND(om.total_revenue, 2) AS total_revenue,
  ROUND(om.total_revenue / NULLIF(om.total_orders, 0), 2) AS avg_order_value,
  COALESCE(sm.total_shipments, 0) AS total_shipments,
  ROUND(COALESCE(sm.total_shipments, 0)::NUMERIC / NULLIF(om.total_orders, 0), 4) AS shipment_rate
FROM order_metrics AS om
LEFT JOIN shipment_metrics AS sm
  ON om.order_date = sm.order_date
  AND om.region_id = sm.region_id
  AND om.customer_id = sm.customer_id
  AND om.product_id = sm.product_id

