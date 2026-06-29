MODEL (
  name LENOVO.USDK.software_product_version__@{rollup_type},
  kind FULL,
  description 'Software product, version, and component analytics',
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