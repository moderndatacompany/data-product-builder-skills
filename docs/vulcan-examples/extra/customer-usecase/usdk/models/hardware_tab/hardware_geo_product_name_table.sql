MODEL (
  name LENOVO.USDK.hardware_geo_product_name__@{rollup_type},
  kind FULL,
  owner 'shreyasikarwartmdcio',
  profiles (ROLLUP_TYPE, EVENT_DATE, ACTION, PRODUCT_NAME, REGION, COUNTRY_NAME),
  tags ('gold', 'hardware-analytics', 'geographic-analytics', 'product-dimension', 'engagement-metrics', 'lenovo', 'usdk', 'regional'),
  terms ('hardware_engagement', 'geographic_distribution', 'product_analytics', 'cumulative_metrics'),
  description 'Gold layer hardware analytics aggregated by geography and product name. Provides regional engagement insights for product performance tracking across different markets with cumulative metrics. Essential for geographic market analysis and regional product adoption patterns.',
  grains (
    ROLLUP_TYPE, EVENT_DATE, ACTION, PRODUCT_NAME, PRODUCT_ID, REGION, COUNTRY_NAME
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
    PRODUCT_NAME = 'Marketing product name from model-brand mapping. Defaults to "Not Found" if no mapping exists',
    PRODUCT_ID = 'Unique software product identifier associated with the hardware activity',
    REGION = 'Business region with expanded names: "LA (Latin America)", "AP (Asia Pacific)", "EMEA (Europe Middle East Africa)"',
    COUNTRY_NAME = 'Full country name in English for detailed geographic analysis',
    PAGEVIEW_COUNT = 'Total number of page views or screen interactions aggregated across all devices',
    DAILY_ACTIVITY_COUNT = 'Count of unique devices active on this specific date (may contain duplicates across dates)',
    CUMULATIVE_ACTIVITY_COUNT = 'Cumulative count of unique devices that have appeared since the start of the rollup period (deduplicated)'
  ),
  column_tags (
    ROLLUP_TYPE = ('time-dimension', 'aggregation-window', 'dimension', 'grain'),
    EVENT_DATE = ('partition-key', 'time-dimension', 'date', 'temporal', 'grain'),
    ACTION = ('activity-type', 'engagement-metric', 'dimension', 'grain'),
    PRODUCT_NAME = ('product-attribute', 'display-name', 'dimension', 'grain'),
    PRODUCT_ID = ('product-attribute', 'identifier', 'dimension', 'grain'),
    REGION = ('geography', 'business-region', 'dimension', 'grain'),
    COUNTRY_NAME = ('geography', 'country', 'dimension', 'grain'),
    PAGEVIEW_COUNT = ('metric', 'measure', 'engagement', 'aggregated', 'count'),
    DAILY_ACTIVITY_COUNT = ('metric', 'measure', 'engagement', 'device-count', 'daily'),
    CUMULATIVE_ACTIVITY_COUNT = ('metric', 'measure', 'engagement', 'cumulative', 'deduplicated')
  ),
  column_terms (
    ROLLUP_TYPE = ('time_window', 'rollup_period', 'aggregation_type'),
    EVENT_DATE = ('event_date', 'date', 'occurrence_date'),
    ACTION = ('action_type', 'activity_type', 'engagement_type'),
    PRODUCT_NAME = ('product_name', 'name', 'marketing_name'),
    PRODUCT_ID = ('product_id', 'identifier', 'product_identifier'),
    REGION = ('region', 'business_region', 'geographic_region'),
    COUNTRY_NAME = ('country', 'country_name', 'geographic_country'),
    PAGEVIEW_COUNT = ('pageview_count', 'view_count', 'interaction_count'),
    DAILY_ACTIVITY_COUNT = ('daily_count', 'active_devices', 'daily_engagement'),
    CUMULATIVE_ACTIVITY_COUNT = ('cumulative_count', 'total_unique_devices', 'cumulative_engagement')
  ),
  partitioned_by event_date
);

