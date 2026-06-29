-- Sales funnel analysis tracking customer journey from browsing to shipment
-- Provides conversion metrics and drop-off analysis at each funnel stage
MODEL (
  name gold_v1.sales_funnel_analysis,
  kind FULL,
  cron '@daily',
  grains (funnel_date, region_id),
  tags ('gold', 'analytics', 'funnel', 'conversion', 'sales'),
  terms ('analytics.sales_funnel', 'conversion.funnel_metrics'),
  description 'Sales funnel analysis model tracking customer journey stages from customer registration through order placement to shipment fulfillment, providing conversion rates and drop-off analysis for optimization',
  column_descriptions (
    funnel_date = 'Date of funnel analysis (aggregation grain) - stored as TIMESTAMP',
    region_id = 'Foreign key to regions table - geographic region (aggregation grain)',
    region_name = 'Name of the region',
    stage_1_registered_customers = 'Total customers registered in the region (funnel top)',
    stage_2_customers_with_orders = 'Customers who have placed at least one order',
    stage_3_orders_placed = 'Total number of orders placed',
    stage_4_orders_with_items = 'Orders that have at least one line item',
    stage_5_orders_shipped = 'Orders that have been shipped',
    conversion_rate_registration_to_order = 'Percentage of registered customers who placed orders',
    conversion_rate_order_to_items = 'Percentage of orders that contain items',
    conversion_rate_order_to_shipment = 'Percentage of orders that were shipped',
    overall_conversion_rate = 'End-to-end conversion from registration to shipment',
    drop_off_after_registration = 'Customers who registered but never ordered',
    drop_off_orders_without_items = 'Orders placed but no items added',
    drop_off_orders_not_shipped = 'Orders not yet shipped or abandoned',
    avg_items_per_order = 'Average number of items in orders with items',
    avg_time_to_ship_days = 'Average days from order to shipment'
  ),
  column_tags (
    funnel_date = ('temporal', 'date', 'grain'),
    region_id = ('foreign_key', 'reference', 'grain'),
    region_name = ('dimension', 'label'),
    stage_1_registered_customers = ('measure', 'metric', 'funnel_stage'),
    stage_2_customers_with_orders = ('measure', 'metric', 'funnel_stage'),
    stage_3_orders_placed = ('measure', 'metric', 'funnel_stage'),
    stage_4_orders_with_items = ('measure', 'metric', 'funnel_stage'),
    stage_5_orders_shipped = ('measure', 'metric', 'funnel_stage'),
    conversion_rate_registration_to_order = ('measure', 'metric', 'conversion', 'percentage'),
    conversion_rate_order_to_items = ('measure', 'metric', 'conversion', 'percentage'),
    conversion_rate_order_to_shipment = ('measure', 'metric', 'conversion', 'percentage'),
    overall_conversion_rate = ('measure', 'metric', 'conversion', 'percentage'),
    drop_off_after_registration = ('measure', 'metric', 'drop_off'),
    drop_off_orders_without_items = ('measure', 'metric', 'drop_off'),
    drop_off_orders_not_shipped = ('measure', 'metric', 'drop_off'),
    avg_items_per_order = ('measure', 'metric', 'average'),
    avg_time_to_ship_days = ('measure', 'metric', 'average', 'temporal')
  ),
  column_terms (
    funnel_date = ('time.date', 'analytics.funnel_date'),
    conversion_rate_registration_to_order = ('analytics.conversion_rate', 'funnel.registration_conversion'),
    overall_conversion_rate = ('analytics.overall_conversion', 'funnel.end_to_end_conversion')
  ),
  -- assertions (
  --   unique_combination_of_columns(columns := (funnel_date, region_id)),
  --   not_null(columns := (funnel_date, region_id, region_name)),
  --   forall(criteria := (
  --     stage_1_registered_customers >= 0,
  --     stage_2_customers_with_orders >= 0,
  --     stage_3_orders_placed >= 0,
  --     stage_4_orders_with_items >= 0,
  --     stage_5_orders_shipped >= 0,
  --     stage_2_customers_with_orders <= stage_1_registered_customers,
  --     stage_4_orders_with_items <= stage_3_orders_placed,
  --     stage_5_orders_shipped <= stage_3_orders_placed
  --   )),
  --   accepted_range(column := conversion_rate_registration_to_order, min_v := 0, max_v := 1),
  --   accepted_range(column := conversion_rate_order_to_items, min_v := 0, max_v := 1),
  --   accepted_range(column := conversion_rate_order_to_shipment, min_v := 0, max_v := 1)
  -- ),
  profiles (region_name, overall_conversion_rate, conversion_rate_registration_to_order, conversion_rate_order_to_shipment)
);

