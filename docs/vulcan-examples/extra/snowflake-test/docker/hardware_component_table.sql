MODEL (
  name VULCAN.TEST.HARDWARE_COMPONENT_TABLE__last_7_days,
  kind FULL,
  partitioned_by event_date,
  grains (
    ROLLUP_TYPE,
    EVENT_DATE,
    ACTION,
    DEVICE_TYPE,
    COMPONENT_ID,
    PRODUCT_ID,
    REGION
  ),
  tags ('gold', 'hardware-analytics', 'component-metrics', 'geography', 'rollup-aggregations', 'lenovo', 'usdk', 'software-components'),
  terms ('glossary.component_analytics', 'glossary.software_adoption', 'glossary.geographic_analysis'),
  description 'Gold layer hardware analytics aggregated by software component ID with device type, product attributes, and geographic dimensions. Tracks component-level adoption and usage patterns across hardware devices and regions with cumulative engagement metrics.',
  -- blueprints (
  --   (
  --     rollup_type := 'yesterday'
  --   ),
  --   (
  --     rollup_type := 'last_7_days'
  --   ),
  --   (
  --     rollup_type := 'last_30_days'
  --   ),
  --   (
  --     rollup_type := 'last_90_days'
  --   ),
  --   (
  --     rollup_type := 'last_180_days'
  --   ),
  --   (
  --     rollup_type := 'last_365_days'
  --   )
  -- ),
  columns (
    ROLLUP_TYPE VARCHAR,
    EVENT_DATE DATE,
    ACTION VARCHAR,
    DEVICE_TYPE VARCHAR,
    COMPONENT_ID VARCHAR,
    PRODUCT_ID VARCHAR,
    PRODUCT_NAME VARCHAR,
    BRAND VARCHAR,
    SERIES VARCHAR,
    REGION VARCHAR,
    COUNTRY_NAME VARCHAR,
    DAILY_ACTIVITY_COUNT INT,
    CUMULATIVE_ACTIVITY_COUNT INT
  ),
  column_descriptions (
    ROLLUP_TYPE = 'Time window aggregation type: yesterday, last_7_days, last_30_days, last_90_days, last_180_days, or last_365_days',
    EVENT_DATE = 'Date of the event occurrence, used for partitioning and time-based analysis',
    ACTION = 'Type of activity: "Engaged Activity" (interactive actions), "All Activity", "Install Base" (existence), or "PageView"',
    DEVICE_TYPE = 'Type of device (e.g., PC, Laptop, Tablet). Defaults to "Not Found" if unavailable',
    COMPONENT_ID = 'Software component identifier. Defaults to "Not Found" if unavailable',
    PRODUCT_ID = 'Unique product identifier for the software. Defaults to "Not Found" if unavailable',
    PRODUCT_NAME = 'Full marketing product name derived from model brand mapping (e.g., ThinkPad X1 Carbon Gen 9). Shows "Not Found" if model not in mapping',
    BRAND = 'Primary brand name from model brand mapping (e.g., ThinkPad, IdeaPad, Legion, Yoga)',
    SERIES = 'Product series name from model brand mapping (e.g., ThinkPad T Series, IdeaPad Gaming, Legion 5)',
    REGION = 'Business region name with descriptive labels (e.g., "LA (Latin America)", "AP (Asia Pacific)", "EMEA (Europe Middle East Africa)")',
    COUNTRY_NAME = 'Full country name in English derived from geographic mapping (e.g., United States, China, United Kingdom)',
    DAILY_ACTIVITY_COUNT = 'Count of distinct active devices (anonymous_device_idv1) for the event date',
    CUMULATIVE_ACTIVITY_COUNT = 'Running total of unique devices seen from start of time window through current event date (window function over rollup_type, action, device_type, model, geo, component_id, product_id)'
  ),
  column_tags (
    ROLLUP_TYPE = ('time-dimension', 'aggregation-window', 'categorical', 'dimension'),
    EVENT_DATE = ('partition-key', 'time-dimension', 'date', 'temporal'),
    ACTION = ('activity-type', 'engagement-metric', 'categorical', 'dimension'),
    DEVICE_TYPE = ('device-attribute', 'dimension', 'categorical', 'hardware-type'),
    COMPONENT_ID = ('product-attribute', 'software-component', 'dimension'),
    PRODUCT_ID = ('product-attribute', 'identifier', 'dimension'),
    PRODUCT_NAME = ('product-attribute', 'display-name', 'dimension', 'enriched'),
    BRAND = ('brand', 'product-hierarchy', 'dimension', 'enriched'),
    SERIES = ('product-line', 'brand-hierarchy', 'dimension', 'enriched'),
    REGION = ('geography', 'region', 'dimension', 'enriched', 'business-region'),
    COUNTRY_NAME = ('geography', 'location', 'dimension', 'enriched'),
    DAILY_ACTIVITY_COUNT = ('measure', 'metric', 'device-count', 'unique-devices'),
    CUMULATIVE_ACTIVITY_COUNT = ('measure', 'metric', 'cumulative', 'running-total', 'window-function')
  ),
  column_terms (
    ROLLUP_TYPE = ('analytics.time_window', 'aggregation.rollup_period'),
    EVENT_DATE = ('analytics.event_date', 'time.date'),
    ACTION = ('analytics.action_type', 'engagement.activity_type'),
    DEVICE_TYPE = ('device.type', 'hardware.device_type'),
    COMPONENT_ID = ('product.component_id', 'software.component'),
    PRODUCT_ID = ('product.identifier', 'software.product_id'),
    PRODUCT_NAME = ('product.name', 'hardware.product_name'),
    BRAND = ('product.brand', 'marketing.brand_name'),
    SERIES = ('product.series', 'brand.product_line'),
    REGION = ('geography.region', 'location.business_region'),
    COUNTRY_NAME = ('geography.country_name', 'location.country'),
    DAILY_ACTIVITY_COUNT = ('analytics.daily_active_devices', 'metrics.dau'),
    CUMULATIVE_ACTIVITY_COUNT = ('analytics.cumulative_devices', 'metrics.cumulative_total')
  )
);

