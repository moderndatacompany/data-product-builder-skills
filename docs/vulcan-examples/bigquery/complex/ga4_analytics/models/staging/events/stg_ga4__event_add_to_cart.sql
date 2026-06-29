-- Add to Cart Event Model
-- Tracks when items are added to shopping cart
MODEL (
  name ga4_analytics.stg_ga4__event_add_to_cart,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'events', 'add_to_cart', 'ecommerce', 'funnel'),
  grains (event_key),
  description 'Add to cart events with product and session context. Used for funnel analysis and cart abandonment tracking.',
  column_descriptions (
    event_key = 'Unique event identifier',
    event_timestamp = 'When item was added to cart',
    event_date = 'Date of add to cart',
    client_key = 'Client identifier',
    session_key = 'Session identifier',
    user_pseudo_id = 'GA4 user pseudo ID',
    item_id = 'Product ID added (if single item)',
    item_name = 'Product name',
    value = 'Value of items added',
    currency = 'Currency code',
    items_count = 'Number of items in event',
    device_category = 'Device type',
    platform = 'Platform',
    geo_country = 'User country',
    session_source = 'Traffic source',
    session_medium = 'Traffic medium',
    session_default_channel_grouping = 'Marketing channel',
    page_location = 'Page where add to cart occurred'
  )
);

-- Get add_to_cart events
SELECT
  e.event_key,
  e.event_timestamp,
  e.event_date_dt AS event_date,
  e.client_key,
  e.session_key,
  e.user_pseudo_id,
  e.session_id,
  e.page_location,
  e.page_path,
  e.page_title,
  e.device_category,
  e.device_operating_system,
  e.device_browser,
  e.platform,
  e.geo_country,
  e.geo_region,
  e.geo_city,
  
  -- Extract add to cart specific params
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'item_id') AS item_id,
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'item_name') AS item_name,
  (SELECT value.double_value FROM UNNEST(e.event_params) WHERE key = 'value') AS value,
  (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'currency') AS currency,
  (SELECT value.int_value FROM UNNEST(e.event_params) WHERE key = 'items_count') AS items_count,
  
  -- Join traffic source
  ts.session_source,
  ts.session_medium,
  ts.session_campaign,
  ts.session_default_channel_grouping

FROM ga4_analytics.stg_ga4__events e
LEFT JOIN ga4_analytics.stg_ga4__sessions_traffic_sources ts
  ON e.session_key = ts.session_key
WHERE e.event_name = 'add_to_cart';

