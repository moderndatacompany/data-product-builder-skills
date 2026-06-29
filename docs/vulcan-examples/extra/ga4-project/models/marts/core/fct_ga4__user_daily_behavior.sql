-- User Daily Behavior Fact Table
-- Daily aggregation of user activity for trend analysis
MODEL (
  name ga4_analytics.fct_ga4__user_daily_behavior,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'fact', 'users', 'daily', 'behavior', 'analytics'),
  grains (client_key, activity_date),
  profiles (
    activity_date,
    device_category
  ),
  description 'Daily user behavior metrics including sessions, engagement, events, and conversions. Used for user activity trends and cohort analysis.',
  column_descriptions (
    client_key = 'User identifier',
    activity_date = 'Date of activity',
    days_since_first_visit = 'Days since user first visit',
    total_sessions = 'Sessions on this date',
    total_engaged_sessions = 'Engaged sessions on this date',
    total_page_views = 'Page views on this date',
    total_events = 'Events triggered on this date',
    total_engagement_time_seconds = 'Total engagement time',
    avg_session_duration_seconds = 'Average session length',
    unique_pages_viewed = 'Unique pages viewed',
    total_conversions = 'Conversion events',
    purchase_conversions = 'Purchase events',
    add_to_cart_events = 'Add to cart events',
    begin_checkout_events = 'Checkout initiation events',
    revenue_usd = 'Revenue generated this date',
    primary_device_category = 'Most used device this date',
    primary_platform = 'Most used platform this date',
    primary_country = 'Country (most common this date)',
    session_sources = 'Traffic sources used (array)',
    session_channels = 'Marketing channels used (array)',
    is_purchase_date = 'Boolean - did user purchase this day',
    is_first_visit_date = 'Boolean - is this the first visit day'
  )
);

-- Get daily user activity from sessions
WITH user_daily_sessions AS (
  SELECT
    s.client_key,
    s.session_start_date AS activity_date,
    s.device_category,
    s.platform,
    s.geo_country,
    s.session_source,
    s.session_medium,
    s.session_default_channel_grouping,
    fs.total_page_views,
    fs.total_events,
    fs.engaged_session,
    fs.session_duration_seconds,
    fs.total_engagement_time_seconds,
    fs.unique_pages_viewed,
    fs.total_conversions,
    fs.purchase_conversions,
    fs.total_revenue
  FROM ga4_analytics.dim_ga4__sessions s
  LEFT JOIN ga4_analytics.fct_ga4__sessions fs USING (session_key)
),

-- Aggregate by user and date
daily_aggregates AS (
  SELECT
    client_key,
    activity_date,
    
    -- Session metrics
    COUNT(*) AS total_sessions,
    COUNTIF(engaged_session = TRUE) AS total_engaged_sessions,
    SUM(total_page_views) AS total_page_views,
    SUM(total_events) AS total_events,
    SUM(total_engagement_time_seconds) AS total_engagement_time_seconds,
    AVG(session_duration_seconds) AS avg_session_duration_seconds,
    SUM(unique_pages_viewed) AS unique_pages_viewed,
    
    -- Conversion metrics
    SUM(total_conversions) AS total_conversions,
    SUM(purchase_conversions) AS purchase_conversions,
    SUM(total_revenue) AS revenue_usd,
    
    -- Primary device/platform/geo (most frequent)
    ARRAY_AGG(device_category ORDER BY device_category LIMIT 1)[OFFSET(0)] AS primary_device_category,
    ARRAY_AGG(platform ORDER BY platform LIMIT 1)[OFFSET(0)] AS primary_platform,
    ARRAY_AGG(geo_country ORDER BY geo_country LIMIT 1)[OFFSET(0)] AS primary_country,
    
    -- Collect traffic sources
    ARRAY_AGG(DISTINCT session_source IGNORE NULLS) AS session_sources,
    ARRAY_AGG(DISTINCT session_default_channel_grouping IGNORE NULLS) AS session_channels
    
  FROM user_daily_sessions
  GROUP BY client_key, activity_date
),

-- Get event-level metrics for add_to_cart and begin_checkout
daily_events AS (
  SELECT
    client_key,
    event_date_dt AS activity_date,
    COUNTIF(event_name = 'add_to_cart') AS add_to_cart_events,
    COUNTIF(event_name = 'begin_checkout') AS begin_checkout_events
  FROM ga4_analytics.stg_ga4__events
  WHERE event_name IN ('add_to_cart', 'begin_checkout')
  GROUP BY client_key, activity_date
),

-- Get user first visit date
user_first_visit AS (
  SELECT
    client_key,
    first_seen_date
  FROM ga4_analytics.dim_ga4__users
),

-- Combine everything
final AS (
  SELECT
    da.client_key,
    da.activity_date,
    DATE_DIFF(da.activity_date, ufv.first_seen_date, DAY) AS days_since_first_visit,
    da.total_sessions,
    da.total_engaged_sessions,
    da.total_page_views,
    da.total_events,
    da.total_engagement_time_seconds,
    da.avg_session_duration_seconds,
    da.unique_pages_viewed,
    da.total_conversions,
    da.purchase_conversions,
    COALESCE(de.add_to_cart_events, 0) AS add_to_cart_events,
    COALESCE(de.begin_checkout_events, 0) AS begin_checkout_events,
    da.revenue_usd,
    da.primary_device_category,
    da.primary_platform,
    da.primary_country,
    da.session_sources,
    da.session_channels,
    da.purchase_conversions > 0 AS is_purchase_date,
    da.activity_date = ufv.first_seen_date AS is_first_visit_date
  FROM daily_aggregates da
  LEFT JOIN daily_events de USING (client_key, activity_date)
  LEFT JOIN user_first_visit ufv USING (client_key)
)

SELECT * FROM final;

