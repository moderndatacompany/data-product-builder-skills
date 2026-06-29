-- Weekly sales fact table aggregating orders and revenue metrics by week
-- Provides weekly-level sales analytics for trend analysis and forecasting
MODEL (
    name curated.fct_weekly_sales,
    kind FULL,
    cron '*/5 * * * *',
    grains (
        week_start_date,
        region_id,
        customer_id,
        product_id
    ),
    tags (
        'fact',
        'aggregated',
        'sales',
        'weekly',
        'silver'
    ),
    terms (
        'sales.weekly_metrics',
        'analytics.weekly_sales'
    ),
    description 'Weekly sales fact table containing aggregated order and revenue metrics by week and region for sales performance tracking, trend analysis, and week-over-week comparisons',
    column_descriptions (
        week_start_date = 'Start date of the week (Monday) - aggregation grain - stored as TIMESTAMP',
        week_end_date = 'End date of the week (Sunday)',
        year = 'Calendar year of the week',
        week_number = 'ISO week number within the year (1-53)',
        region_id = 'Foreign key to regions table - geographic region (aggregation grain)',
        region_name = 'Name of the region for easier reporting',
        customer_id = 'Foreign key to customers table - customer who placed orders (aggregation grain)',
        product_id = 'Foreign key to products table - product that was ordered (aggregation grain)',
        total_orders = 'Total number of orders placed during this week in this region by this customer for this product',
        total_items_sold = 'Total quantity of items sold across all orders',
        total_revenue = 'Total revenue (sum of quantity * unit_price) in USD',
        avg_order_value = 'Average order value (total_revenue / total_orders)',
        avg_daily_revenue = 'Average daily revenue for the week (total_revenue / 7)',
        total_shipments = 'Number of shipments dispatched during this week',
        shipment_rate = 'Percentage of orders that were shipped (total_shipments / total_orders)'
    ),
    column_tags (
        week_start_date = ('temporal', 'date', 'grain'),
        week_end_date = ('temporal', 'date'),
        year = ('temporal', 'attribute'),
        week_number = ('temporal', 'attribute'),
        region_id = (
            'foreign_key',
            'reference',
            'grain'
        ),
        region_name = ('dimension', 'label'),
        customer_id = (
            'foreign_key',
            'reference',
            'grain'
        ),
        product_id = (
            'foreign_key',
            'reference',
            'grain'
        ),
        total_orders = ('measure', 'metric', 'count'),
        total_items_sold = ('measure', 'metric', 'sum'),
        total_revenue = (
            'measure',
            'financial',
            'metric'
        ),
        avg_order_value = (
            'measure',
            'financial',
            'metric'
        ),
        avg_daily_revenue = (
            'measure',
            'financial',
            'metric'
        ),
        total_shipments = ('measure', 'metric', 'count'),
        shipment_rate = (
            'measure',
            'metric',
            'percentage'
        )
    ),
    column_terms (
        week_start_date = (
            'time.week_start',
            'calendar.week_start_date'
        ),
        region_id = (
            'geography.region_id',
            'reference.region_id'
        ),
        total_orders = (
            'sales.order_count',
            'metric.total_orders'
        ),
        total_revenue = (
            'sales.revenue',
            'finance.total_revenue'
        ),
        avg_order_value = (
            'sales.aov',
            'finance.average_order_value'
        )
    ),
    -- assertions (
    --     unique_combination_of_columns (
    --         columns := (
    --             week_start_date,
    --             region_id,
    --             customer_id,
    --             product_id
    --         )
    --     ),
    --     not_null (
    --         columns := (
    --             week_start_date,
    --             week_end_date,
    --             year,
    --             week_number,
    --             region_id,
    --             region_name,
    --             customer_id,
    --             product_id
    --         )
    --     ),
    --     forall (
    --         criteria := (
    --             total_orders >= 0,
    --             total_items_sold >= 0,
    --             total_revenue >= 0,
    --             total_shipments >= 0,
    --             avg_daily_revenue >= 0,
    --             customer_id > 0,
    --             product_id > 0
    --         )
    --     ),
    --     accepted_range (
    --         column := shipment_rate,
    --         min_v := 0,
    --         max_v := 1
    --     ),
    --     accepted_range (
    --         column := week_number,
    --         min_v := 1,
    --         max_v := 53
    --     )
    -- ),
    -- assertions (
    --     not_null (
    --         columns := (
    --             week_start_date,
    --             week_end_date,
    --             year,
    --             week_number,
    --             region_id,
    --             region_name,
    --             customer_id,
    --             product_id
    --         )
    --     ),
    --     forall (
    --         criteria := (
    --             total_orders >= 0,
    --             total_items_sold >= 0,
    --             total_revenue >= 0,
    --             total_shipments >= 0,
    --             avg_daily_revenue >= 0,
    --             customer_id > 0,
    --             product_id > 0
    --         )
    --     ),
    --     accepted_range (
    --         column := week_number,
    --         min_v := 1,
    --         max_v := 53
    --     )
    -- ),
    profiles (
        region_name,
        customer_id,
        product_id,
        total_orders,
        total_revenue,
        avg_order_value,
        avg_daily_revenue
    )
);

