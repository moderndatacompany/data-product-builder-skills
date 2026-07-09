-- Ecommerce Purchases Fact Table
-- Comprehensive purchase-level metrics with full dimensional context
MODEL (
  name ga4_analytics.fct_ga4__ecommerce_purchases,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'fact', 'ecommerce', 'purchases', 'revenue', 'analytics'),
  grains (transaction_id),
  profiles (
    session_default_channel_grouping,
    device_category,
    geo_country,
    payment_type
  ),
  description 'Purchase transaction fact table with revenue, items, taxes, shipping, and full attribution. Primary table for ecommerce revenue analysis.',
  column_descriptions (
    transaction_id = 'Unique transaction identifier',
    purchase_timestamp = 'When purchase completed',
    purchase_date = 'Date of purchase',
    purchase_year = 'Year of purchase',
    purchase_month = 'Month of purchase',
    purchase_quarter = 'Quarter of purchase',
    purchase_day_of_week = 'Day of week (1=Sunday, 7=Saturday)',
    purchase_hour = 'Hour of purchase (0-23)',
    event_key = 'Event identifier',
    client_key = 'Customer identifier',
    session_key = 'Session identifier',
    purchase_revenue_in_usd = 'Total revenue in USD',
    tax_value_in_usd = 'Tax amount in USD',
    shipping_value_in_usd = 'Shipping cost in USD',
    net_revenue_in_usd = 'Revenue excluding tax and shipping',
    total_item_quantity = 'Total items purchased',
    unique_items = 'Number of unique product types',
    currency = 'Original transaction currency',
    payment_type = 'Payment method',
    coupon = 'Coupon code used',
    has_coupon = 'Boolean - was coupon used',
    shipping_tier = 'Shipping option',
    device_category = 'Device type',
    device_operating_system = 'Operating system',
    device_browser = 'Browser',
    platform = 'Platform',
    geo_country = 'Country',
    geo_region = 'State/region',
    geo_city = 'City',
    geo_continent = 'Continent',
    session_source = 'Traffic source',
    session_medium = 'Traffic medium',
    session_campaign = 'Campaign',
    session_content = 'Campaign content',
    session_default_channel_grouping = 'Marketing channel',
    session_source_category = 'Source category',
    is_first_purchase_session = 'Boolean - first session for user',
    session_number = 'Session number for this user',
    landing_page = 'Session landing page',
    session_duration_seconds = 'Session length',
    session_page_views = 'Page views in session',
    avg_item_price_usd = 'Average price per item'
  )
);

-- Get purchase transactions
WITH purchases AS (
  SELECT
    transaction_id,
    purchase_timestamp,
    purchase_date,
    event_key,
    client_key,
    session_key,
    user_pseudo_id,
    purchase_revenue,
    purchase_revenue_in_usd,
    tax_value,
    tax_value_in_usd,
    shipping_value,
    shipping_value_in_usd,
    total_item_quantity,
    unique_items,
    currency,
    payment_type,
    coupon,
    shipping_tier,
    device_category,
    device_operating_system,
    device_browser,
    platform,
    geo_country,
    geo_region,
    geo_city,
    geo_continent,
    session_source,
    session_medium,
    session_campaign,
    session_content,
    session_term,
    session_default_channel_grouping,
    session_source_category
  FROM ga4_analytics.stg_ga4__ecommerce_purchases
),

-- Add time dimensions
with_time_dims AS (
  SELECT
    *,
    EXTRACT(YEAR FROM purchase_date) AS purchase_year,
    EXTRACT(MONTH FROM purchase_date) AS purchase_month,
    EXTRACT(QUARTER FROM purchase_date) AS purchase_quarter,
    EXTRACT(DAYOFWEEK FROM purchase_date) AS purchase_day_of_week,
    EXTRACT(HOUR FROM TIMESTAMP_MICROS(purchase_timestamp)) AS purchase_hour,
    
    -- Calculate net revenue (excluding tax and shipping)
    COALESCE(purchase_revenue_in_usd, 0) - COALESCE(tax_value_in_usd, 0) - COALESCE(shipping_value_in_usd, 0) AS net_revenue_in_usd,
    
    -- Coupon flag
    CASE WHEN coupon IS NOT NULL THEN TRUE ELSE FALSE END AS has_coupon,
    
    -- Average item price
    CASE
      WHEN total_item_quantity > 0 THEN purchase_revenue_in_usd / total_item_quantity
      ELSE NULL
    END AS avg_item_price_usd
    
  FROM purchases
),

-- Enrich with session context
with_session_context AS (
  SELECT
    wtd.*,
    s.is_first_session AS is_first_purchase_session,
    s.session_number,
    s.landing_page,
    fs.session_duration_seconds,
    fs.total_page_views AS session_page_views
  FROM with_time_dims wtd
  LEFT JOIN ga4_analytics.dim_ga4__sessions s
    ON wtd.session_key = s.session_key
  LEFT JOIN ga4_analytics.fct_ga4__sessions fs
    ON wtd.session_key = fs.session_key
)

SELECT * FROM with_session_context;

