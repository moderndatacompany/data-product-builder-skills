-- Base GA4 Events Model
-- This is the foundation model that references the external BigQuery GA4 events table
-- Flattens basic event structure and extracts common fields
MODEL (
  name ga4_analytics.base_ga4__events,
  kind FULL,
  cron '@daily',
  -- signals [(ga4_data_available, {})],
  tags ('ga4', 'staging', 'events', 'base'),
  description 'Base incremental model for GA4 events from BigQuery export. Flattens core event structure and extracts common event parameters.',
  column_descriptions (
    event_date = 'Date of the event in YYYYMMDD format',
    event_timestamp = 'Timestamp of the event in microseconds (epoch)',
    event_name = 'Name of the event (e.g., page_view, session_start, purchase)',
    event_params = 'Array of event parameters containing event-specific data',
    event_previous_timestamp = 'Timestamp of the previous event for this user',
    event_value_in_usd = 'The currency-converted value of the event',
    event_bundle_sequence_id = 'Sequential ID of the bundle in which the event was uploaded',
    event_server_timestamp_offset = 'Timestamp offset between client and server',
    user_id = 'User ID set via the setUserId API',
    user_pseudo_id = 'Pseudonymous ID for the user (e.g., from Google Analytics cookie)',
    user_properties = 'Array of user properties',
    user_first_touch_timestamp = 'Time at which the user first opened the app/website',
    user_ltv = 'Lifetime value of the user',
    device = 'Device information including category, browser, OS',
    geo = 'Geographic information including country, region, city',
    app_info = 'Application information',
    traffic_source = 'Traffic source information including source, medium, campaign',
    stream_id = 'Stream ID from GA4 property',
    platform = 'Platform (web, iOS, Android)',
    event_date_dt = 'Event date as DATE type',
    page_location = 'Page URL where the event occurred',
    page_referrer = 'Page referrer URL',
    page_title = 'Page title',
    session_id = 'Session ID from GA4',
    session_number = 'Session sequence number for this user',
    engaged_session_event = 'Whether this event was part of an engaged session',
    session_engaged = 'Whether the session was engaged',
    page_views = 'Number of page views in this event',
    event_source = 'Campaign source from event parameters',
    event_medium = 'Campaign medium from event parameters',
    event_campaign = 'Campaign name from event parameters',
    event_content = 'Campaign content from event parameters',
    event_term = 'Campaign search term from event parameters',
    user_source = 'First touch traffic source',
    user_medium = 'First touch traffic medium',
    user_campaign = 'First touch campaign name'
  )
);

-- Extract and flatten core GA4 event data
WITH events_raw AS (
  SELECT
    event_date,
    event_timestamp,
    event_name,
    event_params,
    event_previous_timestamp,
    event_value_in_usd,
    event_bundle_sequence_id,
    event_server_timestamp_offset,
    user_id,
    user_pseudo_id,
    user_properties,
    user_first_touch_timestamp,
    user_ltv,
    device,
    geo,
    app_info,
    traffic_source,
    stream_id,
    platform,
    privacy_info
  FROM `tmdc-platform-engineering`.`vulcan_ga4_demo`.`events_table`
  WHERE TRUE
),
-- Extract common event parameters
events_with_params AS (
  SELECT
    *,
    -- Convert event_date to proper DATE type
    PARSE_DATE('%Y%m%d', CAST(event_date AS STRING)) AS event_date_dt,
    
    -- Extract page_location from event_params
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location') AS page_location,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_referrer') AS page_referrer,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_title') AS page_title,
    
    -- Extract session identifiers
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    
    -- Extract engagement metrics
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engaged_session_event') AS engaged_session_event,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_engaged') AS session_engaged,
    
    -- Extract page views
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'page_views') AS page_views,
    
    -- Extract traffic source parameters from event_params
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source') AS event_source,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium') AS event_medium,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'campaign') AS event_campaign,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'content') AS event_content,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'term') AS event_term
    
  FROM events_raw
),
-- Extract nested device fields
events_flattened AS (
  SELECT
    *,
    -- Device fields
    device.category AS device_category,
    device.mobile_brand_name AS device_mobile_brand_name,
    device.mobile_model_name AS device_mobile_model_name,
    device.mobile_marketing_name AS device_mobile_marketing_name,
    device.mobile_os_hardware_model AS device_mobile_os_hardware_model,
    device.operating_system AS device_operating_system,
    device.operating_system_version AS device_operating_system_version,
    device.vendor_id AS device_vendor_id,
    device.advertising_id AS device_advertising_id,
    device.language AS device_language,
    device.is_limited_ad_tracking AS device_is_limited_ad_tracking,
    device.time_zone_offset_seconds AS device_time_zone_offset_seconds,
    device.web_info.browser AS device_browser,
    device.web_info.browser AS device_web_info_browser,
    device.web_info.browser_version AS device_web_info_browser_version,
    -- device.web_info.hostname AS device_web_info_hostname,  -- Field not available in this GA4 schema
    
    -- Geo fields
    geo.continent AS geo_continent,
    geo.sub_continent AS geo_sub_continent,
    geo.country AS geo_country,
    geo.region AS geo_region,
    geo.metro AS geo_metro,
    geo.city AS geo_city,
    
    -- Traffic source fields (first touch)
    traffic_source.source AS user_source,
    traffic_source.medium AS user_medium,
    traffic_source.name AS user_campaign
    
  FROM events_with_params
)

SELECT * FROM events_flattened;
