MODEL (
  name LENOVO.USDK.software_geo_product__@{rollup_type},
  kind FULL,
  owner 'shreyasikarwartmdcio',
  profiles (ROLLUP_TYPE, EVENT_DATE, ACTION, PRODUCT_ID, PRODUCT_VERSION, REGION),
  tags ('gold', 'software-analytics', 'product-analytics', 'geographic-analytics', 'engagement-metrics', 'version-tracking', 'lenovo', 'usdk'),
  terms ('software_engagement', 'product_usage', 'geographic_distribution', 'version_adoption'),
  description 'Gold layer software analytics aggregated by product version and geography. Tracks product version adoption and engagement across different regions. Essential for version rollout analysis, regional deployment strategies, and market-specific product performance insights.',
  grains (
    ROLLUP_TYPE, EVENT_DATE, ACTION, PRODUCT_ID, PRODUCT_VERSION, REGION, COUNTRY_NAME
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
    REGION = 'Business region with expanded names: "LA (Latin America)", "AP (Asia Pacific)", "EMEA (Europe Middle East Africa)"',
    COUNTRY_NAME = 'Full country name in English for detailed geographic analysis',
    PAGEVIEW_COUNT = 'Total number of page views or screen interactions aggregated across all devices',
    DAILY_ACTIVITY_COUNT = 'Count of unique devices active on this specific date (may contain duplicates across dates)'
  ),
  column_tags (
    ROLLUP_TYPE = ('time-dimension', 'aggregation-window', 'dimension', 'grain'),
    EVENT_DATE = ('partition-key', 'time-dimension', 'date', 'temporal', 'grain'),
    ACTION = ('activity-type', 'engagement-metric', 'dimension', 'grain'),
    PRODUCT_ID = ('product-attribute', 'identifier', 'dimension', 'grain'),
    PRODUCT_VERSION = ('product-attribute', 'version', 'dimension', 'grain'),
    REGION = ('geography', 'business-region', 'dimension', 'grain'),
    COUNTRY_NAME = ('geography', 'country', 'dimension', 'grain'),
    PAGEVIEW_COUNT = ('metric', 'measure', 'engagement', 'aggregated', 'count'),
    DAILY_ACTIVITY_COUNT = ('metric', 'measure', 'engagement', 'device-count', 'daily')
  ),
  column_terms (
    ROLLUP_TYPE = ('time_window', 'rollup_period', 'aggregation_type'),
    EVENT_DATE = ('event_date', 'date', 'occurrence_date'),
    ACTION = ('action_type', 'activity_type', 'engagement_type'),
    PRODUCT_ID = ('product_id', 'identifier', 'product_identifier'),
    PRODUCT_VERSION = ('product_version', 'version', 'software_version'),
    REGION = ('region', 'business_region', 'geographic_region'),
    COUNTRY_NAME = ('country', 'country_name', 'geographic_country'),
    PAGEVIEW_COUNT = ('pageview_count', 'view_count', 'interaction_count'),
    DAILY_ACTIVITY_COUNT = ('daily_count', 'active_devices', 'daily_engagement')
  ),
  partitioned_by event_date
);

/* Software geography and product analytics */
WITH flattened AS (
  SELECT
    *
  FROM LENOVO.USDK.FLATTENED_MAIN_BASE_TABLE 
), geo_mapping AS (
  SELECT
    *
  FROM LENOVO.USDK.geo_mapping
), deduped AS (
  SELECT
    rollup_type,
    event_date,
    action,
    geo,
    product_id,
    product_version,
    anonymous_device_idv1,
    COUNT(name) AS pageview_count
  FROM flattened
  @WHERE(TRUE)
    rollup_type = @rollup_type
  GROUP BY
    rollup_type,
    event_date,
    action,
    geo,
    product_id,
    product_version,
    anonymous_device_idv1
), aggregated AS (
  SELECT
    event_date,
    rollup_type,
    action,
    geo,
    product_id,
    product_version,
    SUM(pageview_count) AS pageview_count,
    COUNT(DISTINCT anonymous_device_idv1) AS daily_activity_count
  FROM deduped
  GROUP BY
    event_date,
    rollup_type,
    action,
    geo,
    product_id,
    product_version
)
SELECT
  a.rollup_type,
  a.event_date,
  a.action,
  a.product_id,
  a.product_version,
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
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7