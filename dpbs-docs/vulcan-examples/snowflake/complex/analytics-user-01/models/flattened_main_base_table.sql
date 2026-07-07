MODEL (
  name LENOVO.USDK.FLATTENED_MAIN_BASE_TABLE,
  kind FULL,
  partitioned_by EVENT_DATE,
  owner 'shreyasikarwartmdcio',
  profiles (EVENT_DATE, ANONYMOUS_DEVICE_IDV1, DEVICE_TYPE, MANUFACTURER, GEO, MODEL, OS_VERSION, PRODUCT_VERSION, HW_IN_USE_YEARS, ACTION, ROLLUP_TYPE),
  tags ('silver', 'device-engagement', 'analytics', 'time-series', 'rollup-aggregations', 'lenovo', 'usdk', 'flattened'),
  terms ('device_engagement', 'user_analytics', 'time_series_data'),
  description 'Silver layer fact table with flattened analytics events aggregated across multiple time windows (yesterday, 7/30/90/180/365 days). Supports device engagement analysis, hardware lifecycle tracking, and product adoption metrics with pre-computed rollups for performance.',
  grains (
    ANONYMOUS_DEVICE_IDV1
  ),
  columns (
    EVENT_DATE DATE,
    ANONYMOUS_DEVICE_IDV1 VARCHAR,
    DEVICE_TYPE VARCHAR,
    MANUFACTURER VARCHAR,
    NAME VARCHAR,
    GEO VARCHAR,
    COMPONENT_ID VARCHAR,
    COMPONENT_VERSION VARCHAR,
    MODEL VARCHAR,
    OS_VERSION VARCHAR,
    PRODUCT_VERSION VARCHAR,
    PRODUCT_ID VARCHAR,
    HW_IN_USE_YEARS INT,
    ACTION VARCHAR,
    ROLLUP_TYPE VARCHAR
  ),
  column_descriptions (
    generated_anonymous_user_id = 'Generated anonymous user ID',
    EVENT_DATE = 'Date of the event occurrence, used for partitioning and time-based analysis',
    ANONYMOUS_DEVICE_IDV1 = 'Anonymous device identifier (version 1) used for tracking unique devices while preserving privacy',
    DEVICE_TYPE = 'Type of device (e.g., PC, Laptop, Tablet). Defaults to "Not Found" if unavailable',
    MANUFACTURER = 'Device manufacturer name (e.g., Lenovo, Dell, HP)',
    NAME = 'Event or screen name in lowercase format',
    GEO = 'Geographic location code (country code) where the event originated',
    COMPONENT_ID = 'Software component identifier. Defaults to "Not Found" if unavailable',
    COMPONENT_VERSION = 'Version of the software component. Defaults to "Not Found" if unavailable',
    MODEL = 'Device model identifier (MTM - Machine Type Model). Defaults to "Not Found" if unavailable',
    OS_VERSION = 'Operating system version in format X.X.X (first 3 parts extracted, e.g., 10.0.19041)',
    PRODUCT_VERSION = 'Software product version. Defaults to "Not Found" if unavailable',
    PRODUCT_ID = 'Unique product identifier for the software. Defaults to "Not Found" if unavailable',
    HW_IN_USE_YEARS = 'Calculated hardware age in years (current year minus first run year)',
    ACTION = 'Type of activity: "Engaged Activity" (interactive actions), "All Activity", "Install Base" (existence), or "PageView"',
    ROLLUP_TYPE = 'Time window aggregation type: yesterday, last_7_days, last_30_days, last_90_days, last_180_days, or last_365_days'
  ),
  column_tags (
    EVENT_DATE = ('partition-key', 'time-dimension', 'date', 'temporal'),
    ANONYMOUS_DEVICE_IDV1 = ('device-id', 'anonymized', 'pii-safe', 'identifier'),
    DEVICE_TYPE = ('device-attribute', 'dimension', 'categorical'),
    MANUFACTURER = ('device-attribute', 'brand', 'dimension'),
    NAME = ('event-attribute', 'screen-name', 'categorical'),
    GEO = ('geography', 'location', 'country-code', 'dimension'),
    COMPONENT_ID = ('product-attribute', 'software-component', 'dimension'),
    COMPONENT_VERSION = ('product-attribute', 'version', 'software-version'),
    MODEL = ('device-attribute', 'model', 'mtm', 'hardware-id'),
    OS_VERSION = ('system-info', 'os', 'version', 'dimension'),
    PRODUCT_VERSION = ('product-attribute', 'version', 'dimension'),
    PRODUCT_ID = ('product-attribute', 'identifier', 'dimension'),
    HW_IN_USE_YEARS = ('hardware-metrics', 'calculated', 'measure', 'derived'),
    ACTION = ('activity-type', 'engagement-metric', 'categorical', 'dimension'),
    ROLLUP_TYPE = ('time-dimension', 'aggregation-window', 'categorical', 'dimension')
  ),
  column_terms (
    EVENT_DATE = ('event_date', 'date'),
    ANONYMOUS_DEVICE_IDV1 = ('anonymous_id', 'device_identifier'),
    DEVICE_TYPE = ('type', 'device_type'),
    MANUFACTURER = ('manufacturer', 'vendor'),
    NAME = ('event_name', 'screen_name'),
    GEO = ('country_code', 'geo'),
    COMPONENT_ID = ('component_id', 'component'),
    COMPONENT_VERSION = ('component_version', 'version'),
    MODEL = ('model', 'mtm'),
    OS_VERSION = ('os_version', 'os'),
    PRODUCT_VERSION = ('version', 'product_version'),
    PRODUCT_ID = ('identifier', 'product_id'),
    HW_IN_USE_YEARS = ('age_years', 'lifecycle_years'),
    ACTION = ('action_type', 'activity_type'),
    ROLLUP_TYPE = ('time_window', 'rollup_period')
  )
);

