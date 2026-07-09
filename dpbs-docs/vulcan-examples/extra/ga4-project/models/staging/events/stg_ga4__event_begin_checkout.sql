-- Begin Checkout Event Model
-- Tracks checkout initiation events for funnel analysis
MODEL (
  name ga4_analytics.stg_ga4__event_begin_checkout,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'events', 'begin_checkout', 'ecommerce', 'funnel'),
  grains (event_key),
  description 'Begin checkout events tracking when users initiate the checkout process. Critical for conversion funnel analysis.',
  column_descriptions (
    event_key = 'Unique event identifier',
    event_timestamp = 'When checkout was initiated',
    event_date = 'Date of checkout initiation',
    client_key = 'Client identifier',
    session_key = 'Session identifier',
    user_pseudo_id = 'GA4 user pseudo ID',
    cart_value = 'Total cart value',
    currency = 'Currency code',
    items_count = 'Number of items in cart',
    coupon = 'Coupon applied',
    device_category = 'Device type',
    platform = 'Platform',
    geo_country = 'User country',
    session_source = 'Traffic source',
    session_medium = 'Traffic medium',
    session_default_channel_grouping = 'Marketing channel'
  )
);

-- Get begin_checkout events
SELECT
  e.event_key,
  e.event_timestamp,
  e.event_date_dt AS event_date,
  e.client_key,
  e.session_key,
  e.user_pseudo_id,
  e.session_id,
  e.page_location,
  e.device_category,
  e.device_operating_system,
  e.device_browser,
  e.platform,
  e.geo_country,
  e.geo_region,
  e.geo_city,
  
  -- Extract checkout params
  (SELECT value.double_value FROM UNNEST(e.event_params) WHERE key = 'value') AS cart_value,
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'currency') AS currency,
  (SELECT value.int_value FROM UNNEST(e.event_params) WHERE key = 'items_count') AS items_count,
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'coupon') AS coupon,
  
  -- Join traffic source
  ts.session_source,
  ts.session_medium,
  ts.session_campaign,
  ts.session_default_channel_grouping

FROM ga4_analytics.stg_ga4__events e
LEFT JOIN ga4_analytics.stg_ga4__sessions_traffic_sources ts
  ON e.session_key = ts.session_key
WHERE e.event_name = 'begin_checkout';