WITH stage_1_customers AS (
  -- Stage 1: All registered customers by region (from silver customer profile)
  SELECT
    CURRENT_DATE AS funnel_date,
    cp.region_id,
    cp.region_name,
    COUNT(DISTINCT cp.customer_id) AS registered_customers
  FROM silver_v1.dim_customer_profile AS cp
  GROUP BY cp.region_id, cp.region_name
),
stage_2_ordering_customers AS (
  -- Stage 2: Customers who have placed orders (from silver customer profile)
  SELECT
    cp.region_id,
    COUNT(DISTINCT cp.customer_id) AS customers_with_orders
  FROM silver_v1.dim_customer_profile AS cp
  WHERE cp.total_orders > 0
  GROUP BY cp.region_id
),
stage_3_orders AS (
  -- Stage 3: All orders placed (from silver daily sales)
  SELECT
    ds.region_id,
    COUNT(DISTINCT ds.order_date || '-' || ds.customer_id || '-' || ds.product_id) AS orders_placed,
    AVG(CASE 
      WHEN s.shipped_date IS NOT NULL 
      THEN DATE(s.shipped_date) - DATE(ds.order_date)
      ELSE NULL 
    END) AS avg_time_to_ship_days
  FROM silver_v1.fct_daily_sales AS ds
  LEFT JOIN bronze_v1.orders AS o
    ON DATE(o.order_date) = DATE(ds.order_date)
    AND o.customer_id = ds.customer_id
  LEFT JOIN bronze_v1.shipments AS s
    ON o.order_id = s.order_id
  GROUP BY ds.region_id
),
stage_4_orders_with_items AS (
  -- Stage 4: Orders with line items (from silver daily sales - all records have items)
  SELECT
    ds.region_id,
    COUNT(DISTINCT ds.order_date || '-' || ds.customer_id || '-' || ds.product_id) AS orders_with_items,
    AVG(ds.total_items_sold) AS avg_items_per_order
  FROM silver_v1.fct_daily_sales AS ds
  WHERE ds.total_items_sold > 0
  GROUP BY ds.region_id
),
stage_5_shipped_orders AS (
  -- Stage 5: Orders that were shipped (from silver daily sales with shipments)
  SELECT
    ds.region_id,
    SUM(ds.total_shipments) AS orders_shipped
  FROM silver_v1.fct_daily_sales AS ds
  GROUP BY ds.region_id
)
select *, 'active' as status from (SELECT
  CAST(s1.funnel_date AS TIMESTAMP) AS funnel_date,
  s1.region_id,
  s1.region_name,
  
  -- Funnel Stages
  s1.registered_customers AS stage_1_registered_customers,
  COALESCE(s2.customers_with_orders, 0) AS stage_2_customers_with_orders,
  COALESCE(s3.orders_placed, 0) AS stage_3_orders_placed,
  COALESCE(s4.orders_with_items, 0) AS stage_4_orders_with_items,
  COALESCE(s5.orders_shipped, 0) AS stage_5_orders_shipped,
  
  -- Conversion Rates
  ROUND(
    COALESCE(s2.customers_with_orders, 0)::NUMERIC / NULLIF(s1.registered_customers, 0),
    4
  ) AS conversion_rate_registration_to_order,
  ROUND(
    COALESCE(s4.orders_with_items, 0)::NUMERIC / NULLIF(s3.orders_placed, 0),
    4
  ) AS conversion_rate_order_to_items,
  ROUND(
    COALESCE(s5.orders_shipped, 0)::NUMERIC / NULLIF(s3.orders_placed, 0),
    4
  ) AS conversion_rate_order_to_shipment,
  ROUND(
    COALESCE(s5.orders_shipped, 0)::NUMERIC / NULLIF(s1.registered_customers, 0),
    4
  ) AS overall_conversion_rate,
  
  -- Drop-off Analysis
  s1.registered_customers - COALESCE(s2.customers_with_orders, 0) AS drop_off_after_registration,
  COALESCE(s3.orders_placed, 0) - COALESCE(s4.orders_with_items, 0) AS drop_off_orders_without_items,
  COALESCE(s3.orders_placed, 0) - COALESCE(s5.orders_shipped, 0) AS drop_off_orders_not_shipped,
  
  -- Additional Metrics
  ROUND(COALESCE(s4.avg_items_per_order, 0), 2) AS avg_items_per_order,
  ROUND(COALESCE(s3.avg_time_to_ship_days, 0), 2) AS avg_time_to_ship_days

FROM stage_1_customers AS s1
LEFT JOIN stage_2_ordering_customers AS s2
  ON s1.region_id = s2.region_id
LEFT JOIN stage_3_orders AS s3
  ON s1.region_id = s3.region_id
LEFT JOIN stage_4_orders_with_items AS s4
  ON s1.region_id = s4.region_id
LEFT JOIN stage_5_shipped_orders AS s5
  ON s1.region_id = s5.region_id
)