WITH order_metrics AS (
  SELECT
    DATE_TRUNC('week', o.order_date)::DATE AS week_start_date,
    (DATE_TRUNC('week', o.order_date) + INTERVAL '6 days')::DATE AS week_end_date,
    EXTRACT(YEAR FROM o.order_date)::INTEGER AS year,
    EXTRACT(WEEK FROM o.order_date)::INTEGER AS week_number,
    c.region_id,
    r.region_name,
    o.customer_id,
    oi.product_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_items_sold,
    SUM(oi.quantity * oi.unit_price) AS total_revenue
  from raw.orders AS o
  INNER JOIN bronze.customers AS c
    ON o.customer_id = c.customer_id
  INNER JOIN bronze.regions AS r
    ON c.region_id = r.region_id
  INNER JOIN bronze.order_items AS oi
    ON o.order_id = oi.order_id
  GROUP BY 
    DATE_TRUNC('week', o.order_date)::DATE,
    (DATE_TRUNC('week', o.order_date) + INTERVAL '6 days')::DATE,
    EXTRACT(YEAR FROM o.order_date)::INTEGER,
    EXTRACT(WEEK FROM o.order_date)::INTEGER,
    c.region_id,
    r.region_name,
    o.customer_id,
    oi.product_id
),
shipment_metrics AS (
  SELECT
    DATE_TRUNC('week', o.order_date)::DATE AS week_start_date,
    c.region_id,
    o.customer_id,
    oi.product_id,
    COUNT(DISTINCT s.shipment_id) AS total_shipments
  from raw.orders AS o
  INNER JOIN bronze.customers AS c
    ON o.customer_id = c.customer_id
  INNER JOIN bronze.order_items AS oi
    ON o.order_id = oi.order_id
  LEFT JOIN bronze.shipments AS s
    ON o.order_id = s.order_id
  GROUP BY 
    DATE_TRUNC('week', o.order_date)::DATE,
    c.region_id,
    o.customer_id,
    oi.product_id
)
SELECT
  CAST(om.week_start_date AS TIMESTAMP) AS week_start_date,
  om.week_end_date,
  om.year,
  om.week_number,
  om.region_id,
  om.region_name,
  om.customer_id,
  om.product_id,
  om.total_orders,
  om.total_items_sold,
  ROUND(om.total_revenue, 2) AS total_revenue,
  ROUND(om.total_revenue / NULLIF(om.total_orders, 0), 2) AS avg_order_value,
  ROUND(om.total_revenue / 7.0, 2) AS avg_daily_revenue,
  COALESCE(sm.total_shipments, 0) AS total_shipments,
  ROUND(COALESCE(sm.total_shipments, 0)::NUMERIC / NULLIF(om.total_orders, 0), 4) AS shipment_rate
FROM order_metrics AS om
LEFT JOIN shipment_metrics AS sm
  ON om.week_start_date = sm.week_start_date
  AND om.region_id = sm.region_id
  AND om.customer_id = sm.customer_id
  AND om.product_id = sm.product_id