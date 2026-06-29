MODEL (
  name VULCAN.TEST.HARDWARE_GEO_PRODUCT_NAME_TABLE__@{rollup_type},
  kind FULL,
  partitioned_by event_date,
  grains (
    ROLLUP_TYPE,
    EVENT_DATE,
    ACTION,
    PRODUCT_NAME,
    PRODUCT_ID,
    REGION
  ),
  tags ('gold', 'hardware-analytics', 'geographic-distribution', 'product-metrics', 'rollup-aggregations', 'lenovo', 'usdk'),
  terms ('glossary.geographic_analysis', 'glossary.product_analytics', 'glossary.regional_metrics'),
  description 'Gold layer hardware analytics combining product names with geographic distribution. Aggregates pageviews, daily activity, and cumulative device counts by product and region, enabling regional product adoption analysis and market penetration insights.',
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
    PRODUCT_NAME VARCHAR,
    PRODUCT_ID VARCHAR,
    REGION VARCHAR,
    COUNTRY_NAME VARCHAR,
    PAGEVIEW_COUNT INT,
    DAILY_ACTIVITY_COUNT INT,
    CUMULATIVE_ACTIVITY_COUNT INT
  ),
  column_descriptions (
    ROLLUP_TYPE = 'Time window aggregation type: yesterday, last_7_days, last_30_days, last_90_days, last_180_days, or last_365_days',
    EVENT_DATE = 'Date of the event occurrence, used for partitioning and time-based analysis',
    ACTION = 'Type of activity: "Engaged Activity" (interactive actions), "All Activity", "Install Base" (existence), or "PageView"',
    PRODUCT_NAME = 'Full marketing product name derived from model brand mapping (e.g., ThinkPad X1 Carbon Gen 9). Shows "Not Found" if model not in mapping',
    PRODUCT_ID = 'Unique product identifier for the software. Defaults to "Not Found" if unavailable',
    REGION = 'Business region name with descriptive labels (e.g., "LA (Latin America)", "AP (Asia Pacific)", "EMEA (Europe Middle East Africa)")',
    COUNTRY_NAME = 'Full country name in English derived from geographic mapping (e.g., United States, China, United Kingdom)',
    PAGEVIEW_COUNT = 'Total count of page view events aggregated by product, geography, action, and time window',
    DAILY_ACTIVITY_COUNT = 'Count of distinct active devices (anonymous_device_idv1) for the event date',
    CUMULATIVE_ACTIVITY_COUNT = 'Running total of unique devices seen from start of time window through current event date (window function over rollup_type, action, model, product_id, geo)'
  ),
  column_tags (
    ROLLUP_TYPE = ('time-dimension', 'aggregation-window', 'categorical', 'dimension'),
    EVENT_DATE = ('partition-key', 'time-dimension', 'date', 'temporal'),
    ACTION = ('activity-type', 'engagement-metric', 'categorical', 'dimension'),
    PRODUCT_NAME = ('product-attribute', 'display-name', 'dimension', 'enriched'),
    PRODUCT_ID = ('product-attribute', 'identifier', 'dimension'),
    REGION = ('geography', 'region', 'dimension', 'enriched', 'business-region'),
    COUNTRY_NAME = ('geography', 'location', 'dimension', 'enriched'),
    PAGEVIEW_COUNT = ('measure', 'metric', 'aggregated', 'event-count'),
    DAILY_ACTIVITY_COUNT = ('measure', 'metric', 'device-count', 'unique-devices'),
    CUMULATIVE_ACTIVITY_COUNT = ('measure', 'metric', 'cumulative', 'running-total', 'window-function')
  ),
  column_terms (
    ROLLUP_TYPE = ('analytics.time_window', 'aggregation.rollup_period'),
    EVENT_DATE = ('analytics.event_date', 'time.date'),
    ACTION = ('analytics.action_type', 'engagement.activity_type'),
    PRODUCT_NAME = ('product.name', 'hardware.product_name'),
    PRODUCT_ID = ('product.identifier', 'software.product_id'),
    REGION = ('geography.region', 'location.business_region'),
    COUNTRY_NAME = ('geography.country_name', 'location.country'),
    PAGEVIEW_COUNT = ('analytics.pageview_count', 'metrics.event_count'),
    DAILY_ACTIVITY_COUNT = ('analytics.daily_active_devices', 'metrics.dau'),
    CUMULATIVE_ACTIVITY_COUNT = ('analytics.cumulative_devices', 'metrics.cumulative_total')
  )
);

/* Hardware geo and product name analytics with cumulative metrics */
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