-- Conversion Funnel Fact Table
-- Tracks user progression through ecommerce conversion funnel
MODEL (
  name ga4_analytics.fct_ga4__conversion_funnel,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'fact', 'funnel', 'conversions', 'ecommerce', 'analytics'),
  grains (client_key),
  description 'User-level conversion funnel metrics tracking progression from view to purchase. Includes funnel step timing and drop-off analysis.',
  column_descriptions (
    client_key = 'User identifier',
    first_visit_date = 'Date of first visit',
    total_sessions = 'Total sessions',
    has_viewed_product = 'Boolean - viewed any product',
    first_product_view_date = 'Date of first product view',
    total_product_views = 'Total product view events',
    has_added_to_cart = 'Boolean - added item to cart',
    first_add_to_cart_date = 'Date of first add to cart',
    total_add_to_cart = 'Total add to cart events',
    has_begun_checkout = 'Boolean - started checkout',
    first_begin_checkout_date = 'Date of first checkout initiation',
    total_begin_checkout = 'Total checkout initiations',
    has_purchased = 'Boolean - completed purchase',
    first_purchase_date = 'Date of first purchase',
    total_purchases = 'Total purchase transactions',
    total_revenue_usd = 'Lifetime revenue',
    days_to_first_add_to_cart = 'Days from first visit to first cart add',
    days_to_first_checkout = 'Days from first visit to first checkout',
    days_to_first_purchase = 'Days from first visit to first purchase',
    view_to_cart_rate = 'Conversion rate: product view to cart',
    cart_to_checkout_rate = 'Conversion rate: cart to checkout',
    checkout_to_purchase_rate = 'Conversion rate: checkout to purchase',
    overall_conversion_rate = 'Conversion rate: first visit to purchase',
    funnel_stage = 'Furthest funnel stage reached',
    is_abandoned_cart = 'Boolean - added to cart but never purchased',
    is_abandoned_checkout = 'Boolean - started checkout but never purchased'
  )
);

-- Get user first visit
WITH user_first_visit AS (
  SELECT
    client_key,
    first_seen_date AS first_visit_date,
    total_sessions
  FROM ga4_analytics.dim_ga4__users
),

-- Get product view metrics
product_views AS (
  SELECT
    client_key,
    MIN(event_date) AS first_product_view_date,
    COUNT(*) AS total_product_views
  FROM ga4_analytics.stg_ga4__ecommerce_items
  WHERE event_name IN ('view_item', 'view_item_list')
  GROUP BY client_key
),

-- Get add to cart metrics
add_to_cart AS (
  SELECT
    client_key,
    MIN(event_date) AS first_add_to_cart_date,
    COUNT(*) AS total_add_to_cart
  FROM ga4_analytics.stg_ga4__event_add_to_cart
  GROUP BY client_key
),

-- Get begin checkout metrics
begin_checkout AS (
  SELECT
    client_key,
    MIN(event_date) AS first_begin_checkout_date,
    COUNT(*) AS total_begin_checkout
  FROM ga4_analytics.stg_ga4__event_begin_checkout
  GROUP BY client_key
),

-- Get purchase metrics
purchases AS (
  SELECT
    client_key,
    MIN(purchase_date) AS first_purchase_date,
    COUNT(DISTINCT transaction_id) AS total_purchases,
    SUM(purchase_revenue_in_usd) AS total_revenue_usd
  FROM ga4_analytics.stg_ga4__ecommerce_purchases
  GROUP BY client_key
),

-- Combine all funnel steps
funnel_combined AS (
  SELECT
    ufv.client_key,
    ufv.first_visit_date,
    ufv.total_sessions,
    
    -- Product views
    pv.first_product_view_date IS NOT NULL AS has_viewed_product,
    pv.first_product_view_date,
    COALESCE(pv.total_product_views, 0) AS total_product_views,
    
    -- Add to cart
    atc.first_add_to_cart_date IS NOT NULL AS has_added_to_cart,
    atc.first_add_to_cart_date,
    COALESCE(atc.total_add_to_cart, 0) AS total_add_to_cart,
    
    -- Begin checkout
    bc.first_begin_checkout_date IS NOT NULL AS has_begun_checkout,
    bc.first_begin_checkout_date,
    COALESCE(bc.total_begin_checkout, 0) AS total_begin_checkout,
    
    -- Purchase
    p.first_purchase_date IS NOT NULL AS has_purchased,
    p.first_purchase_date,
    COALESCE(p.total_purchases, 0) AS total_purchases,
    COALESCE(p.total_revenue_usd, 0) AS total_revenue_usd
    
  FROM user_first_visit ufv
  LEFT JOIN product_views pv USING (client_key)
  LEFT JOIN add_to_cart atc USING (client_key)
  LEFT JOIN begin_checkout bc USING (client_key)
  LEFT JOIN purchases p USING (client_key)
),

-- Calculate days to each step and rates
with_metrics AS (
  SELECT
    *,
    
    -- Days to each funnel step
    DATE_DIFF(first_add_to_cart_date, first_visit_date, DAY) AS days_to_first_add_to_cart,
    DATE_DIFF(first_begin_checkout_date, first_visit_date, DAY) AS days_to_first_checkout,
    DATE_DIFF(first_purchase_date, first_visit_date, DAY) AS days_to_first_purchase,
    
    -- Conversion rates
    CASE
      WHEN total_product_views > 0 THEN total_add_to_cart / total_product_views
      ELSE NULL
    END AS view_to_cart_rate,
    CASE
      WHEN total_add_to_cart > 0 THEN total_begin_checkout / total_add_to_cart
      ELSE NULL
    END AS cart_to_checkout_rate,
    CASE
      WHEN total_begin_checkout > 0 THEN total_purchases / total_begin_checkout
      ELSE NULL
    END AS checkout_to_purchase_rate,
    CASE
      WHEN total_sessions > 0 THEN CAST(has_purchased AS INT64) / total_sessions
      ELSE NULL
    END AS overall_conversion_rate,
    
    -- Funnel stage
    CASE
      WHEN has_purchased THEN 'Purchased'
      WHEN has_begun_checkout THEN 'Began Checkout'
      WHEN has_added_to_cart THEN 'Added to Cart'
      WHEN has_viewed_product THEN 'Viewed Product'
      ELSE 'Visited Only'
    END AS funnel_stage,
    
    -- Abandonment flags
    has_added_to_cart AND NOT has_purchased AS is_abandoned_cart,
    has_begun_checkout AND NOT has_purchased AS is_abandoned_checkout
    
  FROM funnel_combined
)

SELECT * FROM with_metrics;

