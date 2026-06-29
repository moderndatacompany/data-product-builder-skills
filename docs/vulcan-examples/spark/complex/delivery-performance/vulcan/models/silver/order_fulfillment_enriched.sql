MODEL (
  name s3depot.qcommerce_delivery_silver.order_fulfillment_enriched,
  kind FULL,
  owner 'shreyasikarwartmdcio',
  grains [order_id],
  description 'Canonical order-level fulfillment fact combining orders, latest shipment attempt, and SLA rules to derive delivery performance business logic.',
  tags ('silver', 'delivery', 'fulfillment', 'canonical-fact'),
  terms ('order_fulfillment_enriched', 'sla_breach', 'issue_type'),
  columns (
    order_id STRING,
    customer_id STRING,
    rider_id STRING,
    city STRING,
    customer_tier STRING,
    order_date DATE,
    order_amount DECIMAL(12, 2),
    order_ts TIMESTAMP,
    pickup_ts TIMESTAMP,
    delivered_ts TIMESTAMP,
    shipment_status STRING,
    normalized_payment_status STRING,
    delivery_mode STRING,
    scan_count INT,
    delivery_minutes INT,
    sla_minutes INT,
    promised_delivery_ts TIMESTAMP,
    delivery_delay_minutes INT,
    is_sla_breached BOOLEAN,
    is_failed_delivery BOOLEAN,
    issue_type STRING
  ),
  assertions (
    not_null(columns := (order_id, customer_id, city, order_date)),
    unique_values(columns := (order_id)),
    accepted_range(column := sla_minutes, min_v := 1, max_v := 180)
  )
);

WITH ranked_shipments AS (
  SELECT
    shipment_id,
    order_id,
    rider_id,
    pickup_ts,
    delivered_ts,
    shipment_status,
    scan_count,
    delivery_minutes,
    is_delivered,
    is_failed_delivery,
    ROW_NUMBER() OVER (
      PARTITION BY order_id
      ORDER BY COALESCE(delivered_ts, pickup_ts) DESC, shipment_id DESC
    ) AS rn
  FROM s3depot.qcommerce_delivery_bronze.shipments_clean
),
latest_shipments AS (
  SELECT
    shipment_id,
    order_id,
    rider_id,
    pickup_ts,
    delivered_ts,
    shipment_status,
    scan_count,
    delivery_minutes,
    is_delivered,
    is_failed_delivery
  FROM ranked_shipments
  WHERE rn = 1
),
base AS (
  SELECT
    o.order_id,
    o.customer_id,
    s.rider_id,
    o.city,
    o.customer_tier,
    o.order_date,
    o.order_amount,
    o.order_ts,
    s.pickup_ts,
    s.delivered_ts,
    COALESCE(s.shipment_status, 'not_shipped') AS shipment_status,
    o.normalized_payment_status,
    o.delivery_mode,
    COALESCE(s.scan_count, 0) AS scan_count,
    s.delivery_minutes,
    COALESCE(r.sla_minutes, 30) AS sla_minutes,
    CAST(FROM_UNIXTIME(CAST(o.order_ts AS BIGINT) + COALESCE(r.sla_minutes, 30) * 60) AS TIMESTAMP) AS promised_delivery_ts,
    COALESCE(s.is_failed_delivery, FALSE) AS is_failed_delivery
  FROM s3depot.qcommerce_delivery_bronze.orders_clean o
  LEFT JOIN latest_shipments s
    ON o.order_id = s.order_id
  LEFT JOIN s3depot.qcommerce_delivery_bronze.city_sla_rules r
    ON o.city = r.city
   AND o.delivery_mode = r.delivery_mode
)
SELECT
  order_id,
  customer_id,
  rider_id,
  city,
  customer_tier,
  order_date,
  order_amount,
  order_ts,
  pickup_ts,
  delivered_ts,
  shipment_status,
  normalized_payment_status,
  delivery_mode,
  scan_count,
  delivery_minutes,
  sla_minutes,
  promised_delivery_ts,
  CASE
    WHEN delivered_ts IS NOT NULL
      THEN CAST((CAST(delivered_ts AS BIGINT) - CAST(promised_delivery_ts AS BIGINT)) / 60 AS INT)
    ELSE NULL
  END AS delivery_delay_minutes,
  CASE
    WHEN is_failed_delivery THEN TRUE
    WHEN delivered_ts IS NOT NULL AND delivered_ts > promised_delivery_ts THEN TRUE
    ELSE FALSE
  END AS is_sla_breached,
  is_failed_delivery,
  CASE
    WHEN is_failed_delivery THEN 'failed_delivery'
    WHEN delivered_ts IS NULL AND shipment_status = 'not_shipped' THEN 'missing_shipment'
    WHEN scan_count = 0 THEN 'missing_scan'
    WHEN normalized_payment_status = 'failed' THEN 'payment_issue'
    WHEN shipment_status IN ('address_issue', 'bad_address') THEN 'address_issue'
    WHEN delivered_ts IS NOT NULL AND delivered_ts > promised_delivery_ts THEN 'late_delivery'
    ELSE 'on_time'
  END AS issue_type
FROM base;
