MODEL (
  name LENOVO.USDK.software_geo_product__@{rollup_type},
  kind FULL,
  description 'Software geography and product analytics',
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