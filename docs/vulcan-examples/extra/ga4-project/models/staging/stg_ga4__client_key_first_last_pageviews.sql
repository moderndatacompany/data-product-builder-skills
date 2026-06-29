-- Client Key First and Last Page Views Model
-- Tracks first and last pages viewed by each client/device
MODEL (
  name ga4_analytics.stg_ga4__client_key_first_last_pageviews,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'client', 'pageviews', 'user_journey'),
  grains (client_key),
  description 'First and last page views for each client/device. Useful for understanding user journey and landing/exit pages.',
  column_descriptions (
    client_key = 'Unique client/device identifier',
    first_page_location = 'First page URL viewed by this client',
    first_page_hostname = 'Hostname of first page',
    first_page_title = 'Title of first page',
    first_page_referrer = 'Referrer of first page',
    first_pageview_timestamp = 'Timestamp of first page view',
    last_page_location = 'Most recent page URL viewed by this client',
    last_page_hostname = 'Hostname of last page',
    last_page_title = 'Title of last page',
    last_pageview_timestamp = 'Timestamp of last page view',
    total_pageviews = 'Total number of page views by this client'
  )
);

-- Get all page view events
WITH page_views AS (
  SELECT
    client_key,
    event_timestamp,
    page_location,
    page_hostname,
    page_title,
    page_referrer,
    ROW_NUMBER() OVER (PARTITION BY client_key ORDER BY event_timestamp ASC) AS first_rank,
    ROW_NUMBER() OVER (PARTITION BY client_key ORDER BY event_timestamp DESC) AS last_rank
  FROM ga4_analytics.stg_ga4__events
  WHERE event_name = 'page_view'
    AND client_key IS NOT NULL
),

-- Get first page view per client
first_pageview AS (
  SELECT
    client_key,
    page_location AS first_page_location,
    page_hostname AS first_page_hostname,
    page_title AS first_page_title,
    page_referrer AS first_page_referrer,
    event_timestamp AS first_pageview_timestamp
  FROM page_views
  WHERE first_rank = 1
),

-- Get last page view per client
last_pageview AS (
  SELECT
    client_key,
    page_location AS last_page_location,
    page_hostname AS last_page_hostname,
    page_title AS last_page_title,
    event_timestamp AS last_pageview_timestamp
  FROM page_views
  WHERE last_rank = 1
),

-- Count total pageviews per client
pageview_counts AS (
  SELECT
    client_key,
    COUNT(*) AS total_pageviews
  FROM page_views
  GROUP BY client_key
)

-- Join all together
SELECT
  f.client_key,
  f.first_page_location,
  f.first_page_hostname,
  f.first_page_title,
  f.first_page_referrer,
  f.first_pageview_timestamp,
  l.last_page_location,
  l.last_page_hostname,
  l.last_page_title,
  l.last_pageview_timestamp,
  c.total_pageviews
FROM first_pageview f
JOIN last_pageview l ON f.client_key = l.client_key
JOIN pageview_counts c ON f.client_key = c.client_key;

