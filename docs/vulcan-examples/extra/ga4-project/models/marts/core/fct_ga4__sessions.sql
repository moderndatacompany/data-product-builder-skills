-- Session Fact Table
-- Aggregates session-level metrics including page views, events, engagement, conversions
MODEL (
  name ga4_analytics.fct_ga4__sessions,
  kind FULL,
  cron '@daily',
  -- signals [(sufficient_ga4_events, {min_events: 100})],
  tags ('ga4', 'fact', 'sessions', 'metrics', 'analytics'),
  grains (session_key),
  profiles (
    session_default_channel_grouping,
    device_category,
    geo_country
  ),
  description 'Session-level fact table with comprehensive metrics including page views, events, engagement time, conversions, and revenue.',
  column_descriptions (
    session_key = 'Unique session identifier',
    client_key = 'Client/device identifier',
    session_start_timestamp = 'When the session started',
    session_end_timestamp = 'When the session ended',
    session_duration_seconds = 'Total session duration in seconds',
    session_start_date = 'Date when session started',
    total_page_views = 'Number of page views in the session',
    total_events = 'Total number of events in the session',
    unique_pages_viewed = 'Number of unique pages viewed',
    engaged_session = 'Whether the session was engaged (>10 seconds or 2+ page views or conversion)',
    total_engagement_time_seconds = 'Total engagement time in seconds',
    total_conversions = 'Total conversion events in the session',
    purchase_conversions = 'Number of purchase events',
    sign_up_conversions = 'Number of sign-up events',
    contact_conversions = 'Number of contact/lead events',
    total_revenue = 'Total revenue from this session (from purchase events)',
    session_source = 'Traffic source',
    session_medium = 'Traffic medium',
    session_campaign = 'Campaign name',
    session_default_channel_grouping = 'Channel grouping',
    device_category = 'Device category',
    platform = 'Platform',
    geo_country = 'Country',
    geo_region = 'Region',
    geo_city = 'City',
    is_first_session = 'Boolean - is this the user first session',
    landing_page = 'Landing page URL',
    landing_page_path = 'Landing page path'
  )
);

-- Get all events per session with basic metrics
WITH session_events AS (
  SELECT
    session_key,
    client_key,
    event_timestamp,
    event_name,
    event_date_dt,
    page_location,
    event_value_in_usd
  FROM ga4_analytics.stg_ga4__events
  WHERE session_key IS NOT NULL
),

-- Aggregate basic session metrics
session_basic_metrics AS (
  SELECT
    session_key,
    client_key,
    MIN(event_date_dt) AS session_start_date,
    MIN(event_timestamp) AS session_start_timestamp,
    MAX(event_timestamp) AS session_end_timestamp,
    (MAX(event_timestamp) - MIN(event_timestamp)) / 1000000.0 AS session_duration_seconds,
    
    -- Event counts
    COUNTIF(event_name = 'page_view') AS total_page_views,
    COUNT(*) AS total_events,
    COUNT(DISTINCT page_location) AS unique_pages_viewed,
    
    -- Revenue (cast STRING to FLOAT64 for numeric operations)
    SUM(CASE WHEN event_name = 'purchase' THEN COALESCE(CAST(event_value_in_usd AS FLOAT64), 0) ELSE 0 END) AS total_revenue
    
  FROM session_events
  GROUP BY session_key, client_key
),

-- Calculate engagement metrics
engagement_metrics AS (
  SELECT
    session_key,
    SUM(
      (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engagement_time_msec')
    ) / 1000.0 AS total_engagement_time_seconds
  FROM ga4_analytics.stg_ga4__events
  WHERE session_key IS NOT NULL
  GROUP BY session_key
),

-- Join with session dimensions
with_dimensions AS (
  SELECT
    m.session_key,
    m.client_key,
    m.session_start_timestamp,
    m.session_end_timestamp,
    m.session_duration_seconds,
    m.session_start_date,
    m.total_page_views,
    m.total_events,
    m.unique_pages_viewed,
    
    -- Engagement logic: >10 seconds OR 2+ page views
    CASE
      WHEN COALESCE(e.total_engagement_time_seconds, 0) > 10
        OR m.total_page_views >= 2
        THEN TRUE
      ELSE FALSE
    END AS engaged_session,
    
    COALESCE(e.total_engagement_time_seconds, 0) AS total_engagement_time_seconds,
    m.total_revenue,
    
    -- Session dimensions
    d.session_source,
    d.session_medium,
    d.session_campaign,
    d.session_default_channel_grouping,
    d.device_category,
    d.platform,
    d.geo_country,
    d.geo_region,
    d.geo_city,
    d.is_first_session,
    d.landing_page,
    d.landing_page_path
    
  FROM session_basic_metrics m
  LEFT JOIN engagement_metrics e USING (session_key)
  LEFT JOIN ga4_analytics.dim_ga4__sessions d USING (session_key)
),

-- Join with conversion metrics (if they exist)
with_conversions AS (
  SELECT
    wd.*,
    COALESCE(c.total_conversions, 0) AS total_conversions,
    COALESCE(c.purchase_conversions, 0) AS purchase_conversions,
    COALESCE(c.sign_up_conversions, 0) AS sign_up_conversions,
    COALESCE(c.contact_conversions, 0) AS contact_conversions
  FROM with_dimensions wd
  LEFT JOIN (
    SELECT
      session_key,
      SUM(total_conversions) AS total_conversions,
      SUM(purchase_conversions) AS purchase_conversions,
      SUM(sign_up_conversions) AS sign_up_conversions,
      SUM(contact_conversions) AS contact_conversions
    FROM ga4_analytics.stg_ga4__session_conversions_daily
    GROUP BY session_key
  ) c USING (session_key)
)

SELECT * FROM with_conversions;

