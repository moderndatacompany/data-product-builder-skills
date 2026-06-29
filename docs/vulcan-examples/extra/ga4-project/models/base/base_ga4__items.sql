-- Base GA4 Items Model
-- Unnests and flattens items array from ecommerce events
MODEL (
  name ga4_analytics.base_ga4__items,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'ecommerce', 'items', 'staging', 'base'),
  grains (item_key),
  description 'Base model for GA4 ecommerce items. Unnests items array from ecommerce events to create item-level records with product details.',
  column_descriptions (
    item_key = 'Unique identifier for this item instance in an event',
    event_key = 'Foreign key to the event this item belongs to',
    event_date_dt = 'Event date',
    event_timestamp = 'Event timestamp',
    event_name = 'Event name (purchase, add_to_cart, etc.)',
    client_key = 'Client identifier',
    session_key = 'Session identifier',
    transaction_id = 'Transaction ID for purchase events',
    item_id = 'Product/item ID',
    item_name = 'Product/item name',
    item_brand = 'Product brand',
    item_category = 'Product category (level 1)',
    item_category2 = 'Product category level 2',
    item_category3 = 'Product category level 3',
    item_category4 = 'Product category level 4',
    item_category5 = 'Product category level 5',
    item_variant = 'Product variant',
    item_list_name = 'Name of item list where product was presented',
    item_list_id = 'ID of item list',
    index = 'Position of item in list',
    price = 'Item price',
    price_in_usd = 'Item price in USD',
    quantity = 'Quantity of this item',
    item_revenue = 'Revenue from this item (price * quantity)',
    item_revenue_in_usd = 'Item revenue in USD',
    item_refund = 'Refund amount for this item',
    item_refund_in_usd = 'Item refund in USD',
    coupon = 'Coupon applied to this item',
    affiliation = 'Store or affiliation',
    location_id = 'Physical location ID',
    creative_name = 'Creative name for marketing attribution',
    creative_slot = 'Creative slot position',
    promotion_id = 'Promotion ID',
    promotion_name = 'Promotion name'
  )
);

-- Extract events with items array
WITH events_with_items AS (
  SELECT
    e.event_date,
    e.event_timestamp,
    e.event_name,
    e.user_pseudo_id,
    e.stream_id,
    e.ecommerce,
    e.items,
    e.event_params,
    -- Generate keys
    TO_BASE64(MD5(CONCAT(CAST(e.user_pseudo_id AS STRING), CAST(e.stream_id AS STRING)))) AS client_key,
    PARSE_DATE('%Y%m%d', CAST(e.event_date AS STRING)) AS event_date_dt
  FROM `tmdc-platform-engineering`.`vulcan_ga4_demo`.`events_table` e
  WHERE e.event_name IN ('purchase', 'refund', 'add_to_cart', 'remove_from_cart', 
                         'begin_checkout', 'view_item', 'view_item_list', 'select_item',
                         'view_promotion', 'select_promotion')
    AND e.items IS NOT NULL
    AND ARRAY_LENGTH(e.items) > 0
),

-- Add session key
with_session_key AS (
  SELECT
    *,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    TO_BASE64(MD5(CONCAT(
      client_key,
      CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
    ))) AS session_key
  FROM events_with_items
),

-- Generate event key
with_event_key AS (
  SELECT
    *,
    TO_BASE64(MD5(CONCAT(
      COALESCE(client_key, ''),
      CAST(session_id AS STRING),
      event_name,
      CAST(event_timestamp AS STRING),
      TO_JSON_STRING(event_params)
    ))) AS event_key
  FROM with_session_key
),

-- Unnest items array - Note: items is ARRAY<STRING> in schema, may need adjustment
-- If items contains JSON strings, we'd parse them; for now treating as simple array
items_unnested AS (
  SELECT
    event_key,
    event_date_dt,
    event_timestamp,
    event_name,
    client_key,
    session_key,
    ecommerce.transaction_id,
    item,
    ROW_NUMBER() OVER (PARTITION BY event_key ORDER BY CAST(event_timestamp AS INT64)) AS item_position
  FROM with_event_key,
  UNNEST(items) AS item
),

-- Generate item key and extract item properties if items contain JSON
items_with_key AS (
  SELECT
    *,
    TO_BASE64(MD5(CONCAT(event_key, CAST(item_position AS STRING)))) AS item_key,
    -- If items are JSON strings, parse them. Otherwise, item is the ID
    -- This is a placeholder - adjust based on actual data structure
    item AS item_id,
    item AS item_name
  FROM items_unnested
)

SELECT
  item_key,
  event_key,
  event_date_dt,
  event_timestamp,
  event_name,
  client_key,
  session_key,
  transaction_id,
  item_id,
  item_name,
  NULL AS item_brand,
  NULL AS item_category,
  NULL AS item_category2,
  NULL AS item_category3,
  NULL AS item_category4,
  NULL AS item_category5,
  NULL AS item_variant,
  NULL AS item_list_name,
  NULL AS item_list_id,
  item_position AS index,
  NULL AS price,
  NULL AS price_in_usd,
  1 AS quantity, -- Default to 1 if not specified
  NULL AS item_revenue,
  NULL AS item_revenue_in_usd,
  NULL AS item_refund,
  NULL AS item_refund_in_usd,
  NULL AS coupon,
  NULL AS affiliation,
  NULL AS location_id,
  NULL AS creative_name,
  NULL AS creative_slot,
  NULL AS promotion_id,
  NULL AS promotion_name
FROM items_with_key;

-- NOTE: The items array in the schema is ARRAY<STRING>. If your actual data has
-- more structured item information (as JSON), you'll want to parse those fields.
-- This model provides the framework - adjust the parsing logic based on your data.

