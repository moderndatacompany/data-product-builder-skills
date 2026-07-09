MODEL (
  name ECOMMERCE_PLATFORM.GOLD.FCT_CONVERSION_FUNNEL,
  kind FULL,
  cron '@daily',
  owner 'shreyasikarwartmdcio',
  grains [SESSION_ID],
  description 'Session-level conversion funnel data tracking whether each session progressed through cart, checkout, and purchase stages. Aggregation (total sessions, conversion rates, revenue metrics) is handled by the semantic layer.',
  tags ('gold', 'fact', 'conversion', 'funnel-analysis', 'ecommerce'),
  terms ('conversion_funnel', 'drop_off_analysis', 'purchase_funnel'),
  columns (
    session_id VARCHAR(100),
    funnel_date DATE,
    traffic_source VARCHAR(50),
    device_type VARCHAR(50),
    has_cart INTEGER,
    has_checkout INTEGER,
    has_purchase INTEGER,
    order_value_usd DECIMAL(10,2),
    calculated_at TIMESTAMP
  ),
  
  column_descriptions (
    session_id = 'Unique session identifier (PK)',
    funnel_date = 'Date of the session for funnel analysis',
    traffic_source = 'Traffic source category (Google Ads, Email, Direct, etc.)',
    device_type = 'Device type used (Desktop, Mobile, Tablet)',
    has_cart = 'Flag (1/0) indicating if session had an add-to-cart event',
    has_checkout = 'Flag (1/0) indicating if session started the checkout process',
    has_purchase = 'Flag (1/0) indicating if session completed a purchase',
    order_value_usd = 'Revenue from purchase event in this session (0 if no purchase)',
    calculated_at = 'Timestamp when this record was calculated'
  ),
  
  column_tags (
    session_id = ('identifier', 'primary-key', 'grain'),
    funnel_date = ('temporal', 'date', 'partition'),
    traffic_source = ('source', 'dimension', 'attribution'),
    device_type = ('device', 'dimension', 'segmentation'),
    has_cart = ('flag', 'funnel', 'cart'),
    has_checkout = ('flag', 'funnel', 'checkout'),
    has_purchase = ('flag', 'funnel', 'purchase', 'conversion'),
    order_value_usd = ('revenue', 'measure', 'financial'),
    calculated_at = ('temporal', 'audit', 'metadata')
  ),
  
  assertions (
    not_null(columns := (session_id, funnel_date, traffic_source, device_type)),
    unique_values(columns := (session_id)),
    forall(criteria := (has_cart >= 0, has_cart <= 1, has_checkout >= 0, has_checkout <= 1, has_purchase >= 0, has_purchase <= 1)),
    forall(criteria := (order_value_usd >= 0))
  ),
  
  profiles (SESSION_ID, FUNNEL_DATE, TRAFFIC_SOURCE, DEVICE_TYPE, HAS_CART, HAS_CHECKOUT, HAS_PURCHASE, ORDER_VALUE_USD, CALCULATED_AT)
);

WITH session_events AS (
  -- Aggregate clickstream events to session level (one row per session)
  SELECT
    e."session_id"::VARCHAR(100) AS session_id,
    e."event_timestamp"::DATE AS funnel_date,
    COALESCE(e."utm_source", 'Direct')::VARCHAR(50) AS traffic_source,
    COALESCE(e."device_type", 'Desktop')::VARCHAR(50) AS device_type,
    MAX(CASE WHEN e."event_type" = 'add_to_cart' THEN 1 ELSE 0 END) AS has_cart,
    MAX(CASE WHEN e."event_type" = 'checkout_start' THEN 1 ELSE 0 END) AS has_checkout,
    MAX(CASE WHEN e."event_type" = 'purchase' THEN 1 ELSE 0 END) AS has_purchase,
    COALESCE(MAX(CASE WHEN e."event_type" = 'purchase' THEN e."order_value_usd" ELSE 0 END), 0) AS order_value_usd
  FROM ECOMMERCE_PLATFORM.BRONZE.WEB_CLICKSTREAM e
  GROUP BY e."session_id", e."event_timestamp"::DATE, e."utm_source", e."device_type"
)

SELECT
  session_id,
  funnel_date,
  traffic_source,
  device_type,
  has_cart,
  has_checkout,
  has_purchase,
  ROUND(order_value_usd, 2) AS order_value_usd,
  CURRENT_TIMESTAMP() AS calculated_at
FROM session_events
ORDER BY funnel_date DESC;
