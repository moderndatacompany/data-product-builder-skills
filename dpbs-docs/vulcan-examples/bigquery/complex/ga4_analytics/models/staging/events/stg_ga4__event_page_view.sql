-- Page View Event Model
-- Filters events for page_view and extracts page-related parameters
MODEL (
  name ga4_analytics.stg_ga4__event_page_view,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'events', 'page_view'),
  grains (event_key),
  description 'Page view events with extracted page hierarchy and metadata. Used for page-level analytics and funnel analysis.',
  column_descriptions (
    page_path_1 = 'First level of page path hierarchy (e.g., /products)',
    page_path_2 = 'Second level of page path hierarchy (e.g., /products/shoes)',
    page_path_3 = 'Third level of page path hierarchy (e.g., /products/shoes/nike)',
    page_path_4 = 'Fourth level of page path hierarchy (e.g., /products/shoes/nike/air-max)',
    entrances = 'Indicator if this page view was a session entrance (1 or 0)',
    is_entrance = 'Boolean flag for session entrance'
  )
);

-- Extract page view events
SELECT
  event_key,
  event_date_dt,
  event_timestamp,
  event_name,
  client_key,
  session_key,
  session_partition_key,
  page_key,
  page_engagement_key,
  user_pseudo_id,
  session_id,
  session_number,
  stream_id,
  page_location,
  page_path,
  page_hostname,
  page_query_string,
  page_title,
  page_referrer,
  device_category,
  device_operating_system,
  device_browser,
  geo_country,
  geo_region,
  geo_city,
  event_value_in_usd,
  event_params,
  
  -- Extract page hierarchy from path
  SPLIT(page_path, '/')[SAFE_OFFSET(1)] AS page_path_1,
  SPLIT(page_path, '/')[SAFE_OFFSET(2)] AS page_path_2,
  SPLIT(page_path, '/')[SAFE_OFFSET(3)] AS page_path_3,
  SPLIT(page_path, '/')[SAFE_OFFSET(4)] AS page_path_4,
  
  -- Extract entrances parameter
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'entrances') AS entrances,
  CASE 
    WHEN (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'entrances') = 1 THEN TRUE
    ELSE FALSE 
  END AS is_entrance

FROM ga4_analytics.stg_ga4__events
WHERE event_name = 'page_view';
