-- Purchase Event Model
-- Detailed purchase event data with transaction context
MODEL (
  name ga4_analytics.stg_ga4__event_purchase,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'events', 'purchase', 'ecommerce'),
  grains (event_key),
  description 'Purchase event-level data with full transaction and session context. One row per purchase event.',
  column_descriptions (
    event_key = 'Unique event identifier',
    purchase_timestamp = 'When purchase occurred',
    purchase_date = 'Date of purchase',
    transaction_id = 'Transaction identifier',
    client_key = 'Client who made purchase',
    session_key = 'Session of purchase',
    user_pseudo_id = 'GA4 user pseudo ID',
    purchase_revenue_in_usd = 'Total revenue in USD',
    tax_value_in_usd = 'Tax in USD',
    shipping_value_in_usd = 'Shipping in USD',
    total_item_quantity = 'Number of items',
    unique_items = 'Count of unique products',
    currency = 'Currency code',
    payment_type = 'Payment method',
    coupon = 'Coupon applied',
    device_category = 'Device type',
    geo_country = 'Country',
    session_source = 'Traffic source',
    session_medium = 'Traffic medium',
    session_campaign = 'Campaign',
    session_default_channel_grouping = 'Marketing channel',
    is_first_purchase = 'Boolean - is this user first purchase'
  )
);

-- Get purchase events
WITH purchases AS (
  SELECT
    e.event_key,
    e.event_timestamp AS purchase_timestamp,
    e.event_date_dt AS purchase_date,
    e.client_key,
    e.session_key,
    e.user_pseudo_id,
    e.session_id,
    e.device_category,
    e.device_operating_system,
    e.device_browser,
    e.platform,
    e.geo_country,
    e.geo_region,
    e.geo_city,
    
    -- Extract ecommerce values from event_params
    (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'transaction_id') AS transaction_id,
    (SELECT value.double_value FROM UNNEST(e.event_params) WHERE key = 'value') AS purchase_revenue_in_usd,
    (SELECT value.double_value FROM UNNEST(e.event_params) WHERE key = 'tax') AS tax_value_in_usd,
    (SELECT value.double_value FROM UNNEST(e.event_params) WHERE key = 'shipping') AS shipping_value_in_usd,
    (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'currency') AS currency,
    (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'payment_type') AS payment_type,
    (SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = 'coupon') AS coupon,
    (SELECT value.int_value FROM UNNEST(e.event_params) WHERE key = 'items_count') AS total_item_quantity,
    (SELECT value.int_value FROM UNNEST(e.event_params) WHERE key = 'unique_items') AS unique_items
    
  FROM ga4_analytics.stg_ga4__events e
  WHERE e.event_name = 'purchase'
),

-- Add traffic source
with_traffic_source AS (
  SELECT
    p.*,
    ts.session_source,
    ts.session_medium,
    ts.session_campaign,
    ts.session_content,
    ts.session_default_channel_grouping
  FROM purchases p
  LEFT JOIN ga4_analytics.stg_ga4__sessions_traffic_sources ts
    ON p.session_key = ts.session_key
),

-- Detect first purchase per user
user_purchases AS (
  SELECT
    client_key,
    MIN(purchase_timestamp) AS first_purchase_timestamp
  FROM with_traffic_source
  GROUP BY client_key
),

-- Mark first purchases
final AS (
  SELECT
    wts.*,
    CASE
      WHEN wts.purchase_timestamp = up.first_purchase_timestamp THEN TRUE
      ELSE FALSE
    END AS is_first_purchase
  FROM with_traffic_source wts
  LEFT JOIN user_purchases up
    ON wts.client_key = up.client_key
)

SELECT * FROM final;