/* Hardware component analytics with cumulative metrics */
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
    component_id,
    product_id,
    anonymous_device_idv1
  FROM flattened
  where
    rollup_type = 'last_7_days'
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
    component_id,
    product_id,
    anonymous_device_idv1,
    MIN(event_date) AS first_seen_date
  FROM deduped
  GROUP BY
    rollup_type,
    device_type,
    action,
    geo,
    model,
    component_id,
    product_id,
    anonymous_device_idv1
), daily_activity AS (
  SELECT
    event_date,
    rollup_type,
    device_type,
    action,
    geo,
    model,
    component_id,
    product_id,
    COUNT(DISTINCT anonymous_device_idv1) AS daily_activity_count
  FROM deduped
  GROUP BY
    event_date,
    rollup_type,
    action,
    geo,
    device_type,
    model,
    component_id,
    product_id
), daily_new AS (
  SELECT
    fs.first_seen_date AS event_date,
    fs.rollup_type,
    fs.action,
    fs.geo,
    fs.device_type,
    fs.model,
    fs.component_id,
    fs.product_id,
    COUNT(*) AS daily_new_devices
  FROM first_seen AS fs
  GROUP BY
    fs.first_seen_date,
    fs.rollup_type,
    fs.action,
    fs.geo,
    fs.device_type,
    fs.model,
    fs.component_id,
    fs.product_id
), cumulative_activity AS (
  SELECT
    d.event_date,
    d.rollup_type,
    d.action,
    d.geo,
    d.device_type,
    d.model,
    d.component_id,
    d.product_id,
    d.daily_activity_count,
    SUM(COALESCE(n.daily_new_devices, 0)) OVER (
      PARTITION BY d.rollup_type, d.action, d.device_type, d.model, d.geo, d.component_id, d.product_id
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
    AND d.component_id = n.component_id
    AND d.product_id = n.product_id
), with_region AS (
  SELECT
    a.event_date,
    a.rollup_type,
    a.action,
    a.geo,
    a.device_type,
    a.component_id,
    a.product_id,
    CASE WHEN b.product_name IS NULL THEN 'Not Found' ELSE b.product_name END AS product_name,
    g.region,
    g.country_name,
    b.brand,
    b.series,
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
  component_id,
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
  7,
  8,
  9,
  10,
  11