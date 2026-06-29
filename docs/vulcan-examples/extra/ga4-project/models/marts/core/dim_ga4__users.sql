-- Users Dimension Table
-- Comprehensive user profile with lifetime metrics and attribution
MODEL (
  name ga4_analytics.dim_ga4__users,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'dimension', 'users', 'customers', 'analytics'),
  grains (client_key),
  profiles (
    first_session_source,
    first_session_medium,
    first_session_default_channel_grouping,
    user_segment
  ),
  description 'User dimension with lifetime behavior, first-touch attribution, geographic and device preferences. One row per unique user/client.',
  column_descriptions (
    client_key = 'Unique user/client identifier',
    user_pseudo_id = 'GA4 user pseudo ID',
    first_seen_date = 'Date of first visit',
    last_seen_date = 'Most recent visit date',
    days_since_first_seen = 'Days between first and last visit',
    total_sessions = 'Total number of sessions',
    total_engaged_sessions = 'Number of engaged sessions',
    engagement_rate = 'Percentage of sessions that were engaged',
    total_page_views = 'Lifetime page views',
    total_events = 'Total events triggered',
    avg_session_duration_seconds = 'Average session length',
    avg_pages_per_session = 'Average pages viewed per session',
    total_conversions = 'Total conversion events',
    total_purchases = 'Number of purchase transactions',
    total_revenue_usd = 'Lifetime revenue generated',
    avg_order_value_usd = 'Average purchase value',
    first_purchase_date = 'Date of first purchase',
    last_purchase_date = 'Date of most recent purchase',
    days_to_first_purchase = 'Days from first visit to first purchase',
    first_session_source = 'Traffic source of first visit',
    first_session_medium = 'Traffic medium of first visit',
    first_session_campaign = 'Campaign of first visit',
    first_session_default_channel_grouping = 'Channel grouping of first visit',
    most_common_device_category = 'Most frequently used device type',
    most_common_platform = 'Most frequently used platform',
    most_common_country = 'Most common country',
    most_common_region = 'Most common region',
    most_common_city = 'Most common city',
    user_segment = 'User segment (New, Engaged, Purchaser, VIP)',
    is_purchaser = 'Boolean - has made at least one purchase',
    is_repeat_purchaser = 'Boolean - has made 2+ purchases'
  )
);

-- Get user session metrics
WITH user_sessions AS (
  SELECT
    client_key,
    session_key,
    session_start_date,
    engaged_session,
    total_page_views,
    total_events,
    session_duration_seconds,
    total_conversions,
    purchase_conversions,
    total_revenue
  FROM ga4_analytics.fct_ga4__sessions
),

user_session_metrics AS (
  SELECT
    client_key,
    MIN(session_start_date) AS first_seen_date,
    MAX(session_start_date) AS last_seen_date,
    COUNT(*) AS total_sessions,
    COUNTIF(engaged_session = TRUE) AS total_engaged_sessions,
    SUM(total_page_views) AS total_page_views,
    SUM(total_events) AS total_events,
    AVG(session_duration_seconds) AS avg_session_duration_seconds,
    AVG(total_page_views) AS avg_pages_per_session,
    SUM(total_conversions) AS total_conversions,
    SUM(purchase_conversions) AS total_purchases,
    SUM(total_revenue) AS total_revenue_usd
  FROM user_sessions
  GROUP BY client_key
),

-- Get purchase metrics
user_purchases AS (
  SELECT
    client_key,
    MIN(purchase_date) AS first_purchase_date,
    MAX(purchase_date) AS last_purchase_date,
    COUNT(DISTINCT transaction_id) AS purchase_count,
    AVG(purchase_revenue_in_usd) AS avg_order_value_usd
  FROM ga4_analytics.stg_ga4__ecommerce_purchases
  GROUP BY client_key
),

-- Get first touch attribution
first_touch AS (
  SELECT
    s.client_key,
    s.session_source AS first_session_source,
    s.session_medium AS first_session_medium,
    s.session_campaign AS first_session_campaign,
    s.session_default_channel_grouping AS first_session_default_channel_grouping
  FROM ga4_analytics.dim_ga4__sessions s
  WHERE s.is_first_session = TRUE
),

