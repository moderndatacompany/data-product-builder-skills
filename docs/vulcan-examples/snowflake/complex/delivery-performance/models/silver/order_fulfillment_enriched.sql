MODEL (
  name QCOMMERCE_PLATFORM.SILVER.ORDER_FULFILLMENT_ENRICHED,
  kind FULL,
  cron '*/15 * * * *',
  owner 'shreyasikarwartmdcio',
  grains [ORDER_ID],
  description 'Canonical order-level fulfillment fact combining orders, latest shipment attempt, and SLA rules to derive delivery performance business logic.',
  tags ('silver', 'delivery', 'fulfillment', 'canonical-fact'),
  terms ('order_fulfillment_enriched', 'sla_breach', 'issue_type'),
  profiles (CITY, CUSTOMER_TIER, ISSUE_TYPE, IS_SLA_BREACHED),
  columns (
    ORDER_ID VARCHAR(50),
    CUSTOMER_ID VARCHAR(50),
    RIDER_ID VARCHAR(50),
    CITY VARCHAR(100),
    CUSTOMER_TIER VARCHAR(50),
    ORDER_DATE DATE,
    ORDER_AMOUNT DECIMAL(12, 2),
    ORDER_TS TIMESTAMP,
    PICKUP_TS TIMESTAMP,
    DELIVERED_TS TIMESTAMP,
    SHIPMENT_STATUS VARCHAR(50),
    NORMALIZED_PAYMENT_STATUS VARCHAR(50),
    DELIVERY_MODE VARCHAR(50),
    SCAN_COUNT INTEGER,
    DELIVERY_MINUTES INTEGER,
    SLA_MINUTES INTEGER,
    PROMISED_DELIVERY_TS TIMESTAMP,
    DELIVERY_DELAY_MINUTES INTEGER,
    IS_SLA_BREACHED BOOLEAN,
    IS_FAILED_DELIVERY BOOLEAN,
    ISSUE_TYPE VARCHAR(50)
  ),
  column_descriptions (
    ORDER_ID = 'Unique order identifier at the canonical fulfillment grain',
    CUSTOMER_ID = 'Customer identifier associated with the fulfilled order',
    RIDER_ID = 'Rider responsible for the latest shipment attempt',
    CITY = 'Fulfillment city used for SLA and KPI aggregation',
    CUSTOMER_TIER = 'Customer segment used for experience analysis',
    ORDER_DATE = 'Business date of the order',
    ORDER_AMOUNT = 'Gross order value used for business impact calculations',
    ORDER_TS = 'Timestamp when the order was placed',
    PICKUP_TS = 'Timestamp when the rider picked up the order',
    DELIVERED_TS = 'Timestamp when the order was delivered',
    SHIPMENT_STATUS = 'Latest shipment status associated with the order',
    NORMALIZED_PAYMENT_STATUS = 'Standardized payment status used for reporting',
    DELIVERY_MODE = 'Delivery speed or service mode requested for the order',
    SCAN_COUNT = 'Operational scan count from the latest shipment attempt',
    DELIVERY_MINUTES = 'Elapsed delivery duration in minutes from pickup to drop',
    SLA_MINUTES = 'Configured SLA threshold in minutes for the city and delivery mode',
    PROMISED_DELIVERY_TS = 'Calculated promised delivery timestamp based on ORDER_TS and SLA_MINUTES',
    DELIVERY_DELAY_MINUTES = 'Difference in minutes between promised and actual delivery timestamps',
    IS_SLA_BREACHED = 'Boolean flag indicating whether the delivery exceeded the SLA threshold',
    IS_FAILED_DELIVERY = 'Boolean flag indicating whether the shipment failed to complete',
    ISSUE_TYPE = 'Derived operational issue category explaining delivery performance'
  ),
  column_tags (
    ORDER_ID = ('identifier', 'primary_key', 'grain'),
    CUSTOMER_ID = ('identifier', 'foreign_key', 'customer'),
    RIDER_ID = ('identifier', 'foreign_key', 'rider'),
    CITY = ('dimension', 'geography', 'grouping'),
    CUSTOMER_TIER = ('dimension', 'segment', 'customer'),
    ORDER_DATE = ('temporal', 'date', 'partition_key'),
    ORDER_AMOUNT = ('measure', 'currency', 'revenue'),
    ORDER_TS = ('temporal', 'event_time', 'order'),
    PICKUP_TS = ('temporal', 'event_time', 'pickup'),
    DELIVERED_TS = ('temporal', 'event_time', 'delivery'),
    SHIPMENT_STATUS = ('status', 'shipment', 'delivery'),
    NORMALIZED_PAYMENT_STATUS = ('status', 'payment', 'standardized'),
    DELIVERY_MODE = ('dimension', 'service-level', 'delivery'),
    SCAN_COUNT = ('measure', 'count', 'operations'),
    DELIVERY_MINUTES = ('measure', 'duration', 'delivery'),
    SLA_MINUTES = ('measure', 'duration', 'sla'),
    PROMISED_DELIVERY_TS = ('temporal', 'derived', 'sla'),
    DELIVERY_DELAY_MINUTES = ('measure', 'duration', 'delay'),
    IS_SLA_BREACHED = ('flag', 'kpi', 'sla'),
    IS_FAILED_DELIVERY = ('flag', 'status', 'delivery_failure'),
    ISSUE_TYPE = ('dimension', 'classification', 'root_cause')
  ),
  column_terms (
    ORDER_ID = ('order_id', 'canonical_order_id', 'business_order_key'),
    CUSTOMER_ID = ('customer_id', 'buyer_id', 'consumer_id'),
    RIDER_ID = ('rider_id', 'courier_id', 'delivery_agent_id'),
    CITY = ('city', 'delivery_city', 'service_area'),
    CUSTOMER_TIER = ('customer_tier', 'loyalty_tier', 'service_segment'),
    ORDER_DATE = ('order_date', 'business_date', 'ds'),
    ORDER_AMOUNT = ('order_amount', 'gross_order_value', 'basket_value'),
    ORDER_TS = ('order_timestamp', 'order_ts', 'ordered_at'),
    PICKUP_TS = ('pickup_timestamp', 'pickup_ts', 'picked_up_at'),
    DELIVERED_TS = ('delivered_timestamp', 'delivered_ts', 'delivered_at'),
    SHIPMENT_STATUS = ('shipment_status', 'delivery_status', 'attempt_status'),
    NORMALIZED_PAYMENT_STATUS = ('normalized_payment_status', 'payment_bucket', 'payment_status_standardized'),
    DELIVERY_MODE = ('delivery_mode', 'service_type', 'delivery_speed'),
    SCAN_COUNT = ('scan_count', 'ops_scan_count', 'event_scan_count'),
    DELIVERY_MINUTES = ('delivery_minutes', 'transit_minutes', 'pickup_to_drop_minutes'),
    SLA_MINUTES = ('sla_minutes', 'delivery_target_minutes', 'promised_sla'),
    PROMISED_DELIVERY_TS = ('promised_delivery_ts', 'delivery_deadline', 'sla_deadline'),
    DELIVERY_DELAY_MINUTES = ('delivery_delay_minutes', 'lateness_minutes', 'delay_minutes'),
    IS_SLA_BREACHED = ('is_sla_breached', 'sla_breach_flag', 'late_delivery_flag'),
    IS_FAILED_DELIVERY = ('is_failed_delivery', 'failed_delivery_flag', 'delivery_failure'),
    ISSUE_TYPE = ('issue_type', 'delivery_issue_category', 'root_cause_type')
  ),
  assertions (
    not_null(columns := (ORDER_ID, CUSTOMER_ID, CITY, ORDER_DATE)),
    unique_values(columns := (ORDER_ID)),
    accepted_range(column := SLA_MINUTES, min_v := 1, max_v := 180)
  )
);

