MODEL (
  name VULCAN.TEST.HARDWARE_HW_IN_USE_TABLE__@{rollup_type},
  kind FULL,
  partitioned_by event_date,
  grains (
    ROLLUP_TYPE,
    EVENT_DATE,
    ACTION,
    DEVICE_TYPE,
    PRODUCT_ID,
    REGION,
    HW_IN_USE_YEARS
  ),
  tags ('gold', 'hardware-lifecycle', 'device-age', 'geography', 'rollup-aggregations', 'lenovo', 'usdk', 'product-analytics'),
  terms ('glossary.hardware_lifecycle', 'glossary.device_age', 'glossary.usage_analytics'),
  description 'Gold layer hardware lifecycle analytics tracking device age (years in use) by device type, product, and geography. Supports hardware refresh cycle analysis, aging fleet identification, and lifecycle management insights with filtered view of devices up to 10 years old.',
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
  columns (
    ROLLUP_TYPE VARCHAR,
    EVENT_DATE DATE,
    ACTION VARCHAR,
    DEVICE_TYPE VARCHAR,
    PRODUCT_ID VARCHAR,
    PRODUCT_NAME VARCHAR,
    BRAND VARCHAR,
    SERIES VARCHAR,
    REGION VARCHAR,
    COUNTRY_NAME VARCHAR,
    HW_IN_USE_YEARS INT,
    DAILY_ACTIVITY_COUNT INT,
    CUMULATIVE_ACTIVITY_COUNT INT
  ),
  column_descriptions (
    ROLLUP_TYPE = 'Time window aggregation type: yesterday, last_7_days, last_30_days, last_90_days, last_180_days, or last_365_days',
    EVENT_DATE = 'Date of the event occurrence, used for partitioning and time-based analysis',
    ACTION = 'Type of activity: "Engaged Activity" (interactive actions), "All Activity", "Install Base" (existence), or "PageView"',
    DEVICE_TYPE = 'Type of device (e.g., PC, Laptop, Tablet). Defaults to "Not Found" if unavailable',
    PRODUCT_ID = 'Unique product identifier for the software. Defaults to "Not Found" if unavailable',
    PRODUCT_NAME = 'Full marketing product name derived from model brand mapping (e.g., ThinkPad X1 Carbon Gen 9). Shows "Not Found" if model not in mapping',
    BRAND = 'Primary brand name from model brand mapping (e.g., ThinkPad, IdeaPad, Legion, Yoga)',
    SERIES = 'Product series name from model brand mapping (e.g., ThinkPad T Series, IdeaPad Gaming, Legion 5)',
    REGION = 'Business region name with descriptive labels (e.g., "LA (Latin America)", "AP (Asia Pacific)", "EMEA (Europe Middle East Africa)")',
    COUNTRY_NAME = 'Full country name in English derived from geographic mapping (e.g., United States, China, United Kingdom)',
    HW_IN_USE_YEARS = 'Calculated hardware age in years (current year minus first run year). Filtered to show only devices with age <= 10 years',
    DAILY_ACTIVITY_COUNT = 'Count of distinct active devices (anonymous_device_idv1) for the event date',
    CUMULATIVE_ACTIVITY_COUNT = 'Running total of unique devices seen from start of time window through current event date (window function over rollup_type, action, device_type, model, product_id, geo, hw_in_use_years)'
  ),
  column_tags (
    ROLLUP_TYPE = ('time-dimension', 'aggregation-window', 'categorical', 'dimension'),
    EVENT_DATE = ('partition-key', 'time-dimension', 'date', 'temporal'),
    ACTION = ('activity-type', 'engagement-metric', 'categorical', 'dimension'),
    DEVICE_TYPE = ('device-attribute', 'dimension', 'categorical', 'hardware-type'),
    PRODUCT_ID = ('product-attribute', 'identifier', 'dimension'),
    PRODUCT_NAME = ('product-attribute', 'display-name', 'dimension', 'enriched'),
    BRAND = ('brand', 'product-hierarchy', 'dimension', 'enriched'),
    SERIES = ('product-line', 'brand-hierarchy', 'dimension', 'enriched'),
    REGION = ('geography', 'region', 'dimension', 'enriched', 'business-region'),
    COUNTRY_NAME = ('geography', 'location', 'dimension', 'enriched'),
    HW_IN_USE_YEARS = ('hardware-metrics', 'calculated', 'measure', 'derived', 'lifecycle'),
    DAILY_ACTIVITY_COUNT = ('measure', 'metric', 'device-count', 'unique-devices'),
    CUMULATIVE_ACTIVITY_COUNT = ('measure', 'metric', 'cumulative', 'running-total', 'window-function')
  ),
  column_terms (
    ROLLUP_TYPE = ('analytics.time_window', 'aggregation.rollup_period'),
    EVENT_DATE = ('analytics.event_date', 'time.date'),
    ACTION = ('analytics.action_type', 'engagement.activity_type'),
    DEVICE_TYPE = ('device.type', 'hardware.device_type'),
    PRODUCT_ID = ('product.identifier', 'software.product_id'),
    PRODUCT_NAME = ('product.name', 'hardware.product_name'),
    BRAND = ('product.brand', 'marketing.brand_name'),
    SERIES = ('product.series', 'brand.product_line'),
    REGION = ('geography.region', 'location.business_region'),
    COUNTRY_NAME = ('geography.country_name', 'location.country'),
    HW_IN_USE_YEARS = ('hardware.age_years', 'device.lifecycle_years'),
    DAILY_ACTIVITY_COUNT = ('analytics.daily_active_devices', 'metrics.dau'),
    CUMULATIVE_ACTIVITY_COUNT = ('analytics.cumulative_devices', 'metrics.cumulative_total')
  )
);

/* Hardware in-use years analytics with cumulative metrics */
WITH flattened AS (
  SELECT
    *
  FROM VULCAN.TEST.FLATTENED_MAIN_BASE_TABLE
), geo_mapping AS (
  SELECT
    *
  FROM VULCAN.TEST.GEO_MAPPING
), model_brand_mapping AS (
  SELECT
    *
  FROM VULCAN.TEST.MODEL_BRAND_MAPPING
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