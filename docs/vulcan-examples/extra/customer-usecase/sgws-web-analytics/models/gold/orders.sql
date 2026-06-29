MODEL (
  name web_analytics_gold.ORDERS,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [ORDER_PK],
  description 'Gold layer orders fact table containing order transaction details with status tracking, rejection handling, pricing information, and integration keys for digital order matching',
  tags ('gold', 'fact', 'orders', 'transactional', 'digital_integration'),
  terms ('orders', 'order_transaction', 'order_tracking'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    ORDER_PK = 'Unique primary key for each order line item',
    ORDER_NO = 'Order number from order management system',
    ORDER_EXTERNAL_ID = 'External order identifier for digital/e-commerce integrations',
    INVOICE_NO = 'Invoice number generated after order fulfillment',
    INVOICE_LINE_NO = 'Line number within the invoice',
    ORDER_LINE_NO = 'Line number within the order',
    SITE_NUMBER = 'Distribution site number processing the order',
    SITE_ITEM_PK_ORDER = 'Composite key linking to product dimension',
    WAREHOUSE_NO = 'Warehouse number fulfilling the order',
    CUSTOMER_NO = 'Customer number placing the order',
    ORDER_ACCOUNT_ID = 'Account identifier for order billing',
    O_UNIQUE_ORDER_KEY = 'Unique composite key for joining with digital checkout data (site-invoice)',
    ITEM_NO = 'Product item number ordered',
    CASES = 'Number of cases ordered',
    BOTTLES = 'Number of bottles ordered',
    QTY_DEC_EQU = 'Order quantity in decimal equivalent units',
    ORDER_NET_AMT = 'Net order amount after discounts (negative values set to zero)',
    ORDER_PRICE_PER_CASE = 'Unit price per case for this order line',
    ORDER_DSCT_PER_CASE = 'Discount amount per case applied',
    SOURCE = 'Data source indicator for the order',
    ENTRY_ORIGIN = 'Origin code indicating order entry channel',
    ORDER_STATUS_CD = 'Order status code (A=Approved, P=Pending, R=Rejected, C=Cancelled)',
    ORDER_STATUS = 'Human-readable order status description',
    ORDER_REJECT_CD = 'Rejection reason code if order was rejected',
    ORDER_REJECT_DT = 'Date when order was rejected',
    ORDER_REJECT_TIME = 'Time when order was rejected',
    ORDER_REJECT_BY = 'User or system that rejected the order',
    IS_REJECTED = 'Boolean flag indicating if order was rejected',
    ORDER_ENTRY_DT = 'Date and time when order was entered',
    INVOICE_DT = 'Date when invoice was generated',
    POSTING_PERIOD = 'Accounting posting period',
    ORDER_DATE = 'Order entry date (date-only version)',
    ORDER_LAST_PURCHASE_FK = 'Foreign key to last purchase record',
    LAST_MODIFIED_DT = 'Timestamp of last modification to order record',
    LOAD_DT = 'Timestamp when record was loaded into data warehouse',
    MODIFIED_DT = 'Timestamp of last update to source system'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    ORDER_PK = ('identifier', 'primary_key', 'grain', 'unique'),
    ORDER_NO = ('identifier', 'business_key', 'document_number'),
    ORDER_EXTERNAL_ID = ('identifier', 'external_key', 'digital', 'integration'),
    INVOICE_NO = ('identifier', 'document_number', 'billing'),
    O_UNIQUE_ORDER_KEY = ('identifier', 'composite_key', 'join_key', 'digital'),
    CUSTOMER_NO = ('identifier', 'foreign_key', 'dimension'),
    ITEM_NO = ('identifier', 'foreign_key', 'dimension'),
    SITE_NUMBER = ('identifier', 'foreign_key', 'location'),
    WAREHOUSE_NO = ('identifier', 'fulfillment', 'location'),
    ORDER_NET_AMT = ('metric', 'revenue', 'currency', 'kpi'),
    CASES = ('metric', 'quantity', 'inventory'),
    BOTTLES = ('metric', 'quantity', 'inventory'),
    QTY_DEC_EQU = ('metric', 'quantity', 'calculated'),
    ORDER_PRICE_PER_CASE = ('metric', 'price', 'currency'),
    ORDER_DSCT_PER_CASE = ('metric', 'discount', 'currency'),
    ORDER_STATUS_CD = ('status', 'classification', 'lifecycle'),
    ORDER_STATUS = ('status', 'classification', 'derived', 'human_readable'),
    ORDER_REJECT_CD = ('classification', 'rejection', 'reason_code'),
    IS_REJECTED = ('flag', 'boolean', 'derived', 'rejection'),
    ORDER_ENTRY_DT = ('temporal', 'timestamp', 'order_lifecycle'),
    INVOICE_DT = ('temporal', 'date', 'billing'),
    ORDER_DATE = ('temporal', 'date', 'derived'),
    POSTING_PERIOD = ('temporal', 'period', 'accounting'),
    ENTRY_ORIGIN = ('classification', 'channel', 'source'),
    SOURCE = ('classification', 'data_source'),
    LAST_MODIFIED_DT = ('temporal', 'timestamp', 'audit'),
    LOAD_DT = ('temporal', 'timestamp', 'etl'),
    MODIFIED_DT = ('temporal', 'timestamp', 'audit')
  ),
  
  -- ==================== COLUMN TERMS ====================
  column_terms (
    ORDER_PK = ('transaction_key', 'order_line'),
    O_UNIQUE_ORDER_KEY = ('digital_key', 'checkout_key'),
    ORDER_EXTERNAL_ID = ('external_id', 'order_id'),
    ORDER_NET_AMT = ('order_amount', 'net_revenue'),
    ORDER_STATUS = ('status_label', 'state'),
    IS_REJECTED = ('rejection_flag', 'rejection_indicator'),
    ORDER_ENTRY_DT = ('entry_timestamp', 'created_at')
  ),
  
  -- ==================== ASSERTIONS (Critical - Blocking) ====================
  assertions (
    -- Primary key must be unique and not null
    not_null(columns := (ORDER_PK)),
    unique_values(columns := (ORDER_PK)),
    
    -- Business rules
    not_null(columns := (ORDER_NO, CUSTOMER_NO))
  ),
  
  -- ==================== PROFILES (Observation - Tracking) ====================
  profiles (
    ORDER_PK,
    ORDER_NO,
    ORDER_EXTERNAL_ID,
    CUSTOMER_NO,
    ITEM_NO,
    ORDER_NET_AMT,
    ORDER_STATUS,
    ORDER_STATUS_CD,
    IS_REJECTED,
    ORDER_ENTRY_DT
  )
);

