MODEL (
  name LENOVO.USDK.hardware_hw_in_use__@{rollup_type},
  kind FULL,
  owner 'shreyasikarwartmdcio',
  profiles (ROLLUP_TYPE, EVENT_DATE, ACTION, DEVICE_TYPE, HW_IN_USE_YEARS, REGION),
  tags ('gold', 'hardware-analytics', 'lifecycle-analytics', 'age-analytics', 'geographic-analytics', 'engagement-metrics', 'lenovo', 'usdk'),
  terms ('hardware_lifecycle', 'device_age', 'hardware_longevity', 'geographic_distribution', 'cumulative_metrics'),
  description 'Gold layer hardware lifecycle analytics aggregated by hardware age in years (filtered to ≤10 years). Tracks device engagement patterns based on hardware age across regions for lifecycle analysis, replacement planning, and age-based performance insights. Essential for understanding hardware longevity and refresh cycles.',
  grains (
    ROLLUP_TYPE, EVENT_DATE, ACTION, DEVICE_TYPE, PRODUCT_ID, PRODUCT_NAME, BRAND, SERIES, REGION, COUNTRY_NAME, HW_IN_USE_YEARS
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
    DEVICE_TYPE = 'Type of hardware device (e.g., PC, Laptop, Tablet). Defaults to "Not Found" if unavailable',
    PRODUCT_ID = 'Unique software product identifier associated with the hardware activity',
    PRODUCT_NAME = 'Marketing product name from model-brand mapping. Defaults to "Not Found" if no mapping exists',
    BRAND = 'Primary Lenovo brand (e.g., ThinkPad, IdeaPad, Legion, Yoga) from MTM mapping',
    SERIES = 'Product series name (e.g., ThinkPad T Series, IdeaPad Gaming) for hierarchical analysis',
    REGION = 'Business region with expanded names: "LA (Latin America)", "AP (Asia Pacific)", "EMEA (Europe Middle East Africa)"',
    COUNTRY_NAME = 'Full country name in English for detailed geographic analysis',
    HW_IN_USE_YEARS = 'Calculated hardware age in years (current year minus first run year). Filtered to devices with ≤10 years of use',
    DAILY_ACTIVITY_COUNT = 'Count of unique devices active on this specific date (may contain duplicates across dates)',
    CUMULATIVE_ACTIVITY_COUNT = 'Cumulative count of unique devices that have appeared since the start of the rollup period (deduplicated)'
  ),
  column_tags (
    ROLLUP_TYPE = ('time-dimension', 'aggregation-window', 'dimension', 'grain'),
    EVENT_DATE = ('partition-key', 'time-dimension', 'date', 'temporal', 'grain'),
    ACTION = ('activity-type', 'engagement-metric', 'dimension', 'grain'),
    DEVICE_TYPE = ('device-attribute', 'dimension', 'categorical', 'grain'),
    PRODUCT_ID = ('product-attribute', 'identifier', 'dimension', 'grain'),
    PRODUCT_NAME = ('product-attribute', 'display-name', 'dimension', 'grain'),
    BRAND = ('brand-attribute', 'hierarchy', 'dimension', 'grain'),
    SERIES = ('product-line', 'hierarchy', 'dimension', 'grain'),
    REGION = ('geography', 'business-region', 'dimension', 'grain'),
    COUNTRY_NAME = ('geography', 'country', 'dimension', 'grain'),
    HW_IN_USE_YEARS = ('lifecycle-metric', 'age', 'dimension', 'derived', 'grain'),
    DAILY_ACTIVITY_COUNT = ('metric', 'measure', 'engagement', 'device-count', 'daily'),
    CUMULATIVE_ACTIVITY_COUNT = ('metric', 'measure', 'engagement', 'cumulative', 'deduplicated')
  ),
  column_terms (
    ROLLUP_TYPE = ('time_window', 'rollup_period', 'aggregation_type'),
    EVENT_DATE = ('event_date', 'date', 'occurrence_date'),
    ACTION = ('action_type', 'activity_type', 'engagement_type'),
    DEVICE_TYPE = ('device_type', 'hardware_type', 'device_category'),
    PRODUCT_ID = ('product_id', 'identifier', 'product_identifier'),
    PRODUCT_NAME = ('product_name', 'name', 'marketing_name'),
    BRAND = ('brand', 'brand_name', 'top_level_brand'),
    SERIES = ('series', 'product_line', 'product_series'),
    REGION = ('region', 'business_region', 'geographic_region'),
    COUNTRY_NAME = ('country', 'country_name', 'geographic_country'),
    HW_IN_USE_YEARS = ('hardware_age', 'device_age', 'years_in_use', 'lifecycle_years'),
    DAILY_ACTIVITY_COUNT = ('daily_count', 'active_devices', 'daily_engagement'),
    CUMULATIVE_ACTIVITY_COUNT = ('cumulative_count', 'total_unique_devices', 'cumulative_engagement')
  ),
  partitioned_by event_date
);