/* Flatten consumer analytics events into structured format */
WITH selected AS (
  SELECT
    CAST(GET_PATH(context, 'user.generated_anonymous_user_id') AS VARCHAR) AS generated_anonymous_user_id,
    CAST(GET_PATH(context, 'device.device_type') AS VARCHAR) AS device_type,
    CAST(GET_PATH(context, 'device.anonymous_device_idv1') AS VARCHAR) AS anonymous_device_idv1,
    CAST(GET_PATH(context, 'device.manufacturer') AS VARCHAR) AS manufacturer,
    CAST(GET_PATH(context, 'device.product_name') AS VARCHAR) AS product_name,
    CAST(GET_PATH(context, 'device.model') AS VARCHAR) AS model,
    CAST(GET_PATH(context, 'environment.os') AS VARCHAR) AS os,
    CAST(GET_PATH(context, 'environment.os_version') AS VARCHAR) AS os_version,
    CAST(GET_PATH(context, 'environment.first_run_date') AS TIMESTAMP) AS first_run_date,
    CAST(GET_PATH(context, 'environment.locale') AS VARCHAR) AS locale,
    CAST(GET_PATH(context, 'environment.geo') AS VARCHAR) AS geo,
    CAST(GET_PATH(context, 'environment.session_id') AS VARCHAR) AS context_session_id,
    CAST(GET_PATH(context, 'product.product_id') AS VARCHAR) AS product_id,
    CAST(GET_PATH(context, 'product.product_version') AS VARCHAR) AS product_version,
    CAST(GET_PATH(context, 'product.component_id') AS VARCHAR) AS component_id,
    CAST(GET_PATH(context, 'product.component_version') AS VARCHAR) AS component_version,
    CAST(GET_PATH(context, 'product.collect_sdk_version') AS VARCHAR) AS collect_sdk_version,
    CAST(GET_PATH(context, 'product.sync_sdk_version') AS VARCHAR) AS sync_sdk_version,
    CAST(GET_PATH(event, 'timestamp') AS TIMESTAMP) AS event_timestamp,
    CAST(GET_PATH(event, 'action') AS VARCHAR) AS action,
    CAST(GET_PATH(event, 'name') AS VARCHAR) AS name,
    GET_PATH(event, 'data') AS data,
    CAST(GET_PATH(event, 'aggregation.method') AS VARCHAR) AS aggregation_method,
    CAST(GET_PATH(event, 'aggregation.count') AS INT) AS aggregation_count,
    CAST(GET_PATH(event, 'aggregation.first_time') AS TIMESTAMP) AS first_date_time,
    CAST(GET_PATH(event, 'aggregation.last_time') AS TIMESTAMP) AS aggregation_last_time,
    reporting_time
  FROM LENOVO.USDK.CONSUMER_ANALYTICS_EVENTS
), base_events AS (
  SELECT
    TO_DATE(event_timestamp) AS event_date,
    anonymous_device_idv1,
    COALESCE(device_type, 'Not Found') AS device_type,
    manufacturer,
    LOWER(name) AS name,
    geo,
    COALESCE(component_id, 'Not Found') AS component_id,
    COALESCE(component_version, 'Not Found') AS component_version,
    COALESCE(model, 'Not Found') AS model,
    REGEXP_SUBSTR(os_version, '^([^.]+\\.[^.]+\\.[^.]+)', 1, 1, 'e') AS os_version, /* Extract first 3 parts of version number (e.g., 10.0.19041 from 10.0.19041.1234) */
    COALESCE(product_version, 'Not Found') AS product_version,
    COALESCE(product_id, 'Not Found') AS product_id,
    YEAR(CURRENT_TIMESTAMP()) - YEAR(first_date_time) AS hw_in_use_years,
    LOWER(action) AS action
  FROM selected
), engaged_activity AS (
  SELECT
    event_date,
    anonymous_device_idv1,
    device_type,
    manufacturer,
    name,
    geo,
    component_id,
    component_version,
    model,
    os_version,
    product_version,
    product_id,
    hw_in_use_years,
    'Engaged Activity' AS action
  FROM base_events
  WHERE
    action IN ('pageview', 'view', 'click', 'useractivity', 'foregroundlaunch')
), all_activity AS (
  SELECT
    event_date,
    anonymous_device_idv1,
    device_type,
    manufacturer,
    name,
    geo,
    component_id,
    component_version,
    model,
    os_version,
    product_version,
    product_id,
    hw_in_use_years,
    'All Activity' AS action
  FROM base_events
), install_base AS (
  SELECT
    event_date,
    anonymous_device_idv1,
    device_type,
    manufacturer,
    name,
    geo,
    component_id,
    component_version,
    model,
    os_version,
    product_version,
    product_id,
    hw_in_use_years,
    'Install Base' AS action
  FROM base_events
  WHERE
    action = 'exist'
), PageView AS (
  SELECT
    event_date,
    anonymous_device_idv1,
    device_type,
    manufacturer,
    name,
    geo,
    component_id,
    component_version,
    model,
    os_version,
    product_version,
    product_id,
    hw_in_use_years,
    'PageView' AS action
  FROM base_events
  WHERE
    action = 'pageview'
), flattened_base AS (
  SELECT
    *
  FROM all_activity
  UNION ALL
  SELECT
    *
  FROM engaged_activity
  UNION ALL
  SELECT
    *
  FROM install_base
  UNION ALL
  SELECT
    *
  FROM PageView
)
SELECT
  *,
  'yesterday' AS rollup_type