-- Get most common device and geo
user_device_geo AS (
  SELECT
    client_key,
    ARRAY_AGG(device_category ORDER BY device_count DESC LIMIT 1)[OFFSET(0)] AS most_common_device_category,
    ARRAY_AGG(platform ORDER BY platform_count DESC LIMIT 1)[OFFSET(0)] AS most_common_platform,
    ARRAY_AGG(geo_country ORDER BY country_count DESC LIMIT 1)[OFFSET(0)] AS most_common_country,
    ARRAY_AGG(geo_region ORDER BY region_count DESC LIMIT 1)[OFFSET(0)] AS most_common_region,
    ARRAY_AGG(geo_city ORDER BY city_count DESC LIMIT 1)[OFFSET(0)] AS most_common_city
  FROM (
    SELECT
      client_key,
      device_category,
      platform,
      geo_country,
      geo_region,
      geo_city,
      COUNT(*) OVER (PARTITION BY client_key, device_category) AS device_count,
      COUNT(*) OVER (PARTITION BY client_key, platform) AS platform_count,
      COUNT(*) OVER (PARTITION BY client_key, geo_country) AS country_count,
      COUNT(*) OVER (PARTITION BY client_key, geo_region) AS region_count,
      COUNT(*) OVER (PARTITION BY client_key, geo_city) AS city_count
    FROM ga4_analytics.dim_ga4__sessions
  )
  GROUP BY client_key
),

-- Get user pseudo ID (most recent)
user_ids AS (
  SELECT
    client_key,
    ARRAY_AGG(user_pseudo_id ORDER BY event_timestamp DESC LIMIT 1)[OFFSET(0)] AS user_pseudo_id
  FROM ga4_analytics.stg_ga4__events
  GROUP BY client_key
),

-- Join all together
user_profile AS (
  SELECT
    usm.client_key,
    ui.user_pseudo_id,
    usm.first_seen_date,
    usm.last_seen_date,
    DATE_DIFF(usm.last_seen_date, usm.first_seen_date, DAY) AS days_since_first_seen,
    usm.total_sessions,
    usm.total_engaged_sessions,
    CASE
      WHEN usm.total_sessions > 0 THEN usm.total_engaged_sessions / usm.total_sessions
      ELSE NULL
    END AS engagement_rate,
    usm.total_page_views,
    usm.total_events,
    usm.avg_session_duration_seconds,
    usm.avg_pages_per_session,
    usm.total_conversions,
    usm.total_purchases,
    usm.total_revenue_usd,
    up.avg_order_value_usd,
    up.first_purchase_date,
    up.last_purchase_date,
    DATE_DIFF(up.first_purchase_date, usm.first_seen_date, DAY) AS days_to_first_purchase,
    ft.first_session_source,
    ft.first_session_medium,
    ft.first_session_campaign,
    ft.first_session_default_channel_grouping,
    udg.most_common_device_category,
    udg.most_common_platform,
    udg.most_common_country,
    udg.most_common_region,
    udg.most_common_city,
    up.purchase_count > 0 AS is_purchaser,
    up.purchase_count >= 2 AS is_repeat_purchaser
  FROM user_session_metrics usm
  LEFT JOIN user_purchases up USING (client_key)
  LEFT JOIN first_touch ft USING (client_key)
  LEFT JOIN user_device_geo udg USING (client_key)
  LEFT JOIN user_ids ui USING (client_key)
),

-- Add user segmentation
with_segments AS (
  SELECT
    *,
    CASE
      WHEN total_purchases >= 3 AND total_revenue_usd >= 500 THEN 'VIP Customer'
      WHEN total_purchases >= 1 THEN 'Purchaser'
      WHEN total_engaged_sessions >= 3 THEN 'Engaged User'
      WHEN total_sessions = 1 THEN 'New User'
      ELSE 'Casual User'
    END AS user_segment
  FROM user_profile
)

SELECT * FROM with_segments;

