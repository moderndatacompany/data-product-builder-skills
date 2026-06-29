MODEL (
  name s3depot.qcommerce_delivery_bronze.shipments_clean,
  kind FULL,
  owner 'shreyasikarwartmdcio',
  grains [shipment_id],
  description 'Standardized shipment attempt records with delivery duration and delivery outcome flags.',
  tags ('bronze', 'shipments', 'delivery', 'attempts'),
  terms ('shipments_clean', 'shipment_attempt', 'failed_delivery'),
  columns (
    shipment_id STRING,
    order_id STRING,
    rider_id STRING,
    pickup_ts TIMESTAMP,
    delivered_ts TIMESTAMP,
    shipment_status STRING,
    scan_count INT,
    delivery_minutes INT,
    is_delivered BOOLEAN,
    is_failed_delivery BOOLEAN
  ),
  assertions (
    not_null(columns := (shipment_id, order_id)),
    unique_values(columns := (shipment_id)),
    accepted_range(column := scan_count, min_v := 0, max_v := 1000)
  )
);

WITH shipments_base AS (
  SELECT
    CAST(shipment_id AS STRING) AS shipment_id,
    CAST(order_id AS STRING) AS order_id,
    CAST(rider_id AS STRING) AS rider_id,
    CAST(pickup_ts AS TIMESTAMP) AS pickup_ts,
    CAST(delivered_ts AS TIMESTAMP) AS delivered_ts,
    LOWER(TRIM(CAST(shipment_status AS STRING))) AS shipment_status,
    CAST(scan_count AS INT) AS scan_count
  FROM s3depot.qcommerce_delivery_bronze.raw_shipments
)
SELECT
  shipment_id,
  order_id,
  rider_id,
  pickup_ts,
  delivered_ts,
  shipment_status,
  scan_count,
  CASE
    WHEN pickup_ts IS NOT NULL AND delivered_ts IS NOT NULL
      THEN CAST((CAST(delivered_ts AS BIGINT) - CAST(pickup_ts AS BIGINT)) / 60 AS INT)
    ELSE NULL
  END AS delivery_minutes,
  CASE
    WHEN shipment_status = 'delivered' AND delivered_ts IS NOT NULL THEN TRUE
    ELSE FALSE
  END AS is_delivered,
  CASE
    WHEN shipment_status IN ('failed', 'returned', 'cancelled') THEN TRUE
    WHEN delivered_ts IS NULL AND shipment_status IN ('undelivered', 'delivery_failed') THEN TRUE
    ELSE FALSE
  END AS is_failed_delivery
FROM shipments_base;
