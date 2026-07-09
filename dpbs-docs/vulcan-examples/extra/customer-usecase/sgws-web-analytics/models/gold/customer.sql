MODEL (
  name web_analytics_gold.CUSTOMER,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [CUSTOMER_ID],
  description 'Gold layer customer dimension providing business-ready customer master data for alcohol distribution analytics, including customer demographics, site information, sales classifications, and digital engagement indicators',
  tags ('gold', 'dimension', 'customer', 'master_data', 'alcohol_distribution'),
  terms ('customer', 'customer_master', 'customer_profile'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    CUSTOMER_ID = 'Unique global customer identifier across all sites and systems',
    GCP_ACCOUNT_ID = 'Google Cloud Platform account identifier for customer integration',
    CUSTOMERNO = 'Legacy customer number from source system',
    SITE_ID = 'Site identifier where customer is primarily registered',
    ACCOUNTID = 'Account identifier for financial tracking',
    CUSTOMER_NAME = 'Official business name of the customer establishment',
    EMAIL = 'Primary email address for customer communications',
    STATUS = 'Customer account status (A=Active, I=Inactive)',
    IS_DELETED = 'Soft delete flag indicating if customer record is marked for deletion',
    SUBCHANNEL = 'Customer format type subcategory (e.g., Fine Dining, Liquor Store)',
    CHANNEL = 'High-level customer channel classification',
    PREMISE_CODE = 'ON/OFF premise code indicating where alcohol is consumed',
    STATE = 'US state where customer location is registered',
    SITE_NAME = 'Name of the distribution site serving this customer',
    SITE_STATE = 'US state where the serving distribution site is located',
    SITE_REGION = 'Geographic region of the serving distribution site (Northeast, Southeast, etc.)',
    IO_SALES = 'Inside/Outside sales organization description',
    FIRST_POSTING_DATE_AT_PROOF = 'Date of first proof-eligible transaction for this customer',
    CUSTOMER_PREMISE = 'Human-readable premise classification (On Premise, Off Premise, Any)',
    PROOF_OF_ELIGIBLE_ACCT = 'Flag indicating if customer is eligible for proof of purchase programs',
    SALES_BUCKET = 'Revenue tier classification based on rolling 12-month sales ($0-$25k, $25k-$50k, etc.)',
    HASMOBILEAPP = 'Boolean flag indicating if customer uses mobile app ordering',
    HASWEB = 'Boolean flag indicating if customer uses web portal ordering'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    CUSTOMER_ID = ('identifier', 'primary_key', 'grain', 'unique'),
    GCP_ACCOUNT_ID = ('identifier', 'foreign_key', 'integration'),
    CUSTOMERNO = ('identifier', 'legacy', 'source_system'),
    SITE_ID = ('identifier', 'foreign_key', 'dimension'),
    CUSTOMER_NAME = ('attribute', 'text', 'business_name'),
    EMAIL = ('contact', 'pii', 'communication'),
    STATUS = ('status', 'classification', 'active_flag'),
    IS_DELETED = ('status', 'soft_delete', 'filter'),
    SUBCHANNEL = ('classification', 'hierarchical', 'format'),
    CHANNEL = ('classification', 'hierarchical', 'high_level'),
    PREMISE_CODE = ('classification', 'business_rule', 'alcohol'),
    STATE = ('geographic', 'location', 'region'),
    SITE_REGION = ('geographic', 'aggregation', 'distribution'),
    SALES_BUCKET = ('classification', 'derived', 'revenue_tier'),
    CUSTOMER_PREMISE = ('classification', 'derived', 'alcohol_consumption'),
    PROOF_OF_ELIGIBLE_ACCT = ('business_rule', 'eligibility', 'program'),
    FIRST_POSTING_DATE_AT_PROOF = ('temporal', 'milestone', 'first_transaction'),
    HASMOBILEAPP = ('flag', 'digital', 'channel'),
    HASWEB = ('flag', 'digital', 'channel')
  ),
  
  -- ==================== COLUMN TERMS ====================
  column_terms (
    CUSTOMER_ID = ('unique_id', 'customer_key'),
    GCP_ACCOUNT_ID = ('gcp_account', 'external_id'),
    CUSTOMER_NAME = ('business_name', 'name'),
    PREMISE_CODE = ('premise_type', 'consumption_location'),
    SITE_REGION = ('region', 'sales_region'),
    SALES_BUCKET = ('revenue_tier', 'sales_classification'),
    CUSTOMER_PREMISE = ('premise_label', 'type'),
    PROOF_OF_ELIGIBLE_ACCT = ('proof_eligibility', 'program_status')
  ),
  
  -- ==================== ASSERTIONS (Critical - Blocking) ====================
  assertions (
    not_null(columns := (CUSTOMER_ID)),
    unique_values(columns := (CUSTOMER_ID)),
    not_null(columns := (CUSTOMER_NAME, SITE_REGION))
  ),
  
  -- ==================== PROFILES (Observation - Tracking) ====================
  profiles (
    CUSTOMER_ID,
    CUSTOMER_NAME,
    SITE_REGION,
    SALES_BUCKET,
    CUSTOMER_PREMISE,
    STATUS,
    PREMISE_CODE,
    HASMOBILEAPP,
    HASWEB
  )
);

