-- Ecommerce Items Fact Table
-- Item-level ecommerce metrics for product performance analysis
MODEL (
  name ga4_analytics.fct_ga4__ecommerce_items,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'fact', 'ecommerce', 'items', 'products', 'analytics'),
  grains (item_key),
  profiles (
    event_name,
    item_category,
    item_brand,
    session_default_channel_grouping,
    device_category
  ),
  description 'Item-level fact table for product analytics. Tracks views, add-to-cart, and purchases at the individual item level.',
  column_descriptions (
    item_key = 'Unique item instance identifier',
    event_key = 'Related event identifier',
    event_name = 'Event type',
    event_date = 'Date of event',
    event_timestamp = 'Timestamp of event',
    client_key = 'Client identifier',
    session_key = 'Session identifier',
    transaction_id = 'Transaction ID for purchases',
    item_id = 'Product ID',
    item_name = 'Product name',
    item_brand = 'Brand',
    item_category = 'Primary category',
    item_category2 = 'Secondary category',
    item_category3 = 'Tertiary category',
    item_variant = 'Product variant',
    item_list_name = 'Product list name',
    list_position = 'Position in list',
    price_in_usd = 'Unit price in USD',
    quantity = 'Quantity',
    item_revenue_in_usd = 'Total revenue from item',
    is_purchased = 'Boolean - was item purchased',
    is_viewed = 'Boolean - was item viewed',
    is_added_to_cart = 'Boolean - was item added to cart',
    device_category = 'Device type',
    platform = 'Platform',
    geo_country = 'Country',
    session_source = 'Traffic source',
    session_medium = 'Traffic medium',
    session_default_channel_grouping = 'Marketing channel',
    promotion_name = 'Promotion name if applicable'
  )
);

-- Get all items with event classification
SELECT
  item_key,
  event_key,
  event_name,
  event_date,
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
  item_variant,
  item_list_name,
  index AS list_position,
  price_in_usd,
  quantity,
  item_revenue_in_usd,
  promotion_name,
  
  -- Event type flags
  CASE WHEN event_name = 'purchase' THEN TRUE ELSE FALSE END AS is_purchased,
  CASE WHEN event_name IN ('view_item', 'view_item_list') THEN TRUE ELSE FALSE END AS is_viewed,
  CASE WHEN event_name = 'add_to_cart' THEN TRUE ELSE FALSE END AS is_added_to_cart,
  
  -- Context
  device_category,
  device_operating_system,
  device_browser,
  platform,
  geo_country,
  geo_region,
  geo_city,
  session_source,
  session_medium,
  session_campaign,
  session_default_channel_grouping

FROM ga4_analytics.stg_ga4__ecommerce_items;

