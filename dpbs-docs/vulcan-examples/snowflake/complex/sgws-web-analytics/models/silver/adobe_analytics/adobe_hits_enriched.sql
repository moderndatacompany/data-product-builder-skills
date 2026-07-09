MODEL (
  name web_analytics_silver.ADOBE_HITS_ENRICHED,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [EVAR1_SITE_ID],
  description 'Silver layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('silver', 'transformed', 'cleaned', 'fact', 'web_analytics'),
  terms ('web_analytics'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    HITID_HIGH = 'Hitid High',
    HITID_LOW = 'Hitid Low',
    HITID = 'Hitid',
    VISID_HIGH = 'Visid High',
    VISID_LOW = 'Visid Low',
    DATE_TIME = 'Date Time',
    FIRST_HIT_TIME_GMT = 'First Hit Time Gmt',
    HIT_SOURCE = 'Hit Source',
    VISIT_NUM = 'Visit Num',
    VISIT_PAGE_NUM = 'Visit Page Num',
    NEW_VISIT = 'New Visit',
    PAGENAME = 'Pagename',
    PAGE_URL = 'Page Url',
    PAGE_TYPE = 'Page Type',
    PAGE_EVENT = 'Page Event'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    HITID_HIGH = ('attribute', 'fact'),
    HITID_LOW = ('attribute', 'fact'),
    HITID = ('attribute', 'fact'),
    VISID_HIGH = ('attribute', 'fact'),
    VISID_LOW = ('attribute', 'fact'),
    DATE_TIME = ('attribute', 'fact'),
    FIRST_HIT_TIME_GMT = ('attribute', 'fact'),
    HIT_SOURCE = ('attribute', 'fact'),
    VISIT_NUM = ('attribute', 'fact'),
    VISIT_PAGE_NUM = ('attribute', 'fact'),
    NEW_VISIT = ('attribute', 'fact'),
    PAGENAME = ('attribute', 'fact'),
    PAGE_URL = ('attribute', 'fact'),
    PAGE_TYPE = ('attribute', 'fact'),
    PAGE_EVENT = ('attribute', 'fact')
  )
);

-- ============================================================================
-- SILVER LAYER: Enriched Adobe Hits
-- ============================================================================
-- Source: web_analytics_silver.ADOBE_HITS_NAMED
-- Joins: browser, operating_systems, languages, referrer_type
-- ============================================================================

SELECT
  -- ==================== IDENTIFIERS ====================
  H.HITID_HIGH,
  H.HITID_LOW,
  H.HITID,
  H.VISID_HIGH,
  H.VISID_LOW,
  
  -- ==================== TIMESTAMPS ====================
  H.DATE_TIME,
  H.FIRST_HIT_TIME_GMT,
  H.HIT_SOURCE,
  
  -- ==================== SESSION ====================
  H.VISIT_NUM,
  H.VISIT_PAGE_NUM,
  H.NEW_VISIT,
  
  -- ==================== PAGE ====================
  H.PAGENAME,
  H.PAGE_URL,
  H.PAGE_TYPE,
  H.PAGE_EVENT,
  H.CHANNEL,
  
  -- ==================== COMMERCE ====================
  H.PRODUCT_LIST,
  H.POST_PRODUCT_LIST,
  H.EVENT_LIST,
  
  -- ==================== EVARS (Business Columns) ====================
  H.EVAR1_SITE_ID,
  H.EVAR4_AUTHENTICATION_STATUS,
  H.EVAR14_ACCOUNT_UNIQUE_ID,
  H.EVAR15_SEARCH_KEYWORDS,
  H.EVAR21_CART_ID,
  H.EVAR24_ORDER_NUMBER,
  H.EVAR29_DIGITAL_PLATFORM,
  
  -- ==================== DEVICE (IDs + Names from Lookups) ====================
  H.BROWSER_ID,
  B.BROWSER_NAME,
  H.OS_ID,
  OS.OS_NAME,
  H.RESOLUTION_ID,
  H.LANGUAGE_ID,
  L.LANGUAGE_NAME,
  
  -- ==================== GEO ====================
  H.GEO_CITY,
  H.GEO_COUNTRY,
  H.GEO_REGION,
  
  -- ==================== MARKETING (ID + Name from Lookup) ====================
  H.REFERRER,
  H.REF_TYPE,
  R.REFERRER_TYPE_NAME

FROM web_analytics_silver.ADOBE_HITS_NAMED H

-- Join browser lookup
LEFT JOIN web_analytics_bronze.BROWSER B
  ON H.BROWSER_ID = B.BROWSER_ID

-- Join operating systems lookup
LEFT JOIN web_analytics_bronze.OPERATING_SYSTEMS OS
  ON H.OS_ID = OS.OS_ID

-- Join languages lookup
LEFT JOIN web_analytics_bronze.LANGUAGES L
  ON H.LANGUAGE_ID = L.LANGUAGE_ID

-- Join referrer type lookup
LEFT JOIN web_analytics_bronze.REFERRER_TYPE R
  ON H.REF_TYPE = R.REFERRER_TYPE_ID
