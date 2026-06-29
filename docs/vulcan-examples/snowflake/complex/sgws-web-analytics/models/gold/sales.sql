MODEL (
  name web_analytics_gold.SALES,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [SALES_PK],
  description 'Gold layer sales fact table containing transactional sales data for alcohol distribution, including invoice details, quantities, revenue, and customer relationships with proof-eligible filtering',
  tags ('gold', 'fact', 'sales', 'transactional', 'alcohol_distribution'),
  terms ('sales', 'sales_transaction', 'revenue'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    SALES_PK = 'Unique primary key for each sales transaction line item across all sites',
    S_SITE = 'Site identifier where the sale was recorded',
    CUSTOMER_NO = 'Customer number identifying the purchasing establishment',
    GCP_ACCOUNT_ID = 'Google Cloud Platform account identifier linking to customer master',
    ITEM_NO = 'Product item number from inventory master',
    INVOICE_NO = 'Invoice number for the sales transaction',
    EXT_NET = 'Extended net sales amount after discounts and allowances',
    CASES = 'Number of cases sold in this transaction',
    BOTTLES = 'Number of individual bottles sold',
    ENTRY_ORIGIN = 'Origin code indicating how the order was entered (e.g., UB=Web, J=Manual)',
    POSTING_DATE = 'Date when the transaction was posted to the accounting system',
    QTY_DEC_EQU = 'Quantity in decimal equivalent units (cases + bottles/12)',
    SOURCE = 'Data source indicator (Proof/Non-Proof/All)',
    SITE_ITEM_PK_SALES = 'Composite key linking to product dimension (site + item)',
    PROOF_INVOICE_DATE_FIRST = 'First date customer made a proof-eligible purchase',
    O_UNIQUE_ORDER_KEY = 'Unique order key for joining with digital order data'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    SALES_PK = ('identifier', 'primary_key', 'grain', 'unique'),
    S_SITE = ('identifier', 'foreign_key', 'dimension'),
    CUSTOMER_NO = ('identifier', 'foreign_key', 'dimension'),
    GCP_ACCOUNT_ID = ('identifier', 'foreign_key', 'integration'),
    ITEM_NO = ('identifier', 'foreign_key', 'dimension'),
    INVOICE_NO = ('identifier', 'document_number', 'transactional'),
    EXT_NET = ('metric', 'revenue', 'currency', 'kpi'),
    CASES = ('metric', 'quantity', 'inventory'),
    BOTTLES = ('metric', 'quantity', 'inventory'),
    ENTRY_ORIGIN = ('classification', 'channel', 'source'),
    POSTING_DATE = ('temporal', 'date', 'accounting'),
    QTY_DEC_EQU = ('metric', 'quantity', 'calculated'),
    SOURCE = ('classification', 'data_source', 'proof_flag'),
    SITE_ITEM_PK_SALES = ('identifier', 'composite_key', 'foreign_key'),
    PROOF_INVOICE_DATE_FIRST = ('temporal', 'milestone', 'customer_lifecycle'),
    O_UNIQUE_ORDER_KEY = ('identifier', 'join_key', 'digital_order')
  ),
  
  -- ==================== COLUMN TERMS ====================
  column_terms (
    SALES_PK = ('transaction_key', 'sales_line'),
    EXT_NET = ('net_sales', 'extended_amount'),
    CASES = ('cases_sold', 'case_quantity'),
    BOTTLES = ('bottles_sold', 'bottle_quantity'),
    POSTING_DATE = ('post_date', 'transaction_date'),
    SOURCE = ('source_indicator', 'eligibility_flag'),
    PROOF_INVOICE_DATE_FIRST = ('first_proof_date', 'first_transaction')
  ),
  
  -- ==================== ASSERTIONS (Critical - Blocking) ====================
  assertions (
    not_null(columns := (SALES_PK)),
    unique_values(columns := (SALES_PK)),
    not_null(columns := (CUSTOMER_NO, EXT_NET))
  ),
  
  -- ==================== PROFILES (Observation - Tracking) ====================
  profiles (
    SALES_PK,
    CUSTOMER_NO,
    ITEM_NO,
    EXT_NET,
    CASES,
    BOTTLES,
    SOURCE,
    POSTING_DATE,
    ENTRY_ORIGIN
  )
);

