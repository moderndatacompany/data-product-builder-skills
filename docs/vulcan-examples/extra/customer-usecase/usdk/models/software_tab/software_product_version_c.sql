MODEL (
  name LENOVO.USDK.software_product_version__@{rollup_type},
  kind FULL,
  owner 'shreyasikarwartmdcio',
  profiles (ROLLUP_TYPE, EVENT_DATE, ACTION, PRODUCT_ID, PRODUCT_VERSION, COMPONENT_ID),
  tags ('gold', 'software-analytics', 'product-analytics', 'component-analytics', 'version-tracking', 'engagement-metrics', 'lenovo', 'usdk'),
  terms ('software_engagement', 'product_usage', 'component_usage', 'version_adoption'),
  description 'Gold layer comprehensive software analytics aggregated by product version and component. Tracks detailed product-component relationships and version-specific usage patterns. Essential for component adoption analysis, version migration tracking, and granular software usage insights.',
  grains (
    ROLLUP_TYPE, EVENT_DATE, ACTION, PRODUCT_ID, PRODUCT_VERSION, COMPONENT_ID, COMPONENT_VERSION
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
    PRODUCT_ID = 'Unique software product identifier',
    PRODUCT_VERSION = 'Software product version number for version-specific tracking',
    COMPONENT_ID = 'Software component identifier tracking specific software modules or features',
    COMPONENT_VERSION = 'Version of the software component for granular version tracking',
    PAGEVIEW_COUNT = 'Total number of page views or screen interactions aggregated across all devices',
    DAILY_ACTIVITY_COUNT = 'Count of unique devices active on this specific date (may contain duplicates across dates)'
  ),
  column_tags (
    ROLLUP_TYPE = ('time-dimension', 'aggregation-window', 'dimension', 'grain'),
    EVENT_DATE = ('partition-key', 'time-dimension', 'date', 'temporal', 'grain'),
    ACTION = ('activity-type', 'engagement-metric', 'dimension', 'grain'),
    PRODUCT_ID = ('product-attribute', 'identifier', 'dimension', 'grain'),
    PRODUCT_VERSION = ('product-attribute', 'version', 'dimension', 'grain'),
    COMPONENT_ID = ('component-attribute', 'identifier', 'dimension', 'grain'),
    COMPONENT_VERSION = ('component-attribute', 'version', 'dimension', 'grain'),
    PAGEVIEW_COUNT = ('metric', 'measure', 'engagement', 'aggregated', 'count'),
    DAILY_ACTIVITY_COUNT = ('metric', 'measure', 'engagement', 'device-count', 'daily')
  ),
  column_terms (
    ROLLUP_TYPE = ('time_window', 'rollup_period', 'aggregation_type'),
    EVENT_DATE = ('event_date', 'date', 'occurrence_date'),
    ACTION = ('action_type', 'activity_type', 'engagement_type'),
    PRODUCT_ID = ('product_id', 'identifier', 'product_identifier'),
    PRODUCT_VERSION = ('product_version', 'version', 'software_version'),
    COMPONENT_ID = ('component_id', 'component_identifier', 'module_id'),
    COMPONENT_VERSION = ('component_version', 'version', 'module_version'),
    PAGEVIEW_COUNT = ('pageview_count', 'view_count', 'interaction_count'),
    DAILY_ACTIVITY_COUNT = ('daily_count', 'active_devices', 'daily_engagement')
  ),
  partitioned_by event_date
);

/* Software product, version, and component analytics */
WITH flattened AS (
  SELECT
    *
  FROM LENOVO.USDK.FLATTENED_MAIN_BASE_TABLE 
), deduped AS (
  SELECT
    rollup_type,
    event_date,
    action,
    product_id,
    product_version,
    component_id,
    component_version,
    anonymous_device_idv1,
    COUNT(name) AS pageview_count
  FROM flattened
  @WHERE(TRUE)
    rollup_type = @rollup_type
  GROUP BY
    rollup_type,
    event_date,
    action,
    product_id,
    product_version,
    component_id,
    component_version,
    anonymous_device_idv1
), aggregated AS (
  SELECT
    event_date,
    rollup_type,
    action,
    product_id,
    product_version,
    component_id,
    component_version,
    SUM(pageview_count) AS pageview_count,
    COUNT(DISTINCT anonymous_device_idv1) AS daily_activity_count
  FROM deduped
  GROUP BY
    event_date,
    rollup_type,
    action,
    product_id,
    product_version,
    component_id,
    component_version
)
SELECT
  rollup_type,
  event_date,
  action,
  product_id,
  product_version,
  component_id,
  component_version,
  SUM(pageview_count) AS pageview_count,
  SUM(daily_activity_count) AS daily_activity_count
FROM aggregated
GROUP BY
  rollup_type,
  event_date,
  action,
  product_id,
  product_version,
  component_id,
  component_version