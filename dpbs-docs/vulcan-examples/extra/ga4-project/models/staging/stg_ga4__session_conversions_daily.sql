-- Session Conversions Daily Model
-- Tracks various conversion events per session with daily aggregation
MODEL (
  name ga4_analytics.stg_ga4__session_conversions_daily,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'conversions', 'sessions', 'goals'),
  grains (session_key, conversion_date),
  description 'Session-level conversion metrics aggregated daily. Tracks key conversion events like purchases, sign-ups, and form submissions.',
  column_descriptions (
    session_key = 'Unique session identifier',
    client_key = 'Client identifier',
    conversion_date = 'Date of conversions',
    total_conversions = 'Total conversion events in this session on this date',
    purchase_conversions = 'Number of purchase events',
    sign_up_conversions = 'Number of sign-up/registration events',
    contact_conversions = 'Number of contact form submissions',
    download_conversions = 'Number of download events',
    video_complete_conversions = 'Number of video completion events',
    add_to_cart_conversions = 'Number of add to cart events',
    begin_checkout_conversions = 'Number of checkout initiation events',
    first_conversion_timestamp = 'Timestamp of first conversion in session',
    last_conversion_timestamp = 'Timestamp of last conversion in session'
  )
);

-- Define conversion events (customize based on your needs)
WITH conversion_events AS (
  SELECT
    event_key,
    session_key,
    client_key,
    event_date_dt AS conversion_date,
    event_timestamp,
    event_name,
    -- Classify conversion types
    CASE WHEN event_name IN ('purchase') THEN 1 ELSE 0 END AS is_purchase,
    CASE WHEN event_name IN ('sign_up', 'registration', 'create_account') THEN 1 ELSE 0 END AS is_sign_up,
    CASE WHEN event_name IN ('contact', 'form_submit', 'generate_lead', 'submit_form') THEN 1 ELSE 0 END AS is_contact,
    CASE WHEN event_name IN ('download', 'file_download') THEN 1 ELSE 0 END AS is_download,
    CASE WHEN event_name IN ('video_complete') THEN 1 ELSE 0 END AS is_video_complete,
    CASE WHEN event_name IN ('add_to_cart') THEN 1 ELSE 0 END AS is_add_to_cart,
    CASE WHEN event_name IN ('begin_checkout') THEN 1 ELSE 0 END AS is_begin_checkout
  FROM ga4_analytics.stg_ga4__events
  WHERE event_name IN (
    'purchase',
    'sign_up', 'registration', 'create_account',
    'contact', 'form_submit', 'generate_lead', 'submit_form',
    'download', 'file_download',
    'video_complete',
    'add_to_cart',
    'begin_checkout'
  )
    AND session_key IS NOT NULL
),

-- Aggregate by session and date
session_conversions AS (
  SELECT
    session_key,
    client_key,
    conversion_date,
    
    -- Conversion counts
    COUNT(*) AS total_conversions,
    SUM(is_purchase) AS purchase_conversions,
    SUM(is_sign_up) AS sign_up_conversions,
    SUM(is_contact) AS contact_conversions,
    SUM(is_download) AS download_conversions,
    SUM(is_video_complete) AS video_complete_conversions,
    SUM(is_add_to_cart) AS add_to_cart_conversions,
    SUM(is_begin_checkout) AS begin_checkout_conversions,
    
    -- Timing
    MIN(event_timestamp) AS first_conversion_timestamp,
    MAX(event_timestamp) AS last_conversion_timestamp
    
  FROM conversion_events
  GROUP BY session_key, client_key, conversion_date
)

SELECT * FROM session_conversions;