-- ============================================================================
-- GOLD LAYER: Orders
-- ============================================================================
-- Source: web_analytics_silver.ORDERS
-- Business-ready order data for analytics
-- ============================================================================

WITH cleaned AS (
  SELECT
    ORDER_PK,
    COALESCE(NULLIF(TRIM(CAST(ORDER_NO AS STRING)), ''), '0') AS ORDER_NO,
    ORDER_EXTERNAL_ID,
    COALESCE(NULLIF(TRIM(CAST(INVOICE_NO AS STRING)), ''), '0') AS INVOICE_NO,
    INVOICE_LINE_NO,
    ORDER_LINE_NO,
    SITE_NUMBER,
    SITE_ITEM_PK_ORDER,
    WAREHOUSE_NO,
    COALESCE(NULLIF(TRIM(CAST(CUSTOMER_NO AS STRING)), ''), '0') AS CUSTOMER_NO,
    ORDER_ACCOUNT_ID,
    ITEM_NO,
    CASES,
    bottles,
    qty_dec_equ,
    CASE
      WHEN order_net_amt < 0 THEN 0
      ELSE order_net_amt
    END AS order_net_amt,
    order_price_per_case,
    order_dsct_per_case,
    source,
    entry_origin,
    order_status_cd,
    order_reject_cd,
    order_reject_dt,
    order_reject_time,
    order_reject_by,
    order_entry_dt,
    invoice_dt,
    posting_period,
    order_last_purchase_fk,
    last_modified_dt,
    load_dt,
    modified_dt
  FROM web_analytics_silver.ORDERS
)
SELECT
  -- ==================== PRIMARY KEY ====================
  order_pk,
  
  -- ==================== IDENTIFIERS ====================
  order_no,
  order_external_id,
  invoice_no,
  invoice_line_no,
  order_line_no,
  
  -- ==================== SITE INFO ====================
  site_number,
  site_item_pk_order,
  warehouse_no,
  
  -- ==================== CUSTOMER INFO ====================
  customer_no,
  order_account_id,
  
  -- ==================== UNIQUE ORDER KEY (for joins with web_heartbeat/adobe_checkout) ====================
  CONCAT(CAST(site_number AS STRING), '-', CAST(invoice_no AS STRING)) AS o_unique_order_key,
  
  -- ==================== PRODUCT INFO ====================
  item_no,
  
  -- ==================== QUANTITIES ====================
  cases,
  bottles,
  qty_dec_equ,
  
  -- ==================== PRICING ====================
  order_net_amt,
  order_price_per_case,
  order_dsct_per_case,
  
  -- ==================== SOURCE & ORIGIN ====================
  source,
  entry_origin,
  
  -- ==================== ORDER STATUS ====================
  order_status_cd,
  CASE 
    WHEN order_status_cd = 'A' THEN 'Approved'
    WHEN order_status_cd = 'P' THEN 'Pending'
    WHEN order_status_cd = 'R' THEN 'Rejected'
    WHEN order_status_cd = 'C' THEN 'Cancelled'
    ELSE 'Unknown'
  END AS order_status,
  
  -- ==================== REJECTION INFO ====================
  order_reject_cd,
  order_reject_dt,
  order_reject_time,
  order_reject_by,
  CASE WHEN order_reject_cd IS NOT NULL THEN true ELSE false END AS is_rejected,
  
  -- ==================== DATES ====================
  order_entry_dt,
  invoice_dt,
  posting_period,
  CAST(order_entry_dt AS DATE) AS order_date,
  -- NOTE: Avoid extra date-part windows here to keep Spark/Iceberg planning stable.
  
  -- ==================== METADATA ====================
  ORDER_LAST_PURCHASE_FK,
  LAST_MODIFIED_DT,
  LOAD_DT,
  MODIFIED_DT

FROM cleaned
WHERE
  -- Keep predicate pushdown simple to avoid Spark V2 pushdown assertion bugs.
  ORDER_PK IS NOT NULL
