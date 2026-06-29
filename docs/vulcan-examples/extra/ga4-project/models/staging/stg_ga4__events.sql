-- Staging GA4 Events Model
-- Enriches base events with computed keys (client_key, session_key, event_key)
-- Adds URL parsing and query parameter handling
MODEL (
  name ga4_analytics.stg_ga4__events,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'staging', 'events', 'enriched'),
  grains (event_key),
  description 'Enriched GA4 events with client keys, session keys, event keys, and URL parsing. Foundation for all downstream analytics.',
  column_descriptions (
    client_key = 'Unique identifier for a client/device (MD5 hash of user_pseudo_id + stream_id)',
    session_key = 'Unique identifier for a session (MD5 hash of client_key + session_id)',
    session_partition_key = 'Partition key combining session_key and event_date for efficient querying',
    event_key = 'Unique identifier for an event (MD5 hash of multiple event attributes)',
    page_path = 'URL path extracted from page_location',
    page_hostname = 'Hostname extracted from page_location',
    page_query_string = 'Query string extracted from page_location',
    page_key = 'Key combining date and page_location for page-level aggregations',
    page_engagement_key = 'Key for tracking page engagement sessions',
    original_page_location = 'Original page URL before query parameter cleaning',
    original_page_referrer = 'Original referrer URL before query parameter cleaning'
  )
);

-- Start with base events
WITH base_events AS (
  SELECT * FROM ga4_analytics.base_ga4__events
),

-- Add client_key that uniquely identifies a device/client
include_client_key AS (
  SELECT
    *,
    TO_BASE64(MD5(CONCAT(CAST(user_pseudo_id AS STRING), CAST(stream_id AS STRING)))) AS client_key
  FROM base_events
),

-- Add session_key that uniquely identifies a session
include_session_key AS (
  SELECT
    *,
    TO_BASE64(MD5(CONCAT(client_key, CAST(session_id AS STRING)))) AS session_key
  FROM include_client_key
),

-- Add session_partition_key combining session_key and date
include_session_partition_key AS (
  SELECT
    *,
    CONCAT(session_key, CAST(event_date_dt AS STRING)) AS session_partition_key
  FROM include_session_key
),

-- Add unique event_key
include_event_key AS (
  SELECT
    *,
    TO_BASE64(MD5(CONCAT(
      COALESCE(client_key, ''),
      CAST(session_id AS STRING),
      event_name,
      CAST(event_timestamp AS STRING),
      TO_JSON_STRING(event_params)
    ))) AS event_key
  FROM include_session_partition_key
),

-- Detect gclid in URLs and adjust source/medium/campaign
detect_gclid AS (
  SELECT
    * EXCEPT (event_source, event_medium, event_campaign),
    CASE
      WHEN page_location LIKE '%gclid%' AND event_source IS NULL THEN 'google'
      ELSE event_source
    END AS event_source,
    CASE
      WHEN page_location LIKE '%gclid%' AND event_medium IS NULL THEN 'cpc'
      WHEN page_location LIKE '%gclid%' AND event_medium = 'organic' THEN 'cpc'
      ELSE event_medium
    END AS event_medium,
    CASE
      WHEN page_location LIKE '%gclid%' AND event_campaign IS NULL THEN '(cpc)'
      WHEN page_location LIKE '%gclid%' AND event_campaign = 'organic' THEN '(cpc)'
      WHEN page_location LIKE '%gclid%' AND event_campaign = '(organic)' THEN '(cpc)'
      ELSE event_campaign
    END AS event_campaign
  FROM include_event_key
),

-- Extract URL components (hostname, path, query string)
enrich_url_params AS (
  SELECT
    *,
    page_location AS original_page_location,
    page_referrer AS original_page_referrer,
    
    -- Extract hostname: Remove protocol and www, take only the domain
    REGEXP_REPLACE(
      REGEXP_REPLACE(
        REGEXP_EXTRACT(page_location, r'^(?:https?://)?(?:www\.)?([^/?#]+)'),
        r'^www\.',
        ''
      ),
      r':\d+$',
      ''
    ) AS page_hostname,
    
    -- Extract path: Get everything between hostname and query string
    REGEXP_EXTRACT(page_location, r'^[^?#]+\.[^/?#]+([^?#]*)') AS page_path,
    
    -- Extract query string: Everything after ? but before #
    REGEXP_EXTRACT(page_location, r'\?([^#]*)') AS page_query_string
    
  FROM detect_gclid
),

-- Add page_key and page_engagement_key
add_page_keys AS (
  SELECT
    *,
    CONCAT(CAST(event_date_dt AS STRING), page_location) AS page_key,
    CASE
      WHEN event_name = 'page_view' THEN
        TO_BASE64(MD5(CONCAT(session_key, COALESCE(page_referrer, ''))))
      ELSE
        TO_BASE64(MD5(CONCAT(session_key, page_location)))
    END AS page_engagement_key
  FROM enrich_url_params
)

SELECT * FROM add_page_keys;
