MODEL (
  name web_analytics_silver.ADOBE_HITS_NAMED,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [EVAR1_SITE_ID],
  description 'Silver layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('silver', 'transformed', 'cleaned', 'fact', 'web_analytics'),
  terms ('web_analytics')
);

-- ============================================================================
-- SILVER LAYER: Named Columns (Verified Positions)
-- ============================================================================
-- Source: BRONZE_ADOBE_ANALYTICS_RAW.HIT_DATA
-- All positions verified via vulcan fetchdf queries
-- ============================================================================

SELECT
  -- ==================== IDENTIFIERS ====================
  CAST(hitid_high AS BIGINT) AS HITID_HIGH,
  CAST(hitid_low AS BIGINT) AS HITID_LOW,
  CONCAT(CAST(hitid_high AS STRING), '-', CAST(hitid_low AS STRING)) AS HITID,
  CAST(visid_high AS BIGINT) AS VISID_HIGH,
  CAST(visid_low AS BIGINT) AS VISID_LOW,
  
  -- ==================== TIMESTAMPS ====================
  CAST(date_time AS TIMESTAMP) AS DATE_TIME,
  CAST(first_hit_time_gmt AS BIGINT) AS FIRST_HIT_TIME_GMT,
  CAST(hit_source AS SMALLINT) AS HIT_SOURCE,
  
  -- ==================== SESSION ====================
  CAST(visit_num AS INT) AS VISIT_NUM,
  CAST(visit_page_num AS INT) AS VISIT_PAGE_NUM,
  CAST(new_visit AS SMALLINT) AS NEW_VISIT,
  
  -- ==================== PAGE ====================
  pagename AS PAGENAME,
  page_url AS PAGE_URL,
  page_type AS PAGE_TYPE,
  CAST(page_event AS SMALLINT) AS PAGE_EVENT,
  channel AS CHANNEL,
  
  -- ==================== COMMERCE ====================
  product_list AS PRODUCT_LIST,
  post_product_list AS POST_PRODUCT_LIST,
  event_list AS EVENT_LIST,
  
  -- ==================== EVARS (Key Business Columns) ====================
  evar1 AS EVAR1_SITE_ID,
  evar4 AS EVAR4_AUTHENTICATION_STATUS,
  evar14 AS EVAR14_ACCOUNT_UNIQUE_ID,
  evar15 AS EVAR15_SEARCH_KEYWORDS,
  evar21 AS EVAR21_CART_ID,
  evar24 AS EVAR24_ORDER_NUMBER,
  evar29 AS EVAR29_DIGITAL_PLATFORM,
  
  -- ==================== DEVICE (IDs for lookup) ====================
  CAST(browser AS INT) AS BROWSER_ID,
  CAST(os AS INT) AS OS_ID,
  CAST(resolution AS INT) AS RESOLUTION_ID,
  CAST(language AS INT) AS LANGUAGE_ID,
  
  -- ==================== GEO ====================
  geo_city AS GEO_CITY,
  geo_country AS GEO_COUNTRY,
  geo_region AS GEO_REGION,
  
  -- ==================== MARKETING ====================
  referrer AS REFERRER,
  CAST(ref_type AS SMALLINT) AS REF_TYPE

FROM web_analytics_bronze.HIT_DATA
