MODEL (
  name LENOVO.USDK.software_geo_os__@{rollup_type},
  kind FULL,
  owner 'shreyasikarwartmdcio',
  profiles (ROLLUP_TYPE, EVENT_DATE, ACTION, OS_FAMILY, COMPONENT_ID, REGION),
  tags ('gold', 'software-analytics', 'os-analytics', 'component-analytics', 'geographic-analytics', 'engagement-metrics', 'lenovo', 'usdk'),
  terms ('software_engagement', 'os_distribution', 'component_usage', 'geographic_distribution'),
  description 'Gold layer software analytics aggregated by OS family, component, and geography. Tracks software component usage patterns across different Windows versions and regions. Essential for OS adoption analysis, component compatibility assessment, and regional software deployment insights.',
  grains (
    ROLLUP_TYPE, EVENT_DATE, ACTION, OS_FAMILY, COMPONENT_ID, COMPONENT_VERSION, PRODUCT_ID, REGION, COUNTRY_NAME
  ),
  blueprints (
    (
      rollup_type := 'yesterday'
    ),
    (
      rollup_type := 'last_7_days'
    ),
    (
      rollup_type := 'last_30_days'
    ),
    (
      rollup_type := 'last_90_days'
    ),
    (
      rollup_type := 'last_180_days'
    ),
    (
      rollup_type := 'last_365_days'
    )
  ),
  column_descriptions (
    ROLLUP_TYPE = 'Time aggregation window: yesterday, last_7_days, last_30_days, last_90_days, last_180_days, or last_365_days',
    EVENT_DATE = 'Date of the engagement event occurrence, used for time-series analysis and partitioning',
    ACTION = 'User activity type: "Engaged Activity" (interactive), "All Activity", "Install Base", or "PageView"',
    OS_FAMILY = 'Human-readable Windows release name (e.g., "Windows 10 2004", "Windows 11 22H2"). Defaults to "Other/Unknown" if version not mapped',
    COMPONENT_ID = 'Software component identifier tracking specific software modules or features',
    COMPONENT_VERSION = 'Version of the software component',
    PRODUCT_ID = 'Unique software product identifier associated with the component',
    REGION = 'Business region with expanded names: "LA (Latin America)", "AP (Asia Pacific)", "EMEA (Europe Middle East Africa)"',
    COUNTRY_NAME = 'Full country name in English for detailed geographic analysis',
    PAGEVIEW_COUNT = 'Total number of page views or screen interactions aggregated across all devices',
    DAILY_ACTIVITY_COUNT = 'Count of unique devices active on this specific date (may contain duplicates across dates)'
  ),
  column_tags (
    ROLLUP_TYPE = ('time-dimension', 'aggregation-window', 'dimension', 'grain'),
    EVENT_DATE = ('partition-key', 'time-dimension', 'date', 'temporal', 'grain'),
    ACTION = ('activity-type', 'engagement-metric', 'dimension', 'grain'),
    OS_FAMILY = ('os-attribute', 'display-name', 'dimension', 'grain'),
    COMPONENT_ID = ('component-attribute', 'identifier', 'dimension', 'grain'),
    COMPONENT_VERSION = ('component-attribute', 'version', 'dimension', 'grain'),
    PRODUCT_ID = ('product-attribute', 'identifier', 'dimension', 'grain'),
    REGION = ('geography', 'business-region', 'dimension', 'grain'),
    COUNTRY_NAME = ('geography', 'country', 'dimension', 'grain'),
    PAGEVIEW_COUNT = ('metric', 'measure', 'engagement', 'aggregated', 'count'),
    DAILY_ACTIVITY_COUNT = ('metric', 'measure', 'engagement', 'device-count', 'daily')
  ),
  column_terms (
    ROLLUP_TYPE = ('time_window', 'rollup_period', 'aggregation_type'),
    EVENT_DATE = ('event_date', 'date', 'occurrence_date'),
    ACTION = ('action_type', 'activity_type', 'engagement_type'),
    OS_FAMILY = ('os_family', 'os_release', 'windows_version'),
    COMPONENT_ID = ('component_id', 'component_identifier', 'module_id'),
    COMPONENT_VERSION = ('component_version', 'version', 'software_version'),
    PRODUCT_ID = ('product_id', 'identifier', 'product_identifier'),
    REGION = ('region', 'business_region', 'geographic_region'),
    COUNTRY_NAME = ('country', 'country_name', 'geographic_country'),
    PAGEVIEW_COUNT = ('pageview_count', 'view_count', 'interaction_count'),
    DAILY_ACTIVITY_COUNT = ('daily_count', 'active_devices', 'daily_engagement')
  ),
  partitioned_by event_date
);

/* Software geography, OS, and component analytics */
WITH flattened AS (
  SELECT
    *
  FROM LENOVO.USDK.FLATTENED_MAIN_BASE_TABLE 
), geo_mapping AS (
  SELECT
    *
  FROM LENOVO.USDK.geo_mapping
), os_family AS (
  SELECT
    *
  FROM LENOVO.USDK.os_family
), deduped AS (
  SELECT
    rollup_type,
    event_date,
    os_version,
    action,
    geo,
    component_id,
    component_version,
    product_id,
    anonymous_device_idv1,
    COUNT(name) AS pageview_count
  FROM flattened
  @WHERE(TRUE)
    rollup_type = @rollup_type
  GROUP BY
    rollup_type,
    event_date,
    os_version,
    action,
    geo,
    component_id,
    component_version,
    product_id,
    anonymous_device_idv1
), aggregated AS (
  SELECT
    event_date,
    rollup_type,
    action,
    geo,
    os_version,
    component_id,
    component_version,
    product_id,
    SUM(pageview_count) AS pageview_count,
    COUNT(DISTINCT anonymous_device_idv1) AS daily_activity_count
  FROM deduped
  GROUP BY
    event_date,
    rollup_type,
    action,
    geo,
    os_version,
    component_id,
    component_version,
    product_id
)
SELECT
  a.rollup_type,
  a.event_date,
  a.action,
  CASE WHEN o.os_family IS NULL THEN 'Other/Unknown' ELSE o.os_family END AS os_family,
  a.component_id,
  a.component_version,
  a.product_id,
  CASE
    WHEN g.region = 'LA'
    THEN 'LA (Latin America)'
    WHEN g.region = 'AP'
    THEN 'AP (Asia Pacific)'
    WHEN g.region = 'EMEA'
    THEN 'EMEA (Europe Middle East Africa)'
    ELSE g.region
  END AS region,
  g.country_name,
  SUM(a.pageview_count) AS pageview_count,
  SUM(a.daily_activity_count) AS daily_activity_count
FROM aggregated AS a
LEFT JOIN geo_mapping AS g
  ON g.country_code = a.geo
LEFT JOIN os_family AS o
  ON o.os_version = a.os_version
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9