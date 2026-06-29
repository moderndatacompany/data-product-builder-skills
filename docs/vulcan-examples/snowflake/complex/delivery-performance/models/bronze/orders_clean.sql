MODEL (
  name QCOMMERCE_PLATFORM.BRONZE.ORDERS_CLEAN,
  kind VIEW,
  owner 'shreyasikarwartmdcio',
  grains [ORDER_ID],
  description 'Cleaned order master combining external order events with customer attributes for downstream delivery analytics.',
  tags ('bronze', 'orders', 'delivery', 'customer'),
  terms ('orders_clean', 'order_master', 'customer_tier'),
  profiles (CITY, ORDER_AMOUNT, CUSTOMER_TIER, NORMALIZED_PAYMENT_STATUS),
  columns (
    ORDER_ID VARCHAR(50),
    CUSTOMER_ID VARCHAR(50),
    CITY VARCHAR(100),
    ORDER_TS TIMESTAMP,
    ORDER_DATE DATE,
    ORDER_AMOUNT DECIMAL(12, 2),
    PAYMENT_STATUS VARCHAR(50),
    NORMALIZED_PAYMENT_STATUS VARCHAR(50),
    DELIVERY_MODE VARCHAR(50),
    CUSTOMER_NAME VARCHAR(200),
    CUSTOMER_TIER VARCHAR(50),
    SIGNUP_CITY VARCHAR(100),
    IS_ACTIVE BOOLEAN
  ),
  column_descriptions (
    ORDER_ID = 'Unique order identifier for the delivery transaction',
    CUSTOMER_ID = 'Customer identifier associated with the order',
    CITY = 'Fulfillment city where the order is placed',
    ORDER_TS = 'Timestamp when the order was created',
    ORDER_DATE = 'Calendar date derived from ORDER_TS',
    ORDER_AMOUNT = 'Gross monetary value of the order',
    PAYMENT_STATUS = 'Raw payment status captured from the source system',
    NORMALIZED_PAYMENT_STATUS = 'Standardized payment status used for analytics',
    DELIVERY_MODE = 'Delivery service mode requested for the order',
    CUSTOMER_NAME = 'Customer display name from the customer master',
    CUSTOMER_TIER = 'Customer segment such as STANDARD, PREMIUM, or VIP',
    SIGNUP_CITY = 'City where the customer originally signed up',
    IS_ACTIVE = 'Boolean flag indicating whether the customer is active'
  ),
  column_tags (
    ORDER_ID = ('identifier', 'primary_key', 'grain'),
    CUSTOMER_ID = ('identifier', 'foreign_key', 'customer'),
    CITY = ('dimension', 'geography', 'grouping'),
    ORDER_TS = ('temporal', 'event_time', 'order'),
    ORDER_DATE = ('temporal', 'date', 'partition_key'),
    ORDER_AMOUNT = ('measure', 'currency', 'revenue'),
    PAYMENT_STATUS = ('status', 'raw', 'payment'),
    NORMALIZED_PAYMENT_STATUS = ('status', 'standardized', 'payment'),
    DELIVERY_MODE = ('dimension', 'service-level', 'delivery'),
    CUSTOMER_NAME = ('dimension', 'descriptive', 'customer'),
    CUSTOMER_TIER = ('dimension', 'segment', 'customer'),
    SIGNUP_CITY = ('dimension', 'geography', 'customer_profile'),
    IS_ACTIVE = ('flag', 'status', 'customer')
  ),
  column_terms (
    ORDER_ID = ('order_id', 'delivery_order_id', 'business_order_key'),
    CUSTOMER_ID = ('customer_id', 'buyer_id', 'consumer_id'),
    CITY = ('city', 'delivery_city', 'order_city'),
    ORDER_TS = ('order_timestamp', 'order_ts', 'order_created_at'),
    ORDER_DATE = ('order_date', 'business_date', 'ds'),
    ORDER_AMOUNT = ('order_amount', 'gross_order_value', 'basket_value'),
    PAYMENT_STATUS = ('payment_status', 'transaction_status', 'payment_state'),
    NORMALIZED_PAYMENT_STATUS = ('normalized_payment_status', 'payment_status_standardized', 'payment_bucket'),
    DELIVERY_MODE = ('delivery_mode', 'service_type', 'delivery_speed'),
    CUSTOMER_NAME = ('customer_name', 'buyer_name', 'consumer_name'),
    CUSTOMER_TIER = ('customer_tier', 'loyalty_tier', 'service_segment'),
    SIGNUP_CITY = ('signup_city', 'registration_city', 'customer_home_city'),
    IS_ACTIVE = ('is_active', 'customer_active_flag', 'active_customer')
  ),
  assertions (
    not_null(columns := (ORDER_ID, CUSTOMER_ID, CITY, ORDER_TS)),
    unique_values(columns := (ORDER_ID)),
    accepted_range(column := ORDER_AMOUNT, min_v := 0, max_v := 100000)
  )
);

WITH orders_base AS (
  SELECT
    ORDER_ID::VARCHAR(50) AS ORDER_ID,
    CUSTOMER_ID::VARCHAR(50) AS CUSTOMER_ID,
    INITCAP(TRIM(CITY::VARCHAR(100))) AS CITY,
    ORDER_TS::TIMESTAMP AS ORDER_TS,
    ORDER_AMOUNT::DECIMAL(12, 2) AS ORDER_AMOUNT,
    LOWER(TRIM(PAYMENT_STATUS::VARCHAR(50))) AS PAYMENT_STATUS,
    LOWER(TRIM(DELIVERY_MODE::VARCHAR(50))) AS DELIVERY_MODE
  FROM QCOMMERCE_PLATFORM.EXT_RAW.ORDERS
),
customers_base AS (
  SELECT
    CUSTOMER_ID::VARCHAR(50) AS CUSTOMER_ID,
    CUSTOMER_NAME::VARCHAR(200) AS CUSTOMER_NAME,
    UPPER(TRIM(CUSTOMER_TIER::VARCHAR(50))) AS CUSTOMER_TIER,
    INITCAP(TRIM(SIGNUP_CITY::VARCHAR(100))) AS SIGNUP_CITY,
    IS_ACTIVE::BOOLEAN AS IS_ACTIVE
  FROM QCOMMERCE_PLATFORM.EXT_RAW.CUSTOMERS
)
SELECT
  o.ORDER_ID,
  o.CUSTOMER_ID,
  o.CITY,
  o.ORDER_TS,
  CAST(o.ORDER_TS AS DATE) AS ORDER_DATE,
  o.ORDER_AMOUNT,
  o.PAYMENT_STATUS,
  CASE
    WHEN o.PAYMENT_STATUS IN ('paid', 'captured', 'settled') THEN 'paid'
    WHEN o.PAYMENT_STATUS IN ('failed', 'declined') THEN 'failed'
    WHEN o.PAYMENT_STATUS IN ('refunded', 'partial_refund') THEN 'refunded'
    WHEN o.PAYMENT_STATUS IN ('pending', 'authorized') THEN 'pending'
    ELSE 'unknown'
  END AS NORMALIZED_PAYMENT_STATUS,
  o.DELIVERY_MODE,
  c.CUSTOMER_NAME,
  COALESCE(c.CUSTOMER_TIER, 'STANDARD') AS CUSTOMER_TIER,
  c.SIGNUP_CITY,
  COALESCE(c.IS_ACTIVE, TRUE) AS IS_ACTIVE
FROM orders_base o
LEFT JOIN customers_base c
  ON o.CUSTOMER_ID = c.CUSTOMER_ID;
