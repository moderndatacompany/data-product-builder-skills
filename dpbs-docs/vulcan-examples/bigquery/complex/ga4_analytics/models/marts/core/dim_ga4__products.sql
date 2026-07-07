-- Products Dimension Table
-- Dimensional model for products with aggregated metrics
MODEL (
  name ga4_analytics.dim_ga4__products,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'dimension', 'products', 'ecommerce', 'analytics'),
  grains (item_id),
  profiles (
    item_category,
    item_brand
  ),
  description 'Product dimension with aggregated metrics including views, cart additions, purchases, and revenue. One row per unique product.',
  column_descriptions (
    item_id = 'Unique product identifier',
    item_name = 'Product name',
    item_brand = 'Product brand',
    item_category = 'Primary product category',
    item_category2 = 'Secondary category',
    item_category3 = 'Tertiary category',
    total_views = 'Total product views across all time',
    total_add_to_cart = 'Total times added to cart',
    total_purchases = 'Total purchase transactions containing this product',
    total_quantity_sold = 'Total units sold',
    total_revenue_usd = 'Total revenue generated',
    avg_price_usd = 'Average selling price',
    first_seen_date = 'First date product appeared in events',
    last_seen_date = 'Most recent date product appeared',
    conversion_rate = 'Purchase rate (purchases / views)',
    cart_to_purchase_rate = 'Rate of cart adds that converted to purchase'
  )
);

-- Aggregate product metrics
WITH product_events AS (
  SELECT
    item_id,
    item_name,
    item_brand,
    item_category,
    item_category2,
    item_category3,
    event_name,
    event_date,
    quantity,
    item_revenue_in_usd,
    price_in_usd
  FROM ga4_analytics.stg_ga4__ecommerce_items
  WHERE item_id IS NOT NULL
),

product_metrics AS (
  SELECT
    item_id,
    -- Use most recent name/brand/category as the current values
    ARRAY_AGG(item_name IGNORE NULLS ORDER BY event_date DESC LIMIT 1)[OFFSET(0)] AS item_name,
    ARRAY_AGG(item_brand IGNORE NULLS ORDER BY event_date DESC LIMIT 1)[OFFSET(0)] AS item_brand,
    ARRAY_AGG(item_category IGNORE NULLS ORDER BY event_date DESC LIMIT 1)[OFFSET(0)] AS item_category,
    ARRAY_AGG(item_category2 IGNORE NULLS ORDER BY event_date DESC LIMIT 1)[OFFSET(0)] AS item_category2,
    ARRAY_AGG(item_category3 IGNORE NULLS ORDER BY event_date DESC LIMIT 1)[OFFSET(0)] AS item_category3,
    
    -- Aggregate metrics
    COUNTIF(event_name IN ('view_item', 'view_item_list')) AS total_views,
    COUNTIF(event_name = 'add_to_cart') AS total_add_to_cart,
    COUNTIF(event_name = 'purchase') AS total_purchases,
    SUM(CASE WHEN event_name = 'purchase' THEN quantity ELSE 0 END) AS total_quantity_sold,
    SUM(CASE WHEN event_name = 'purchase' THEN item_revenue_in_usd ELSE 0 END) AS total_revenue_usd,
    AVG(CASE WHEN event_name = 'purchase' AND price_in_usd > 0 THEN price_in_usd ELSE NULL END) AS avg_price_usd,
    
    -- Date range
    MIN(event_date) AS first_seen_date,
    MAX(event_date) AS last_seen_date
    
  FROM product_events
  GROUP BY item_id
),

-- Calculate conversion rates
with_rates AS (
  SELECT
    *,
    CASE
      WHEN total_views > 0 THEN total_purchases / total_views
      ELSE NULL
    END AS conversion_rate,
    CASE
      WHEN total_add_to_cart > 0 THEN total_purchases / total_add_to_cart
      ELSE NULL
    END AS cart_to_purchase_rate
  FROM product_metrics
)

SELECT * FROM with_rates;

