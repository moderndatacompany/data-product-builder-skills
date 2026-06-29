-- User Engagement Event Model
-- Filters events for user_engagement to track active user sessions
MODEL (
  name ga4_analytics.stg_ga4__event_user_engagement,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'events', 'engagement'),
  grains (event_key),
  description 'User engagement events indicating active user interaction. Fired when user is engaged with the site/app.'
);

-- Extract user engagement events
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
  -- Extract engagement_time_msec parameter
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engagement_time_msec') AS engagement_time_msec
FROM ga4_analytics.stg_ga4__events
WHERE event_name = 'user_engagement';