-- ============================================================================
-- GOLD LAYER: Customer
-- ============================================================================
-- Source: web_analytics_silver.CUSTOMER
-- Filters: Active, not deleted, proof eligible customers only
-- ============================================================================

WITH ranked AS (
  SELECT
    c.*,
    ROW_NUMBER() OVER (
      PARTITION BY c.CUSTOMER_ID
      ORDER BY c.LAST_MODIFIED_DT DESC NULLS LAST
    ) AS _RN
  FROM web_analytics_silver.CUSTOMER c
  WHERE
    c.CUSTOMER_NO >= 0
    AND c.IS_DELETED = 'N'
    AND c.STATUS = 'A'
    AND c.PROOF_OF_ELIGIBLE_ACCT = 'Y'
    AND c.CUSTOMER_NAME IS NOT NULL
    AND c.SITE_REGION IS NOT NULL
)
SELECT
  -- ==================== PRIMARY KEY ====================
  c.CUSTOMER_ID,
  
  -- ==================== IDENTIFIERS ====================
  c.GCP_ACCOUNT_ID,
  CAST(c.CUSTOMER_NO AS STRING) AS CUSTOMERNO,
  c.SITE AS SITE_ID,
  CAST(c.ACCOUNT_ID AS STRING) AS ACCOUNTID,
  
  -- ==================== CUSTOMER INFO ====================
  c.CUSTOMER_NAME,
  c.EMAIL,
  c.STATUS,
  c.IS_DELETED,
  
  -- ==================== CLASSIFICATION ====================
  c.FORMAT_TYPE AS SUBCHANNEL,
  c.CHANNEL_DESCRIPTION AS CHANNEL,
  c.PREMISE_TYPE AS PREMISE_CODE,
  
  -- ==================== SITE INFO ====================
  c.STATE,
  c.SITE_NAME,
  c.SITE_STATE,
  c.SITE_REGION,
  
  -- ==================== IO SALES ====================
  c.RPT_SALES_ORG_DESC AS IO_SALES,
  
  -- ==================== DATES ====================
  c.FIRST_POSTING_DATE_AT_PROOF,
  
  -- ==================== CUSTOMER PREMISE ====================
  CASE
    WHEN c.PREMISE_CODE = 'ON' THEN 'On Premise'
    WHEN c.PREMISE_CODE = '10.' THEN 'On Premise'
    WHEN c.PREMISE_CODE = 'OFF' THEN 'Off Premise'
    WHEN c.PREMISE_CODE = '20.' THEN 'Off Premise'
    WHEN c.PREMISE_CODE = 'BOT' THEN 'Any'
    WHEN c.PREMISE_CODE = 'OTH' THEN 'Any'
    WHEN c.PREMISE_CODE IS NULL THEN 'Any'
    ELSE ''
  END AS CUSTOMER_PREMISE,
  
  -- ==================== PROOF ELIGIBILITY ====================
  c.PROOF_OF_ELIGIBLE_ACCT,
  
  -- ==================== SALES BUCKET ====================
  CASE
    WHEN c.R12_MONTHS_REVENUE BETWEEN 0 AND 25000 THEN '$0-$25k'
    WHEN c.R12_MONTHS_REVENUE BETWEEN 25000.01 AND 50000 THEN '$25k-$50k'
    WHEN c.R12_MONTHS_REVENUE BETWEEN 50000.01 AND 75000 THEN '$50k-$75k'
    WHEN c.R12_MONTHS_REVENUE BETWEEN 75000.01 AND 100000 THEN '$75k-$100k'
    WHEN c.R12_MONTHS_REVENUE BETWEEN 100000.01 AND 200000 THEN '$100k-$200k'
    WHEN c.R12_MONTHS_REVENUE BETWEEN 200000.01 AND 300000 THEN '$200k-$300k'
    WHEN c.R12_MONTHS_REVENUE BETWEEN 300000.01 AND 400000 THEN '$300k-$400k'
    WHEN c.R12_MONTHS_REVENUE BETWEEN 400000.01 AND 500000 THEN '$400k-$500k'
    WHEN c.R12_MONTHS_REVENUE > 500000.01 THEN '$500k+'
    ELSE NULL 
  END AS SALES_BUCKET,
  
  -- ==================== DIGITAL FLAGS (placeholder - derived in semantic layer) ====================
  FALSE AS HASMOBILEAPP,
  FALSE AS HASWEB

FROM ranked c
WHERE c._RN = 1
