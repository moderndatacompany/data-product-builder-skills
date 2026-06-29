MODEL (
  name ECOMMERCE_PLATFORM.GOLD.FCT_SESSION_ANALYTICS,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column SESSION_DATE
  ),
  cron '@daily',
  owner 'shreyasikarwartmdcio',
  grains [SESSION_ID],
  description 'Session-level metrics including duration, page views, bounce rate, and conversion flags for user engagement analysis and experience optimization. Aggregates clickstream events to session-level with UTM attribution and device segmentation.',
  tags ('gold', 'fact', 'sessions', 'engagement', 'ecommerce'),
  terms ('session_metrics', 'user_engagement', 'bounce_rate'),
  columns (
    session_id VARCHAR(100),
    user_id VARCHAR(50),
    session_start TIMESTAMP,
    session_date DATE,
    session_end TIMESTAMP,
    session_duration_seconds INTEGER,
    total_events INTEGER,
    pages_visited INTEGER,
    session_utm_source VARCHAR(50),
    session_utm_medium VARCHAR(50),
    session_utm_campaign VARCHAR(50),
    session_device VARCHAR(50),
    has_cart_add BOOLEAN,
    has_checkout_start BOOLEAN,
    has_purchase BOOLEAN,
    session_revenue DECIMAL(10,2),
    is_bounce BOOLEAN,
    is_cart_abandoned BOOLEAN,
    created_at TIMESTAMP
  ),
  
  column_descriptions (
    session_id = 'Unique session identifier (PK) - groups all events in a single visit',
    user_id = 'Registered user identifier (if logged in, NULL for anonymous)',
    session_start = 'Timestamp of the first event in the session',
    session_date = 'Date of the session (used for incremental processing)',
    session_end = 'Timestamp of the last event in the session',
    session_duration_seconds = 'Total session duration in seconds (session_end - session_start)',
    total_events = 'Total number of events (clicks, views, actions) in the session',
    pages_visited = 'Count of distinct pages visited during the session',
    session_utm_source = 'UTM source for the session (first-touch attribution)',
    session_utm_medium = 'UTM medium for the session (first-touch attribution)',
    session_utm_campaign = 'UTM campaign identifier for the session',
    session_device = 'Device type used during the session (Desktop, Mobile, Tablet)',
    has_cart_add = 'Whether the session included an add-to-cart event',
    has_checkout_start = 'Whether the session started the checkout process',
    has_purchase = 'Whether the session completed a purchase',
    session_revenue = 'Total revenue from purchases completed in this session',
    is_bounce = 'Whether the session visited only a single page',
    is_cart_abandoned = 'Whether items were added to cart but no purchase was completed',
    created_at = 'Record creation timestamp'
  ),
  
  column_tags (
    session_id = ('identifier', 'primary-key', 'grain'),
    user_id = ('user', 'identifier'),
    session_start = ('temporal', 'timestamp', 'start'),
    session_date = ('temporal', 'date', 'partition', 'incremental-key'),
    session_end = ('temporal', 'timestamp', 'end'),
    session_duration_seconds = ('duration', 'measure', 'engagement'),
    total_events = ('count', 'measure', 'engagement'),
    pages_visited = ('count', 'measure', 'engagement'),
    session_utm_source = ('source', 'attribution', 'utm'),
    session_utm_medium = ('medium', 'attribution', 'utm'),
    session_utm_campaign = ('campaign', 'attribution', 'utm'),
    session_device = ('device', 'dimension', 'segmentation'),
    has_cart_add = ('flag', 'cart', 'conversion'),
    has_checkout_start = ('flag', 'checkout', 'conversion'),
    has_purchase = ('flag', 'purchase', 'conversion'),
    session_revenue = ('revenue', 'measure', 'financial'),
    is_bounce = ('flag', 'engagement', 'quality'),
    is_cart_abandoned = ('flag', 'cart', 'abandonment'),
    created_at = ('temporal', 'audit', 'metadata')
  ),
  
  assertions (
    not_null(columns := (session_id, session_date, session_start, total_events)),
    unique_values(columns := (session_id)),
    forall(criteria := (session_duration_seconds >= 0, total_events >= 1, pages_visited >= 1)),
    forall(criteria := (session_revenue >= 0))
  ),
  
  profiles (SESSION_ID, USER_ID, SESSION_START, SESSION_DATE, SESSION_END, SESSION_DURATION_SECONDS, TOTAL_EVENTS, PAGES_VISITED, SESSION_UTM_SOURCE, SESSION_UTM_MEDIUM, SESSION_UTM_CAMPAIGN, SESSION_DEVICE, HAS_CART_ADD, HAS_CHECKOUT_START, HAS_PURCHASE, SESSION_REVENUE, IS_BOUNCE, IS_CART_ABANDONED, CREATED_AT)
);

