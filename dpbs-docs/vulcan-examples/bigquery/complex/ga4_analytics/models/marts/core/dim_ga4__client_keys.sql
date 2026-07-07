-- Client Key Dimension Table
-- Dimension table for unique devices/clients with first and last activity
MODEL (
  name ga4_analytics.dim_ga4__client_keys,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'dimension', 'clients', 'users'),
  grains (client_key),
  profiles (
    device_category,
    platform,
    geo_country
  ),
  description 'Client/device dimension table tracking unique devices with first and last seen activity, page views, and user attributes.',
  column_descriptions (
    client_key = 'Unique client/device identifier',
    user_pseudo_id = 'GA4 pseudonymous user ID',
    stream_id = 'GA4 data stream ID',
    first_seen_timestamp = 'First time this client was seen',
    last_seen_timestamp = 'Last time this client was seen',
    first_page_location = 'First page URL viewed',
    first_page_hostname = 'Hostname of first page',
    first_page_title = 'Title of first page',
    first_page_referrer = 'Referrer of first page',
    last_page_location = 'Most recent page URL viewed',
    last_page_hostname = 'Hostname of last page',
    last_page_title = 'Title of last page',
    total_pageviews = 'Total page views by this client',
    total_sessions = 'Total number of sessions by this client',
    device_category = 'Device category (desktop, mobile, tablet)',
    platform = 'Platform (web, iOS, Android)',
    device_operating_system = 'Operating system',
    device_browser = 'Browser name',
    geo_country = 'Country (from first session)',
    geo_region = 'Region (from first session)',
    geo_city = 'City (from first session)',
    days_active = 'Number of days between first and last seen'
  )
);

-- Get first and last event per client
WITH client_events AS (
  SELECT
    client_key,
    user_pseudo_id,
    stream_id,
    event_timestamp,
    event_date_dt,
    device_category,
    platform,
    device_operating_system,
    device_browser,
    geo_country,
    geo_region,
    geo_city,
    session_key,
    ROW_NUMBER() OVER (PARTITION BY client_key ORDER BY event_timestamp ASC) AS first_rank,
    ROW_NUMBER() OVER (PARTITION BY client_key ORDER BY event_timestamp DESC) AS last_rank
  FROM ga4_analytics.stg_ga4__events
  WHERE client_key IS NOT NULL
),

-- Get first event details
first_event AS (
  SELECT
    client_key,
    user_pseudo_id,
    stream_id,
    event_timestamp AS first_seen_timestamp,
    device_category,
    platform,
    device_operating_system,
    device_browser,
    geo_country,
    geo_region,
    geo_city
  FROM client_events
  WHERE first_rank = 1
),

-- Get last event details
last_event AS (
  SELECT
    client_key,
    event_timestamp AS last_seen_timestamp
  FROM client_events
  WHERE last_rank = 1
),

-- Count total sessions per client
session_counts AS (
  SELECT
    client_key,
    COUNT(DISTINCT session_key) AS total_sessions
  FROM client_events
  GROUP BY client_key
),

-- Join with pageview data
with_pageviews AS (
  SELECT
    f.client_key,
    f.user_pseudo_id,
    f.stream_id,
    f.first_seen_timestamp,
    l.last_seen_timestamp,
    p.first_page_location,
    p.first_page_hostname,
    p.first_page_title,
    p.first_page_referrer,
    p.last_page_location,
    p.last_page_hostname,
    p.last_page_title,
    p.total_pageviews,
    s.total_sessions,
    f.device_category,
    f.platform,
    f.device_operating_system,
    f.device_browser,
    f.geo_country,
    f.geo_region,
    f.geo_city,
    TIMESTAMP_DIFF(
      TIMESTAMP_MICROS(l.last_seen_timestamp),
      TIMESTAMP_MICROS(f.first_seen_timestamp),
      DAY
    ) AS days_active
  FROM first_event f
  JOIN last_event l USING (client_key)
  LEFT JOIN ga4_analytics.stg_ga4__client_key_first_last_pageviews p USING (client_key)
  LEFT JOIN session_counts s USING (client_key)
)

SELECT * FROM with_pageviews;

