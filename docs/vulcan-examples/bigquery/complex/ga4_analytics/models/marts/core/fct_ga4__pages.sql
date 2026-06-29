-- Page Fact Table
-- Aggregates page-level metrics including views, unique users, engagement
MODEL (
  name ga4_analytics.fct_ga4__pages,
  kind FULL,
  cron '@daily',
  -- signals [(sufficient_ga4_events, {min_events: 50})],
  tags ('ga4', 'fact', 'pages', 'metrics'),
  grains (page_key),
  profiles (
    page_hostname,
    page_path
  ),
  description 'Page-level fact table aggregating key metrics including page views, unique users, sessions, entrances, and engagement.',
  column_descriptions (
    page_key = 'Unique page identifier (date + page_location)',
    event_date_dt = 'Date of the page views',
    stream_id = 'GA4 data stream ID',
    page_location = 'Full page URL',
    page_path = 'URL path',
    page_hostname = 'Hostname',
    page_title = 'Page title (most common for this page)',
    total_page_views = 'Total number of page views',
    unique_page_views = 'Number of unique page views (distinct sessions)',
    unique_users = 'Number of unique users (distinct client_keys)',
    entrances = 'Number of times this page was a landing page',
    total_time_on_page_seconds = 'Total time spent on this page across all sessions',
    avg_time_on_page_seconds = 'Average time spent on this page',
    bounce_rate = 'Percentage of sessions that bounced from this page',
    exit_rate = 'Percentage of page views that were exits'
  )
);

-- Get all page view events
WITH page_views AS (
  SELECT
    page_key,
    event_date_dt,
    stream_id,
    page_location,
    page_path,
    page_hostname,
    page_title,
    session_key,
    client_key,
    event_timestamp,
    entrances
  FROM ga4_analytics.stg_ga4__event_page_view
),

-- Calculate time on page (time between consecutive page views in a session)
page_times AS (
  SELECT
    page_key,
    session_key,
    event_timestamp,
    LEAD(event_timestamp) OVER (
      PARTITION BY session_key
      ORDER BY event_timestamp
    ) AS next_event_timestamp
  FROM page_views
),

page_durations AS (
  SELECT
    page_key,
    session_key,
    CASE
      WHEN next_event_timestamp IS NOT NULL THEN
        (next_event_timestamp - event_timestamp) / 1000000.0  -- Convert microseconds to seconds
      ELSE 0
    END AS time_on_page_seconds
  FROM page_times
),

-- Aggregate page metrics
page_metrics AS (
  SELECT
    pv.page_key,
    pv.event_date_dt,
    pv.stream_id,
    pv.page_location,
    pv.page_path,
    pv.page_hostname,
    
    -- Most common page title
    APPROX_TOP_COUNT(pv.page_title, 1)[SAFE_OFFSET(0)].value AS page_title,
    
    -- Counts
    COUNT(*) AS total_page_views,
    COUNT(DISTINCT pv.session_key) AS unique_page_views,
    COUNT(DISTINCT pv.client_key) AS unique_users,
    SUM(COALESCE(pv.entrances, 0)) AS entrances,
    
    -- Time metrics
    SUM(COALESCE(pd.time_on_page_seconds, 0)) AS total_time_on_page_seconds,
    AVG(COALESCE(pd.time_on_page_seconds, 0)) AS avg_time_on_page_seconds
    
  FROM page_views pv
  LEFT JOIN page_durations pd
    ON pv.page_key = pd.page_key
    AND pv.session_key = pd.session_key
  GROUP BY
    pv.page_key,
    pv.event_date_dt,
    pv.stream_id,
    pv.page_location,
    pv.page_path,
    pv.page_hostname
),

-- Calculate bounce and exit rates
-- (Simplified - a full implementation would need session-level data)
with_rates AS (
  SELECT
    *,
    CASE
      WHEN unique_page_views > 0 THEN
        SAFE_DIVIDE(entrances, unique_page_views) * 100
      ELSE 0
    END AS bounce_rate,
    
    CASE
      WHEN total_page_views > 0 THEN
        SAFE_DIVIDE(unique_page_views, total_page_views) * 100
      ELSE 0
    END AS exit_rate
    
  FROM page_metrics
)

SELECT * FROM with_rates;