WITH session_raw AS (
  -- Aggregate clickstream events to session level
  SELECT
    e."session_id"::VARCHAR(100) AS session_id,
    MAX(e."user_id")::VARCHAR(50) AS user_id,
    MIN(e."event_timestamp"::TIMESTAMP) AS session_start,
    MIN(e."event_timestamp"::DATE) AS session_date,
    MAX(e."event_timestamp"::TIMESTAMP) AS session_end,
    COUNT(*) AS total_events,
    COUNT(DISTINCT e."page_url") AS pages_visited,
    
    -- UTM attribution (first-touch: take from first event in session)
    MIN(COALESCE(e."utm_source", 'Direct'))::VARCHAR(50) AS session_utm_source,
    MIN(COALESCE(e."utm_medium", 'None'))::VARCHAR(50) AS session_utm_medium,
    MIN(e."utm_campaign")::VARCHAR(50) AS session_utm_campaign,
    
    -- Device (consistent within session)
    MAX(COALESCE(e."device_type", 'Desktop'))::VARCHAR(50) AS session_device,
    
    -- Conversion flags
    MAX(CASE WHEN e."event_type" = 'add_to_cart' THEN 1 ELSE 0 END) AS has_cart_add_int,
    MAX(CASE WHEN e."event_type" = 'checkout_start' THEN 1 ELSE 0 END) AS has_checkout_start_int,
    MAX(CASE WHEN e."event_type" = 'purchase' THEN 1 ELSE 0 END) AS has_purchase_int,
    
    -- Revenue
    COALESCE(SUM(CASE WHEN e."event_type" = 'purchase' THEN e."order_value_usd" ELSE 0 END), 0) AS session_revenue
    
  FROM ECOMMERCE_PLATFORM.BRONZE.WEB_CLICKSTREAM e
  WHERE e."event_timestamp"::DATE BETWEEN @start_date AND @end_date
  GROUP BY e."session_id"
)

SELECT
  session_id,
  user_id,
  session_start,
  session_date,
  session_end,
  DATEDIFF(SECOND, session_start, session_end)::INTEGER AS session_duration_seconds,
  total_events,
  pages_visited,
  session_utm_source,
  session_utm_medium,
  session_utm_campaign,
  session_device,
  CASE WHEN has_cart_add_int = 1 THEN TRUE ELSE FALSE END AS has_cart_add,
  CASE WHEN has_checkout_start_int = 1 THEN TRUE ELSE FALSE END AS has_checkout_start,
  CASE WHEN has_purchase_int = 1 THEN TRUE ELSE FALSE END AS has_purchase,
  ROUND(session_revenue, 2) AS session_revenue,
  CASE WHEN pages_visited <= 1 THEN TRUE ELSE FALSE END AS is_bounce,
  CASE WHEN has_cart_add_int = 1 AND has_purchase_int = 0 THEN TRUE ELSE FALSE END AS is_cart_abandoned,
  CURRENT_TIMESTAMP() AS created_at
FROM session_raw
ORDER BY session_date DESC, session_start DESC;

