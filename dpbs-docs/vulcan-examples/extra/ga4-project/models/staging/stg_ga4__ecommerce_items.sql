-- Staging GA4 Ecommerce Items Model
-- Item-level ecommerce data enriched with event and session context
MODEL (
  name ga4_analytics.stg_ga4__ecommerce_items,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'ecommerce', 'items', 'products'),
  grains (item_key),
  description 'Item-level ecommerce data from GA4 events. Includes product details, pricing, and context from add_to_cart, purchase, and view events.',
  column_descriptions (
    item_key = 'Unique item instance identifier',
    event_key = 'Related event identifier',
    event_name = 'Event type (purchase, add_to_cart, view_item, etc.)',
    event_date = 'Date of the event',
    event_timestamp = 'Timestamp of the event',
    client_key = 'Client identifier',
    session_key = 'Session identifier',
    transaction_id = 'Transaction ID (for purchase/refund events)',
    item_id = 'Product ID',
    item_name = 'Product name',
    item_brand = 'Product brand',
    item_category = 'Primary product category',
    item_category2 = 'Secondary category',
    item_category3 = 'Tertiary category',
    item_variant = 'Product variant (size, color, etc.)',
    item_list_name = 'Product list where item appeared',
    index = 'Position in list',
    price = 'Unit price',
    price_in_usd = 'Unit price in USD',
    quantity = 'Quantity',
    item_revenue_in_usd = 'Total revenue from this item in USD',
    device_category = 'Device used',
    platform = 'Platform',
    geo_country = 'User country',
    session_source = 'Traffic source',
    session_medium = 'Traffic medium',
    session_default_channel_grouping = 'Marketing channel'
  )
);

-- Start with base items
WITH base_items AS (
  SELECT
    item_key,
    event_key,
    event_name,
    event_date_dt AS event_date,
    event_timestamp,
    client_key,
    session_key,
    transaction_id,
    item_id,
    item_name,
    item_brand,
    item_category,
    item_category2,
    item_category3,
    item_category4,
    item_category5,
    item_variant,
    item_list_name,
    item_list_id,
    index,
    price,
    price_in_usd,
    quantity,
    item_revenue_in_usd,
    coupon,
    affiliation,
    creative_name,
    promotion_id,
    promotion_name
  FROM ga4_analytics.base_ga4__items
),

-- Enrich with event context
with_event_context AS (
  SELECT
    i.*,
    e.device_category,
    e.device_operating_system,
    e.device_browser,
    e.platform,
    e.geo_country,
    e.geo_region,
    e.geo_city
  FROM base_items i
  LEFT JOIN ga4_analytics.stg_ga4__events e
    ON i.event_key = e.event_key
),

-- Add session traffic source
with_traffic_source AS (
  SELECT
    ec.*,
    ts.session_source,
    ts.session_medium,
    ts.session_campaign,
    ts.session_default_channel_grouping
  FROM with_event_context ec
  LEFT JOIN ga4_analytics.stg_ga4__sessions_traffic_sources ts
    ON ec.session_key = ts.session_key
)

SELECT * FROM with_traffic_source;

