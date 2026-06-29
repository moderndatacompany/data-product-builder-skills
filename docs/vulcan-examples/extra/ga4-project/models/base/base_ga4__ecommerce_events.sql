-- Base GA4 Ecommerce Events Model
-- Flattens ecommerce structure from GA4 events for purchase-related events
MODEL (
  name ga4_analytics.base_ga4__ecommerce_events,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'ecommerce', 'staging', 'base'),
  grains (event_key),
  description 'Base model for GA4 ecommerce events. Flattens ecommerce struct and extracts transaction-level data from purchase, refund, and add_to_cart events.',
  column_descriptions (
    event_key = 'Unique event identifier',
    event_date_dt = 'Event date as DATE type',
    event_timestamp = 'Event timestamp in microseconds',
    event_name = 'Event name (purchase, add_to_cart, begin_checkout, etc.)',
    client_key = 'Unique client/device identifier',
    session_key = 'Unique session identifier',
    user_pseudo_id = 'GA4 pseudonymous user ID',
    transaction_id = 'E-commerce transaction ID',
    purchase_revenue = 'Total purchase revenue',
    purchase_revenue_in_usd = 'Purchase revenue converted to USD',
    tax_value = 'Tax amount',
    tax_value_in_usd = 'Tax amount in USD',
    shipping_value = 'Shipping cost',
    shipping_value_in_usd = 'Shipping cost in USD',
    refund_value = 'Refund amount',
    refund_value_in_usd = 'Refund amount in USD',
    total_item_quantity = 'Total quantity of items',
    unique_items = 'Number of unique items',
    currency = 'Transaction currency',
    payment_type = 'Payment method used',
    coupon = 'Coupon code applied',
    shipping_tier = 'Shipping tier selected'
  )
);

-- Extract ecommerce events with flattened structure
WITH ecommerce_events AS (
  SELECT
    e.event_date,
    e.event_timestamp,
    e.event_name,
    e.user_pseudo_id,
    e.stream_id,
    e.ecommerce,
    e.event_params,
    -- Generate keys same as stg_ga4__events for consistency
    TO_BASE64(MD5(CONCAT(CAST(e.user_pseudo_id AS STRING), CAST(e.stream_id AS STRING)))) AS client_key,
    PARSE_DATE('%Y%m%d', CAST(e.event_date AS STRING)) AS event_date_dt
  FROM `tmdc-platform-engineering`.`vulcan_ga4_demo`.`events_table` e
  WHERE e.event_name IN ('purchase', 'refund', 'add_to_cart', 'remove_from_cart', 
                         'begin_checkout', 'add_payment_info', 'add_shipping_info', 
                         'view_cart', 'view_item', 'view_item_list', 'select_item')
    AND e.ecommerce IS NOT NULL
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
  FROM ecommerce_events
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

-- Flatten ecommerce struct and extract additional parameters
flattened AS (
  SELECT
    event_key,
    event_date_dt,
    event_timestamp,
    event_name,
    client_key,
    session_key,
    user_pseudo_id,
    
    -- Ecommerce transaction fields
    ecommerce.transaction_id,
    CAST(ecommerce.purchase_revenue AS FLOAT64) AS purchase_revenue,
    CAST(ecommerce.purchase_revenue_in_usd AS FLOAT64) AS purchase_revenue_in_usd,
    CAST(ecommerce.tax_value AS FLOAT64) AS tax_value,
    CAST(ecommerce.tax_value_in_usd AS FLOAT64) AS tax_value_in_usd,
    CAST(ecommerce.shipping_value AS FLOAT64) AS shipping_value,
    CAST(ecommerce.shipping_value_in_usd AS FLOAT64) AS shipping_value_in_usd,
    CAST(ecommerce.refund_value AS FLOAT64) AS refund_value,
    CAST(ecommerce.refund_value_in_usd AS FLOAT64) AS refund_value_in_usd,
    CAST(ecommerce.total_item_quantity AS INT64) AS total_item_quantity,
    CAST(ecommerce.unique_items AS INT64) AS unique_items,
    
    -- Extract currency and payment info from event params
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'currency') AS currency,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'payment_type') AS payment_type,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'coupon') AS coupon,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'shipping_tier') AS shipping_tier
    
  FROM with_event_key
)

SELECT * FROM flattened;