WITH latest_shipments AS (
  SELECT
    SHIPMENT_ID,
    ORDER_ID,
    RIDER_ID,
    PICKUP_TS,
    DELIVERED_TS,
    SHIPMENT_STATUS,
    SCAN_COUNT,
    DELIVERY_MINUTES,
    IS_DELIVERED,
    IS_FAILED_DELIVERY
  FROM QCOMMERCE_PLATFORM.BRONZE.SHIPMENTS_CLEAN
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY ORDER_ID
    ORDER BY COALESCE(DELIVERED_TS, PICKUP_TS) DESC, SHIPMENT_ID DESC
  ) = 1
),
base AS (
  SELECT
    o.ORDER_ID,
    o.CUSTOMER_ID,
    s.RIDER_ID,
    o.CITY,
    o.CUSTOMER_TIER,
    o.ORDER_DATE,
    o.ORDER_AMOUNT,
    o.ORDER_TS,
    s.PICKUP_TS,
    s.DELIVERED_TS,
    COALESCE(s.SHIPMENT_STATUS, 'not_shipped') AS SHIPMENT_STATUS,
    o.NORMALIZED_PAYMENT_STATUS,
    o.DELIVERY_MODE,
    COALESCE(s.SCAN_COUNT, 0) AS SCAN_COUNT,
    s.DELIVERY_MINUTES,
    COALESCE(r.SLA_MINUTES, 30) AS SLA_MINUTES,
    DATEADD('minute', COALESCE(r.SLA_MINUTES, 30), o.ORDER_TS) AS PROMISED_DELIVERY_TS,
    COALESCE(s.IS_FAILED_DELIVERY, FALSE) AS IS_FAILED_DELIVERY
  FROM QCOMMERCE_PLATFORM.BRONZE.ORDERS_CLEAN o
  LEFT JOIN latest_shipments s
    ON o.ORDER_ID = s.ORDER_ID
  LEFT JOIN QCOMMERCE_PLATFORM.BRONZE.CITY_SLA_RULES r
    ON o.CITY = r.CITY
   AND o.DELIVERY_MODE = r.DELIVERY_MODE
)
SELECT
  ORDER_ID,
  CUSTOMER_ID,
  RIDER_ID,
  CITY,
  CUSTOMER_TIER,
  ORDER_DATE,
  ORDER_AMOUNT,
  ORDER_TS,
  PICKUP_TS,
  DELIVERED_TS,
  SHIPMENT_STATUS,
  NORMALIZED_PAYMENT_STATUS,
  DELIVERY_MODE,
  SCAN_COUNT,
  DELIVERY_MINUTES,
  SLA_MINUTES,
  PROMISED_DELIVERY_TS,
  CASE
    WHEN DELIVERED_TS IS NOT NULL THEN DATEDIFF('minute', PROMISED_DELIVERY_TS, DELIVERED_TS)
    ELSE NULL
  END AS DELIVERY_DELAY_MINUTES,
  CASE
    WHEN IS_FAILED_DELIVERY THEN TRUE
    WHEN DELIVERED_TS IS NOT NULL AND DELIVERED_TS > PROMISED_DELIVERY_TS THEN TRUE
    ELSE FALSE
  END AS IS_SLA_BREACHED,
  IS_FAILED_DELIVERY,
  CASE
    WHEN IS_FAILED_DELIVERY THEN 'failed_delivery'
    WHEN DELIVERED_TS IS NULL AND SHIPMENT_STATUS = 'not_shipped' THEN 'missing_shipment'
    WHEN SCAN_COUNT = 0 THEN 'missing_scan'
    WHEN NORMALIZED_PAYMENT_STATUS = 'failed' THEN 'payment_issue'
    WHEN SHIPMENT_STATUS IN ('address_issue', 'bad_address') THEN 'address_issue'
    WHEN DELIVERED_TS IS NOT NULL AND DELIVERED_TS > PROMISED_DELIVERY_TS THEN 'late_delivery'
    ELSE 'on_time'
  END AS ISSUE_TYPE
FROM base;