/* Hardware in-use years analytics with cumulative metrics */
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
    device_type,
    action,
    geo,
    model,
    product_id,
    hw_in_use_years,
    anonymous_device_idv1
  FROM flattened
  @WHERE(TRUE)
    rollup_type = @rollup_type
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
), first_seen AS (
  SELECT
    rollup_type,
    device_type,
    action,
    geo,
    model,
    product_id,
    hw_in_use_years,
    anonymous_device_idv1,
    MIN(event_date) AS first_seen_date
  FROM deduped
  GROUP BY
    rollup_type,
    device_type,
    action,
    geo,
    model,
    product_id,
    anonymous_device_idv1,
    hw_in_use_years
), daily_activity AS (
  SELECT
    event_date,
    rollup_type,
    device_type,
    action,
    geo,
    model,
    product_id,
    hw_in_use_years,
    COUNT(DISTINCT anonymous_device_idv1) AS daily_activity_count
  FROM deduped
  GROUP BY
    event_date,
    rollup_type,
    action,
    geo,
    device_type,
    model,
    product_id,
    hw_in_use_years
), daily_new AS (
  SELECT
    fs.first_seen_date AS event_date,
    fs.rollup_type,
    fs.action,
    fs.geo,
    fs.device_type,
    fs.model,
    fs.product_id,
    fs.hw_in_use_years,
    COUNT(*) AS daily_new_devices
  FROM first_seen AS fs
  GROUP BY
    fs.first_seen_date,
    fs.rollup_type,
    fs.action,
    fs.geo,
    fs.device_type,
    fs.model,
    fs.product_id,
    fs.hw_in_use_years
), cumulative_activity AS (
  SELECT
    d.event_date,
    d.rollup_type,
    d.action,
    d.geo,
    d.device_type,
    d.model,
    d.product_id,
    d.hw_in_use_years,
    d.daily_activity_count,
    SUM(COALESCE(n.daily_new_devices, 0)) OVER (
      PARTITION BY d.rollup_type, d.action, d.device_type, d.model, d.product_id, d.geo, d.hw_in_use_years
      ORDER BY d.event_date
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_activity_count
  FROM daily_activity AS d
  LEFT JOIN daily_new AS n
    ON d.event_date = n.event_date
    AND d.rollup_type = n.rollup_type
    AND d.action = n.action
    AND d.geo = n.geo
    AND d.device_type = n.device_type
    AND d.model = n.model
    AND d.product_id = n.product_id
    AND d.hw_in_use_years = n.hw_in_use_years
), with_region AS (
  SELECT
    a.event_date,
    a.rollup_type,
    a.action,
    a.geo,
    a.device_type,
    a.product_id,
    CASE WHEN b.product_name IS NULL THEN 'Not Found' ELSE b.product_name END AS product_name,
    g.region,
    g.country_name,
    b.brand,
    b.series,
    a.hw_in_use_years,
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
  device_type,
  product_id,
  product_name,
  brand,
  series,
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
  hw_in_use_years,
  SUM(daily_activity_count) AS daily_activity_count,
  SUM(cumulative_activity_count) AS cumulative_activity_count
FROM with_region
WHERE
  hw_in_use_years <= 10
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11