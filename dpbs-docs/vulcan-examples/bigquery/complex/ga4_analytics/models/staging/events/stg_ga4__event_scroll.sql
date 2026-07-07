-- Scroll Event Model
-- Tracks scroll depth events (typically fired at 90% scroll depth)
MODEL (
  name ga4_analytics.stg_ga4__event_scroll,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'events', 'scroll', 'engagement'),
  grains (event_key),
  description 'Scroll events indicating user scrolled to a significant depth (typically 90%) on a page.',
  column_descriptions (
    percent_scrolled = 'Percentage of page scrolled by the user'
  )
);

-- Extract scroll events
SELECT
  event_key,
  event_date_dt,
  event_timestamp,
  client_key,
  session_key,
  user_pseudo_id,
  session_id,
  page_location,
  page_path,
  page_hostname,
  device_category,
  geo_country,
  geo_region,
  -- Extract percent_scrolled parameter
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'percent_scrolled') AS percent_scrolled
FROM ga4_analytics.stg_ga4__events
WHERE event_name = 'scroll';

