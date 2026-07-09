MODEL (
  name LENOVO.USDK.software_os__@{rollup_type},
  kind FULL,
  owner 'shreyasikarwartmdcio',
  profiles (ROLLUP_TYPE, EVENT_DATE, ACTION, OS_FAMILY, PRODUCT_ID),
  tags ('gold', 'software-analytics', 'os-analytics', 'distribution-analytics', 'engagement-metrics', 'version-tracking', 'lenovo', 'usdk'),
  terms ('software_engagement', 'os_distribution', 'version_adoption', 'os_analytics'),
  description 'Gold layer OS distribution analytics aggregated by OS family and product. Provides high-level view of Windows version adoption across products. Essential for OS compatibility planning, upgrade strategies, and understanding user base distribution across Windows releases.',
  grains (
    ROLLUP_TYPE, EVENT_DATE, ACTION, OS_FAMILY, PRODUCT_ID
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
    PRODUCT_ID = 'Unique software product identifier',
    PAGEVIEW_COUNT = 'Total number of page views or screen interactions aggregated across all devices',
    DAILY_ACTIVITY_COUNT = 'Count of unique devices active on this specific date (may contain duplicates across dates)'
  ),
  column_tags (
    ROLLUP_TYPE = ('time-dimension', 'aggregation-window', 'dimension', 'grain'),
    EVENT_DATE = ('partition-key', 'time-dimension', 'date', 'temporal', 'grain'),
    ACTION = ('activity-type', 'engagement-metric', 'dimension', 'grain'),
    OS_FAMILY = ('os-attribute', 'display-name', 'dimension', 'grain'),
    PRODUCT_ID = ('product-attribute', 'identifier', 'dimension', 'grain'),
    PAGEVIEW_COUNT = ('metric', 'measure', 'engagement', 'aggregated', 'count'),
    DAILY_ACTIVITY_COUNT = ('metric', 'measure', 'engagement', 'device-count', 'daily')
  ),
  column_terms (
    ROLLUP_TYPE = ('time_window', 'rollup_period', 'aggregation_type'),
    EVENT_DATE = ('event_date', 'date', 'occurrence_date'),
    ACTION = ('action_type', 'activity_type', 'engagement_type'),
    OS_FAMILY = ('os_family', 'os_release', 'windows_version'),
    PRODUCT_ID = ('product_id', 'identifier', 'product_identifier'),
    PAGEVIEW_COUNT = ('pageview_count', 'view_count', 'interaction_count'),
    DAILY_ACTIVITY_COUNT = ('daily_count', 'active_devices', 'daily_engagement')
  ),
  partitioned_by event_date
);

/* Software OS version analytics - similar pattern to software_geo_os_table */
WITH flattened AS (
  SELECT
    *
  FROM LENOVO.USDK.FLATTENED_MAIN_BASE_TABLE 
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
    product_id,
    anonymous_device_idv1
), aggregated AS (
  SELECT
    event_date,
    rollup_type,
    action,
    os_version,
    product_id,
    SUM(pageview_count) AS pageview_count,
    COUNT(DISTINCT anonymous_device_idv1) AS daily_activity_count
  FROM deduped
  GROUP BY
    event_date,
    rollup_type,
    action,
    os_version,
    product_id
)
SELECT
  a.rollup_type,
  a.event_date,
  a.action,
  CASE WHEN o.os_family IS NULL THEN 'Other/Unknown' ELSE o.os_family END AS os_family,
  a.product_id,
  SUM(a.pageview_count) AS pageview_count,
  SUM(a.daily_activity_count) AS daily_activity_count
FROM aggregated AS a
LEFT JOIN os_family AS o
  ON o.os_version = a.os_version
GROUP BY
  1,
  2,
  3,
  4,
  5