/* Hardware geo and product name analytics with cumulative metrics */
WITH flattened AS (
  SELECT
    *
  FROM LENOVO.USDK.FLATTENED_MAIN_BASE_TABLE 
), geo_mapping AS (
  SELECT
    *
  FROM LENOVO.USDK.geo_mapping
), model_brand_mapping AS (
  SELECT
    *
  FROM LENOVO.USDK.model_brand_mapping
), deduped AS (
  SELECT
    rollup_type,
    event_date,
    action,
    model,
    product_id,
    geo,
    anonymous_device_idv1,
    COUNT(name) AS pageview_count
  FROM flattened
  @WHERE(TRUE)
    rollup_type = @rollup_type
  GROUP BY
    rollup_type,
    event_date,
    action,
    model,
    product_id,
    geo,
    anonymous_device_idv1
), first_seen AS (
  SELECT
    rollup_type,
    action,
    model,
    product_id,
    geo,
    anonymous_device_idv1,
    MIN(event_date) AS first_seen_date
  FROM deduped
  GROUP BY
    rollup_type,
    action,
    model,
    product_id,
    geo,
    anonymous_device_idv1
), daily_activity AS (
  SELECT
    event_date,
    rollup_type,
    action,
    model,
    product_id,
    geo,
    SUM(pageview_count) AS pageview_count,
    COUNT(DISTINCT anonymous_device_idv1) AS daily_activity_count
  FROM deduped
  GROUP BY
    event_date,
    rollup_type,
    action,
    model,
    product_id,
    geo
), daily_new AS (
  SELECT
    fs.first_seen_date AS event_date,
    fs.rollup_type,
    fs.action,
    fs.model,
    fs.product_id,
    fs.geo,
    COUNT(*) AS daily_new_devices
  FROM first_seen AS fs
  GROUP BY
    fs.first_seen_date,
    fs.rollup_type,
    fs.action,
    fs.model,
    fs.product_id,
    fs.geo
), cumulative_activity AS (
  SELECT
    d.event_date,
    d.rollup_type,
    d.action,
    d.model,
    d.product_id,
    d.geo,
    d.pageview_count,
    d.daily_activity_count,
    SUM(COALESCE(n.daily_new_devices, 0)) OVER (
      PARTITION BY d.rollup_type, d.action, d.model, d.product_id, d.geo
      ORDER BY d.event_date
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_activity_count
  FROM daily_activity AS d
  LEFT JOIN daily_new AS n
    ON d.event_date = n.event_date
    AND d.rollup_type = n.rollup_type
    AND d.action = n.action
    AND d.model = n.model
    AND d.product_id = n.product_id
    AND d.geo = n.geo
), with_region AS (
  SELECT
    a.event_date,
    a.rollup_type,
    a.action,
    a.geo,
    CASE WHEN b.product_name IS NULL THEN 'Not Found' ELSE b.product_name END AS product_name,
    a.product_id,
    g.region,
    g.country_name,
    a.pageview_count,
    a.daily_activity_count,
    a.cumulative_activity_count
  FROM cumulative_activity AS a
  LEFT JOIN geo_mapping AS g
    ON g.country_code = a.geo
  LEFT JOIN model_brand_mapping AS b
    ON LOWER(b.mtm) = LOWER(a.model)
)
SELECT
  rollup_type,
  event_date,
  action,
  product_name,
  product_id,
  CASE
    WHEN region = 'LA'
    THEN 'LA (Latin America)'
    WHEN region = 'AP'
    THEN 'AP (Asia Pacific)'
    WHEN region = 'EMEA'
    THEN 'EMEA (Europe Middle East Africa)'
    ELSE region
  END AS region,
  country_name,
  SUM(pageview_count) AS pageview_count,
  SUM(daily_activity_count) AS daily_activity_count,
  SUM(cumulative_activity_count) AS cumulative_activity_count
FROM with_region
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7