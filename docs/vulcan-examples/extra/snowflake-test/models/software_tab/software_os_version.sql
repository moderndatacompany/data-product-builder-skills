MODEL (
  name LENOVO.USDK.software_os__@{rollup_type},
  kind FULL,
  description 'Software OS version distribution analytics',
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