FROM flattened_base
WHERE
  event_date = DATEADD(DAY, -1, CURRENT_DATE)
UNION ALL
SELECT
  *,
  'last_7_days' AS rollup_type
FROM flattened_base
WHERE
  event_date BETWEEN DATEADD(DAY, -7, CURRENT_DATE) AND DATEADD(DAY, -1, CURRENT_DATE)
UNION ALL
SELECT
  *,
  'last_30_days' AS rollup_type
FROM flattened_base
WHERE
  event_date BETWEEN DATEADD(DAY, -30, CURRENT_DATE) AND DATEADD(DAY, -1, CURRENT_DATE)
UNION ALL
SELECT
  *,
  'last_90_days' AS rollup_type
FROM flattened_base
WHERE
  event_date BETWEEN DATEADD(DAY, -90, CURRENT_DATE) AND DATEADD(DAY, -1, CURRENT_DATE)
UNION ALL
SELECT
  *,
  'last_180_days' AS rollup_type
FROM flattened_base
WHERE
  event_date BETWEEN DATEADD(DAY, -180, CURRENT_DATE) AND DATEADD(DAY, -1, CURRENT_DATE)
UNION ALL
SELECT
  *,
  'last_365_days' AS rollup_type
FROM flattened_base
WHERE
  event_date BETWEEN DATEADD(DAY, -365, CURRENT_DATE) AND DATEADD(DAY, -1, CURRENT_DATE)