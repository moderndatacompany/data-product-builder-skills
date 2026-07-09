MODEL (
  name QCOMMERCE_PLATFORM.BRONZE.SHIPMENTS_CLEAN,
  kind FULL,
  cron '*/15 * * * *',
  owner 'shreyasikarwartmdcio',
  grains [SHIPMENT_ID],
  description 'Standardized shipment attempt records with delivery duration and delivery outcome flags.',
  tags ('bronze', 'shipments', 'delivery', 'attempts'),
  terms ('shipments_clean', 'shipment_attempt', 'failed_delivery'),
  profiles (SHIPMENT_STATUS, SCAN_COUNT, DELIVERY_MINUTES, IS_FAILED_DELIVERY),
  columns (
    SHIPMENT_ID VARCHAR(50),
    ORDER_ID VARCHAR(50),
    RIDER_ID VARCHAR(50),
    PICKUP_TS TIMESTAMP,
    DELIVERED_TS TIMESTAMP,
    SHIPMENT_STATUS VARCHAR(50),
    SCAN_COUNT INTEGER,
    DELIVERY_MINUTES INTEGER,
    IS_DELIVERED BOOLEAN,
    IS_FAILED_DELIVERY BOOLEAN
  ),
  column_descriptions (
    SHIPMENT_ID = 'Unique shipment attempt identifier',
    ORDER_ID = 'Order identifier associated with the shipment attempt',
    RIDER_ID = 'Rider identifier assigned to the shipment attempt',
    PICKUP_TS = 'Timestamp when the rider picked up the order',
    DELIVERED_TS = 'Timestamp when the order was delivered or marked complete',
    SHIPMENT_STATUS = 'Standardized shipment outcome status',
    SCAN_COUNT = 'Number of operational scan events recorded for the shipment',
    DELIVERY_MINUTES = 'Elapsed minutes between pickup and delivery timestamps',
    IS_DELIVERED = 'Boolean flag indicating whether the shipment was successfully delivered',
    IS_FAILED_DELIVERY = 'Boolean flag indicating whether the shipment attempt failed'
  ),
  column_tags (
    SHIPMENT_ID = ('identifier', 'primary_key', 'grain'),
    ORDER_ID = ('identifier', 'foreign_key', 'order'),
    RIDER_ID = ('identifier', 'foreign_key', 'rider'),
    PICKUP_TS = ('temporal', 'event_time', 'pickup'),
    DELIVERED_TS = ('temporal', 'event_time', 'delivery'),
    SHIPMENT_STATUS = ('status', 'delivery', 'shipment'),
    SCAN_COUNT = ('measure', 'count', 'operations'),
    DELIVERY_MINUTES = ('measure', 'duration', 'delivery'),
    IS_DELIVERED = ('flag', 'status', 'delivery'),
    IS_FAILED_DELIVERY = ('flag', 'status', 'delivery_failure')
  ),
  column_terms (
    SHIPMENT_ID = ('shipment_id', 'shipment_attempt_id', 'delivery_attempt_id'),
    ORDER_ID = ('order_id', 'delivery_order_id', 'shipment_order_key'),
    RIDER_ID = ('rider_id', 'courier_id', 'delivery_agent_id'),
    PICKUP_TS = ('pickup_timestamp', 'pickup_ts', 'picked_up_at'),
    DELIVERED_TS = ('delivered_timestamp', 'delivered_ts', 'delivered_at'),
    SHIPMENT_STATUS = ('shipment_status', 'delivery_status', 'attempt_status'),
    SCAN_COUNT = ('scan_count', 'event_scan_count', 'ops_scan_count'),
    DELIVERY_MINUTES = ('delivery_minutes', 'pickup_to_drop_minutes', 'transit_minutes'),
    IS_DELIVERED = ('is_delivered', 'delivered_flag', 'successful_delivery'),
    IS_FAILED_DELIVERY = ('is_failed_delivery', 'failed_delivery_flag', 'delivery_failure')
  ),
  assertions (
    not_null(columns := (SHIPMENT_ID, ORDER_ID)),
    unique_values(columns := (SHIPMENT_ID)),
    accepted_range(column := SCAN_COUNT, min_v := 0, max_v := 1000)
  )
);

SELECT
  SHIPMENT_ID::VARCHAR(50) AS SHIPMENT_ID,
  ORDER_ID::VARCHAR(50) AS ORDER_ID,
  RIDER_ID::VARCHAR(50) AS RIDER_ID,
  PICKUP_TS::TIMESTAMP AS PICKUP_TS,
  DELIVERED_TS::TIMESTAMP AS DELIVERED_TS,
  LOWER(TRIM(SHIPMENT_STATUS::VARCHAR(50))) AS SHIPMENT_STATUS,
  SCAN_COUNT::INTEGER AS SCAN_COUNT,
  CASE
    WHEN PICKUP_TS IS NOT NULL AND DELIVERED_TS IS NOT NULL
      THEN DATEDIFF('minute', PICKUP_TS::TIMESTAMP, DELIVERED_TS::TIMESTAMP)
    ELSE NULL
  END AS DELIVERY_MINUTES,
  CASE
    WHEN LOWER(TRIM(SHIPMENT_STATUS::VARCHAR(50))) = 'delivered' AND DELIVERED_TS IS NOT NULL THEN TRUE
    ELSE FALSE
  END AS IS_DELIVERED,
  CASE
    WHEN LOWER(TRIM(SHIPMENT_STATUS::VARCHAR(50))) IN ('failed', 'returned', 'cancelled') THEN TRUE
    WHEN DELIVERED_TS IS NULL AND LOWER(TRIM(SHIPMENT_STATUS::VARCHAR(50))) IN ('undelivered', 'delivery_failed') THEN TRUE
    ELSE FALSE
  END AS IS_FAILED_DELIVERY
FROM QCOMMERCE_PLATFORM.EXT_RAW.SHIPMENTS;