-- ============================================================================
-- GOLD LAYER: Sales
-- ============================================================================
-- Source: web_analytics_silver.SALES
-- JOINs: customer (proof_invoice_date_first), orders (o_unique_order_key)
-- ============================================================================

WITH ranked AS (
  SELECT
    -- ==================== PRIMARY KEY ====================
    S.SALES_PK,

    -- ==================== SITE INFO ====================
    S.SITE AS S_SITE,

    -- ==================== CUSTOMER INFO ====================
    COALESCE(NULLIF(TRIM(CAST(S.CUSTOMER_NO AS STRING)), ''), '0') AS CUSTOMER_NO,
    S.GCP_ACCOUNT_ID,

    -- ==================== PRODUCT INFO ====================
    S.ITEM_NO,

    -- ==================== INVOICE INFO ====================
    COALESCE(NULLIF(TRIM(CAST(S.INVOICE_NO AS STRING)), ''), '0') AS INVOICE_NO,

    -- ==================== FINANCIALS ====================
    COALESCE(s.ext_net, CAST(0 AS DECIMAL(18, 2))) AS ext_net,
    s.cases,
    s.bottles,

    -- ==================== ORIGIN ====================
    s.entry_origin,

    -- ==================== DATES ====================
    s.posting_date,

    -- ==================== QUANTITIES ====================
    s.qty_dec_equ,

    -- ==================== SOURCE (Proof/Non-proof) ====================
    s.source,

    -- ==================== SITE ITEM KEY ====================
    s.site_item_pk_sales,

    -- ==================== PROOF INVOICE DATE FIRST (from customer join) ====================
    c.first_posting_date_at_proof AS proof_invoice_date_first,

    -- ==================== UNIQUE ORDER KEY ====================
    o.o_unique_order_key,

    row_number() OVER (
      PARTITION BY s.sales_pk
      ORDER BY s.posting_date DESC NULLS LAST, s.last_modified_dt DESC NULLS LAST
    ) AS _rn

  FROM web_analytics_silver.SALES s
  JOIN (
  -- Get proof eligible customers with their first posting date
  SELECT DISTINCT 
    gcp_account_id, 
    first_posting_date_at_proof AS first_posting_date_at_proof
  FROM web_analytics_silver.CUSTOMER
  WHERE proof_of_eligible_acct = 'Y'
  ) c ON c.gcp_account_id = s.gcp_account_id
  LEFT JOIN (
  -- Build unique order key from orders
  SELECT DISTINCT 
    CONCAT(
      CAST(site_number AS STRING), '-', 
      CAST(customer_no AS STRING), '-', 
      UPPER(COALESCE(order_external_id, ''))
    ) AS o_unique_order_key,
    CONCAT(
      CAST(site_number AS STRING), '-', 
      CAST(customer_no AS STRING), '-', 
      CAST(item_no AS STRING), '-', 
      CAST(invoice_no AS STRING), '-', 
      CAST(invoice_line_no AS STRING)
    ) AS order_fk
  FROM web_analytics_silver.ORDERS
  ) o ON o.order_fk = s.sales_pk
)
SELECT
  sales_pk,
  s_site,
  customer_no,
  gcp_account_id,
  item_no,
  invoice_no,
  ext_net,
  cases,
  bottles,
  entry_origin,
  posting_date,
  qty_dec_equ,
  source,
  site_item_pk_sales,
  proof_invoice_date_first,
  o_unique_order_key
FROM ranked
WHERE _rn = 1
