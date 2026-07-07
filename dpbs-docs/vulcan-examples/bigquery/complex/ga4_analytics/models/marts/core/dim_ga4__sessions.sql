-- Session Dimension Table
-- Core dimensional model for GA4 sessions with rich attribution and context
MODEL (
  name ga4_analytics.dim_ga4__sessions,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'dimension', 'sessions', 'analytics'),
  grains (session_key),
  profiles (
    session_default_channel_grouping,
    device_category,
    geo_country,
    platform
  ),
  description 'Session dimension table containing comprehensive session attributes including landing page, device info, geography, and traffic source attribution.',
  column_descriptions (
    session_key = 'Unique session identifier',
    client_key = 'Client/device identifier for this session',
    session_start_date = 'Date when session started',
    session_start_timestamp = 'Timestamp when session started',
    landing_page = 'First page URL in the session (landing page)',
    landing_page_path = 'Path of the landing page',
    landing_page_hostname = 'Hostname of the landing page',
    landing_page_referrer = 'Referrer URL that brought user to landing page',
    geo_continent = 'Continent where session originated',
    geo_country = 'Country where session originated',
    geo_region = 'State/region where session originated',
    geo_city = 'City where session originated',
    geo_sub_continent = 'Sub-continent geographic classification',
    geo_metro = 'Metro area code',
    stream_id = 'GA4 data stream ID',
    platform = 'Platform (web, iOS, Android)',
    device_category = 'Device category (desktop, mobile, tablet)',
    device_mobile_brand_name = 'Mobile device brand',
    device_mobile_model_name = 'Mobile device model',
    device_operating_system = 'Operating system',
    device_operating_system_version = 'OS version',
    device_browser = 'Browser name',
    device_language = 'Browser/device language',
    session_number = 'Session sequence number for this user',
    is_first_session = 'Boolean indicating if this is the user first session',
    user_campaign = 'First-touch campaign name',
    user_medium = 'First-touch medium',
    user_source = 'First-touch source',
    session_source = 'Session-level traffic source',
    session_medium = 'Session-level traffic medium',
    session_campaign = 'Session-level campaign',
    session_content = 'Session-level campaign content',
    session_term = 'Session-level search term',
    session_default_channel_grouping = 'Channel grouping (Organic Search, Paid Search, Direct, etc.)',
    session_source_category = 'Source category (Organic, Paid, Direct, etc.)'
  )
);

-- Get first meaningful event per session (excluding session_start and first_visit)
WITH session_first_event AS (
  SELECT
    session_key,
    client_key,
    event_date_dt,
    event_timestamp,
    page_path,
    page_location,
    page_hostname,
    page_referrer,
    geo_continent,
    geo_country,
    geo_region,
    geo_city,
    geo_sub_continent,
    geo_metro,
    stream_id,
    platform,
    device_category,
    device_mobile_brand_name,
    device_mobile_model_name,
    device_mobile_marketing_name,
    device_mobile_os_hardware_model,
    device_operating_system,
    device_operating_system_version,
    device_vendor_id,
    device_advertising_id,
    device_language,
    device_is_limited_ad_tracking,
    device_time_zone_offset_seconds,
    device_browser,
    device_web_info_browser,
    device_web_info_browser_version,
    -- device_web_info_hostname,  -- Field not available in this GA4 schema
    session_number,
    user_campaign,
    user_medium,
    user_source,
    ROW_NUMBER() OVER (
      PARTITION BY session_key
      ORDER BY event_timestamp ASC
    ) AS event_rank
  FROM ga4_analytics.stg_ga4__events
  WHERE event_name NOT IN ('first_visit', 'session_start')
    AND session_key IS NOT NULL
),

-- Get only the first event per session
session_start_dims AS (
  SELECT
    session_key,
    client_key,
    event_date_dt AS session_start_date,
    event_timestamp AS session_start_timestamp,
    page_path AS landing_page_path,
    page_location AS landing_page,
    page_hostname AS landing_page_hostname,
    page_referrer AS landing_page_referrer,
    geo_continent,
    geo_country,
    geo_region,
    geo_city,
    geo_sub_continent,
    geo_metro,
    stream_id,
    platform,
    device_category,
    device_mobile_brand_name,
    device_mobile_model_name,
    device_mobile_marketing_name,
    device_mobile_os_hardware_model,
    device_operating_system,
    device_operating_system_version,
    device_vendor_id,
    device_advertising_id,
    device_language,
    device_is_limited_ad_tracking,
    device_time_zone_offset_seconds,
    device_browser,
    device_web_info_browser,
    device_web_info_browser_version,
    -- device_web_info_hostname,  -- Field not available in this GA4 schema
    session_number,
    session_number = 1 AS is_first_session,
    user_campaign,
    user_medium,
    user_source
  FROM session_first_event
  WHERE event_rank = 1
),

-- Join with traffic source attribution
join_traffic_source AS (
  SELECT
    session_start_dims.*,
    sessions_traffic_sources.session_source,
    sessions_traffic_sources.session_medium,
    sessions_traffic_sources.session_campaign,
    sessions_traffic_sources.session_content,
    sessions_traffic_sources.session_term,
    sessions_traffic_sources.session_default_channel_grouping,
    sessions_traffic_sources.session_source_category
  FROM session_start_dims
  LEFT JOIN ga4_analytics.stg_ga4__sessions_traffic_sources AS sessions_traffic_sources
    USING (session_key)
)

SELECT * FROM join_traffic_source;

