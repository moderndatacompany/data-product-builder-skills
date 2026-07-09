-- Staging GA4 Ecommerce Purchases Model
-- Transaction-level purchase data with enriched attributes
MODEL (
  name ga4_analytics.stg_ga4__ecommerce_purchases,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'ecommerce', 'purchases', 'transactions'),
  grains (transaction_id),
  description 'Transaction-level purchase data from GA4 with enriched session, user, and geography attributes. One row per completed purchase transaction.',
  column_descriptions (
    transaction_id = 'Unique transaction identifier',
    purchase_timestamp = 'When the purchase was completed',
    purchase_date = 'Date of purchase',
    event_key = 'Event key for the purchase event',
    client_key = 'Client who made the purchase',
    session_key = 'Session where purchase occurred',
    purchase_revenue = 'Total revenue (original currency)',
    purchase_revenue_in_usd = 'Total revenue in USD',
    tax_value = 'Tax amount (original currency)',
    tax_value_in_usd = 'Tax amount in USD',
    shipping_value = 'Shipping cost (original currency)',
    shipping_value_in_usd = 'Shipping cost in USD',
    total_item_quantity = 'Total items purchased',
    unique_items = 'Number of unique products',
    currency = 'Transaction currency code',
    payment_type = 'Payment method',
    coupon = 'Coupon code used',
    shipping_tier = 'Shipping option selected',
    device_category = 'Device type used for purchase',
    platform = 'Platform (web/mobile/app)',
    geo_country = 'Country of purchaser',
    geo_region = 'Region/state of purchaser',
    geo_city = 'City of purchaser',
    session_source = 'Traffic source for this session',
    session_medium = 'Traffic medium for this session',
    session_campaign = 'Campaign attribution',
    session_default_channel_grouping = 'Marketing channel grouping'
  )
);

-- Get purchase events from base ecommerce
WITH purchases AS (
  SELECT
    transaction_id,
    event_timestamp AS purchase_timestamp,
    event_date_dt AS purchase_date,
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
    shipping_tier
  FROM ga4_analytics.base_ga4__ecommerce_events
  WHERE event_name = 'purchase'
    AND transaction_id IS NOT NULL
),

-- Enrich with session and device context from staging events
enriched_purchases AS (
  SELECT
    p.*,
    e.device_category,
    e.device_operating_system,
    e.device_browser,
    e.platform,
    e.geo_country,
    e.geo_region,
    e.geo_city,
    e.geo_continent
  FROM purchases p
  LEFT JOIN ga4_analytics.stg_ga4__events e
    ON p.event_key = e.event_key
),

-- Add traffic source attribution
with_attribution AS (
  SELECT
    ep.*,
    ts.session_source,
    ts.session_medium,
    ts.session_campaign,
    ts.session_content,
    ts.session_term,
    ts.session_default_channel_grouping,
    ts.session_source_category
  FROM enriched_purchases ep
  LEFT JOIN ga4_analytics.stg_ga4__sessions_traffic_sources ts
    ON ep.session_key = ts.session_key
)

SELECT * FROM with_attribution;

