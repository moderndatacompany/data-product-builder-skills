MODEL (
  name web_analytics_gold.WEB_HEARTBEAT,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [uuid],
  description 'Gold layer comprehensive web analytics fact table capturing all Adobe Analytics hits with enriched dimensions, device tracking, session management, product interactions, list recommendations, and customer journey metrics for digital platform analysis',
  tags ('gold', 'fact', 'web_analytics', 'digital', 'adobe_analytics', 'clickstream'),
  terms ('web_heartbeat', 'digital_interactions', 'hit_data', 'user_behavior'),
  
  -- ==================== COLUMN DESCRIPTIONS (Key Columns) ====================
  column_descriptions (
    uuid = 'Unique primary key for each hit combining visitor, visit, and page view identifiers (SHA256 hash)',
    hitid = 'Adobe Analytics hit identifier',
    visid_high = 'High bits of the visitor identifier for composite visitor ID',
    visid_low = 'Low bits of the visitor identifier for composite visitor ID',
    date_time = 'Timestamp of the hit event',
    visit_num = 'Sequential visit number for this visitor',
    visit_page_num = 'Page view number within this visit session',
    pagename = 'Name of the page viewed',
    page_url = 'Full URL of the page',
    page_type = 'Categorization of the page type',
    event_list = 'Comma-separated list of Adobe events fired on this hit',
    site_id = 'Site identifier from eVar1',
    account_unique_id = 'Unique account identifier from eVar14 linking to customer',
    search_keywords = 'Search keywords entered by user from eVar15',
    cart_id = 'Shopping cart identifier from eVar21',
    order_number = 'Order number from eVar24 when order is placed',
    digital_platform_raw = 'Raw digital platform value from eVar29 (App/Web)',
    digitalplatform = 'Cleaned digital platform indicator (App or Web)',
    operating_system = 'Operating system name from device detection',
    browser_name = 'Browser name from device detection',
    device_category = 'Device type category (Mobile App, Mobile Web, Tablet, Desktop)',
    sessionid = 'Derived session identifier combining visitor ID and visit number',
    visitorid = 'Derived visitor identifier for unique visitor tracking',
    unique_order_key = 'Composite order key for joining with transactional order data',
    site_item_key = 'Composite site-item key for product dimension lookup',
    product_id = 'Product identifier extracted from Adobe product list',
    list_algorithmic_type = 'Classification of product list as Algorithmic (ML recommendations) or Non-Algorithmic (manual lists)',
    list_type = 'Specific list type (Favorites, Ready to Reorder, Customers Like You, Previously Purchased, etc.)',
    list_sub_type = 'Sub-classification of list display context (List Page vs Other Page)',
    geo_city = 'Geographic city from IP geolocation',
    geo_country = 'Geographic country',
    geo_region = 'Geographic region/state',
    referrer = 'Referring URL for traffic source analysis',
    referrer_type_name = 'Referrer type description (Search Engine, Social, Direct, etc.)',
    max_visit_page_num_of_session = 'Maximum page number in this session for exit and bounce rate calculations'
  ),
  
  -- ==================== COLUMN TAGS (Key Columns) ====================
  column_tags (
    uuid = ('identifier', 'primary_key', 'grain', 'unique', 'hash'),
    hitid = ('identifier', 'adobe', 'hit'),
    visid_high = ('identifier', 'adobe', 'visitor'),
    visid_low = ('identifier', 'adobe', 'visitor'),
    date_time = ('temporal', 'timestamp', 'event'),
    visit_num = ('metric', 'sequence', 'session'),
    visit_page_num = ('metric', 'sequence', 'pageview'),
    sessionid = ('identifier', 'session', 'derived'),
    visitorid = ('identifier', 'visitor', 'derived'),
    account_unique_id = ('identifier', 'customer', 'foreign_key'),
    cart_id = ('identifier', 'shopping_cart'),
    product_id = ('identifier', 'product', 'foreign_key'),
    site_item_key = ('identifier', 'composite_key'),
    digitalplatform = ('classification', 'channel'),
    device_category = ('classification', 'device'),
    operating_system = ('classification', 'device'),
    page_type = ('classification', 'page_category'),
    list_algorithmic_type = ('classification', 'recommendation'),
    list_type = ('classification', 'feature'),
    event_list = ('attribute', 'adobe', 'events'),
    geo_region = ('geographic', 'location'),
    referrer_type_name = ('classification', 'traffic_source'),
    unique_order_key = ('identifier', 'join_key')
  ),
  
  -- ==================== COLUMN TERMS (Key Columns) ====================
  column_terms (
    uuid = ('hit_key', 'web_interaction'),
    sessionid = ('session_id', 'identifier'),
    visitorid = ('visitor_id', 'identifier'),
    account_unique_id = ('digital_id', 'unique_identifier'),
    unique_order_key = ('order_key', 'link_key'),
    list_algorithmic_type = ('type', 'algorithm_classification'),
    list_type = ('list_category', 'list_name'),
    digitalplatform = ('platform', 'app_or_web')
  ),
  
  -- ==================== ASSERTIONS (Critical - Blocking) ====================
  assertions (
    not_null(columns := (uuid, hitid)),
    unique_values(columns := (uuid)),
    not_null(columns := (date_time))
  ),
  
  -- ==================== PROFILES (Observation - Tracking) ====================
  profiles (
    uuid,
    hitid,
    date_time,
    digitalplatform,
    device_category,
    page_type,
    account_unique_id,
    sessionid,
    list_type,
    list_algorithmic_type,
    product_id,
    operating_system,
    browser_name,
    geo_region
  )
);

-- ============================================================================
-- GOLD LAYER: Web Heartbeat
-- ============================================================================
-- Source: web_analytics_silver.adobe_hits_enriched
-- Business Logic: All dimensions and derived columns for semantic layer
-- ============================================================================

SELECT 
  -- ==================== UUID (Primary Key) ====================
  -- Avoid global window (single-partition) UUID generation.
  sha2(
    concat_ws(
      '||',
      cast(h.hitid AS STRING),
      cast(h.date_time AS STRING),
      cast(h.visid_high AS STRING),
      cast(h.visid_low AS STRING),
      cast(h.visit_num AS STRING),
      cast(h.visit_page_num AS STRING)
    ),
    256
  ) AS uuid,
  
  -- ==================== ALL BASE COLUMNS ====================
  h.hitid,
  h.hitid_high,
  h.hitid_low,
  h.visid_high,
  h.visid_low,
  h.date_time,
  h.first_hit_time_gmt,
  h.hit_source,
  h.visit_num,
  h.visit_page_num,
  h.new_visit,
  h.pagename,
  h.page_url,
  h.page_type,
  h.page_event,
  h.channel,
  h.product_list,
  h.post_product_list AS unique_product_list,
  h.event_list,
  
  -- ==================== EVARS ====================
  h.evar1_site_id AS site_id,
  h.evar4_authentication_status AS authentication_status,
  h.evar14_account_unique_id AS account_unique_id,
  h.evar15_search_keywords AS search_keywords,
  h.evar15_search_keywords AS post_search_keywords,
  h.evar21_cart_id AS cart_id,
  h.evar24_order_number AS order_number,
  h.evar29_digital_platform AS digital_platform_raw,
  
  -- ==================== DEVICE INFO ====================
  h.browser_id,
  h.browser_name,
  h.os_id,
  h.os_name AS operating_system,
  h.resolution_id,
  h.language_id,
  h.language_name,
  
  -- ==================== GEO ====================
  h.geo_city,
  h.geo_country,
  h.geo_region,
  
  -- ==================== REFERRER ====================
  h.referrer,
  h.ref_type,
  h.referrer_type_name,
  
  -- ==================== SESSION ID (derived) ====================
  CONCAT(CAST(h.visid_high AS STRING), '-', CAST(h.visid_low AS STRING), '-', CAST(h.visit_num AS STRING)) AS sessionid,
  
  -- ==================== VISITOR ID (derived) ====================
  CONCAT(CAST(h.visid_high AS STRING), '-', CAST(h.visid_low AS STRING)) AS visitorid,
  
  -- ==================== ADOBE ECID (placeholder) ====================
  CONCAT(CAST(h.visid_high AS STRING), '-', CAST(h.visid_low AS STRING)) AS adobe_ecid,
  
  -- ==================== DIGITAL PLATFORM ====================
  CASE WHEN h.evar29_digital_platform = 'App' THEN 'App' ELSE 'Web' END AS digitalplatform,
  
  -- ==================== REVENUES ====================
  CAST(0 AS DECIMAL(15,2)) AS revenues,
  
  -- ==================== ATC REV ====================
  CASE 
    WHEN h.post_product_list LIKE '%|216=%' 
    THEN regexp_extract(h.post_product_list, '\\|216=([^|;]+)', 1)  
    ELSE '0' 
  END AS atc_rev,
  
  -- ==================== SITE ITEM KEY ====================
  CONCAT(CAST(h.evar1_site_id AS STRING), '-', 
         regexp_extract(COALESCE(h.product_list, ''), '^([^;,]+)', 1)) AS site_item_key,
  
  -- ==================== PRODUCT ID (extracted from product_list) ====================
  regexp_extract(COALESCE(h.product_list, ''), '^([^;,]+)', 1) AS product_id,
  
  -- ==================== QUANTITY (placeholder) ====================
  CAST(NULL AS INT) AS quantity,
  
  -- ==================== MAX VISIT PAGE NUM (for isexit/isbounce calculations) ====================
  MAX(h.visit_page_num) OVER (
    PARTITION BY h.visid_high, h.visid_low, h.visit_num
  ) AS max_visit_page_num_of_session,
  
  -- ==================== LIST ALGORITHMIC TYPE ====================
  CASE 
    WHEN (h.page_type = 'customerslikeyou' OR h.post_product_list LIKE '%125=Customers Like You%' 
        OR h.post_product_list LIKE '%125=customerslikeyou%' OR h.post_product_list LIKE '%125=CustomersLikeYou%'
        OR h.post_product_list LIKE '%284=Customers Like You%' OR h.post_product_list LIKE '%284=CustomersLikeYou%'
        OR h.post_product_list LIKE '%284=customerslikeyou%') 
    OR (h.page_type = 'ready2reorder' OR h.post_product_list LIKE '%125=ReadyToReorder%' OR h.post_product_list LIKE '%125=ready to reorder%'
        OR h.post_product_list LIKE '%125=ready2reorder%' OR h.post_product_list LIKE '%125=search panel:ready to reorder%'
        OR h.post_product_list LIKE '%284=ReadyToReorder%' OR h.post_product_list LIKE '%284=ready to reorder%'
        OR h.post_product_list LIKE '%284=ready2reorder%' OR h.post_product_list LIKE '%284=search panel:ready to reorder%')
    OR (h.post_product_list LIKE '%125=FrequentlyBoughtTogether%' OR h.post_product_list LIKE '%284=FrequentlyBoughtTogether%')
    THEN 'Algorithmic'
    WHEN ((h.page_type IN ('myfavoritespage', 'sgwssavedlistdetailspage') AND h.page_url LIKE '%favLists_%')
        OR h.post_product_list LIKE '%125=favorite%' OR h.post_product_list LIKE '%125=Favorite%'
        OR h.post_product_list LIKE '%284=favorites%' OR h.post_product_list LIKE '%284=Favorite%' OR h.page_url LIKE '%favLists_%')
    OR (h.page_type IN ('sgwssavedlistpage', 'sgwssavedlistdetailspage') OR h.post_product_list LIKE '%125=my lists%' OR h.post_product_list LIKE '%284=my lists%')
    OR (h.page_type = 'sgwspreviouslypurchased' OR h.post_product_list LIKE '%125=RecentlyPurchased%' 
        OR h.post_product_list LIKE '%125=previouslyPurchased%'
        OR h.post_product_list LIKE '%125=recently purchased%' OR h.post_product_list LIKE '%284=RecentlyPurchased%' 
        OR h.post_product_list LIKE '%284=previouslyPurchased%'
        OR h.post_product_list LIKE '%284=recently purchased%')
    THEN 'Non-Algorithmic' 
    ELSE NULL
  END AS list_algorithmic_type,
  
  -- ==================== LIST TYPE ====================
  CASE 
    WHEN (h.page_type IN ('myfavoritespage', 'sgwssavedlistdetailspage') AND h.page_url LIKE '%favLists_%')
        OR h.post_product_list LIKE '%125=favorite%' OR h.post_product_list LIKE '%125=Favorite%'
        OR h.post_product_list LIKE '%284=favorite%' OR h.post_product_list LIKE '%284=Favorite%' OR h.page_url LIKE '%favLists_%'
    THEN 'Favorites'
    WHEN h.page_type IN ('sgwssavedlistpage', 'sgwssavedlistdetailspage') OR h.post_product_list LIKE '%125=my lists%' OR h.post_product_list LIKE '%284=my lists%' 
    THEN 'My List'
    WHEN h.post_product_list LIKE '%125=FrequentlyBoughtTogether%' OR h.post_product_list LIKE '%284=FrequentlyBoughtTogether%' 
    THEN 'Frequently Bought Together'
    WHEN h.page_type = 'sgwspreviouslypurchased' OR h.post_product_list LIKE '%125=RecentlyPurchased%' 
        OR h.post_product_list LIKE '%125=previouslyPurchased%'
        OR h.post_product_list LIKE '%125=recently purchased%' OR h.post_product_list LIKE '%284=RecentlyPurchased%' 
        OR h.post_product_list LIKE '%284=previouslyPurchased%'
        OR h.post_product_list LIKE '%284=recently purchased%'
    THEN 'Previously Purchased'
    WHEN h.page_type = 'ready2reorder' OR h.post_product_list LIKE '%125=ReadyToReorder%' OR h.post_product_list LIKE '%125=ready to reorder%'
        OR h.post_product_list LIKE '%125=ready2reorder%' OR h.post_product_list LIKE '%125=search panel:ready to reorder%'
        OR h.post_product_list LIKE '%284=ReadyToReorder%' OR h.post_product_list LIKE '%284=ready to reorder%'
        OR h.post_product_list LIKE '%284=ready2reorder%' OR h.post_product_list LIKE '%284=search panel:ready to reorder%'
    THEN 'Ready to Reorder'
    WHEN h.page_type = 'customerslikeyou' OR h.post_product_list LIKE '%125=Customers Like You%' 
        OR h.post_product_list LIKE '%125=customerslikeyou%' OR h.post_product_list LIKE '%125=CustomersLikeYou%'
        OR h.post_product_list LIKE '%284=Customers Like You%' OR h.post_product_list LIKE '%284=CustomersLikeYou%'
        OR h.post_product_list LIKE '%284=customerslikeyou%'
    THEN 'Customers Like You'
    ELSE NULL
  END AS list_type,
  
  -- ==================== LIST SUB TYPE ====================
  CASE
    WHEN h.page_type IN ('sgwspreviouslypurchased', 'myfavoritespage', 'sgwssavedlistdetailspage', 'sgwssavedlistpage', 'ready2reorder', 'customerslikeyou') 
    THEN 'List Page'
    WHEN h.post_product_list LIKE '%125=previouslyPurchased%' OR h.post_product_list LIKE '%125=favorites%' OR h.post_product_list LIKE '%125=Favorite%' OR h.post_product_list LIKE '%125=RecentlyPurchased%'
        OR h.post_product_list LIKE '%125=ReadyToReorder%' OR h.post_product_list LIKE '%125=Customers Like You%' OR h.post_product_list LIKE '%125=ready2reorder%'
        OR h.post_product_list LIKE '%125=recently purchased%'
        OR h.post_product_list LIKE '%125=FrequentlyBoughtTogether%'
        OR h.post_product_list LIKE '%125=customerslikeyou%' OR h.post_product_list LIKE '%125=CustomersLikeYou%'
        OR h.post_product_list LIKE '%125=search panel:ready to reorder%'
        OR h.post_product_list LIKE '%125=ready to reorder%' OR h.post_product_list LIKE '%125=my lists%'
        OR h.post_product_list LIKE '%284=previouslyPurchased%' OR h.post_product_list LIKE '%284=favorites%' OR h.post_product_list LIKE '%284=Favorite%' OR h.post_product_list LIKE '%284=RecentlyPurchased%'
        OR h.post_product_list LIKE '%284=ReadyToReorder%' OR h.post_product_list LIKE '%284=Customers Like You%' OR h.post_product_list LIKE '%284=ready2reorder%'
        OR h.post_product_list LIKE '%284=recently purchased%'
        OR h.post_product_list LIKE '%284=FrequentlyBoughtTogether%' 
        OR h.post_product_list LIKE '%284=customerslikeyou%' OR h.post_product_list LIKE '%284=CustomersLikeYou%' OR h.post_product_list LIKE '%284=search panel:ready to reorder%'
        OR h.post_product_list LIKE '%284=ready to reorder%' OR h.post_product_list LIKE '%284=my lists%'
    THEN 'Other Page'
    ELSE NULL
  END AS list_sub_type,
  
  -- ==================== UNIQUE ORDER KEY ====================
  CONCAT(
    COALESCE(
      CAST(
        TRY_CAST(
          CASE
            WHEN length(h.evar14_account_unique_id) = 12 THEN substr(h.evar14_account_unique_id, 1, 2)
            WHEN length(h.evar14_account_unique_id) = 10 THEN substr(h.evar14_account_unique_id, 1, 3)
            WHEN length(h.evar14_account_unique_id) = 9 THEN substr(h.evar14_account_unique_id, 1, 2)
            WHEN length(h.evar14_account_unique_id) = 8 THEN substr(h.evar14_account_unique_id, 1, 1)
            ELSE NULL
          END AS INT
        ) AS STRING
      ),
      ''
    ),
    '-',
    COALESCE(
      CAST(
        TRY_CAST(
          CASE
            WHEN length(h.evar14_account_unique_id) = 12 THEN substr(h.evar14_account_unique_id, 3)
            WHEN length(h.evar14_account_unique_id) = 10 THEN substr(h.evar14_account_unique_id, -7)
            WHEN length(h.evar14_account_unique_id) = 9 THEN substr(h.evar14_account_unique_id, -7)
            WHEN length(h.evar14_account_unique_id) = 8 THEN substr(h.evar14_account_unique_id, -7)
            ELSE NULL
          END AS INT
        ) AS STRING
      ),
      ''
    ),
    '-',
    COALESCE(h.evar24_order_number, '')
  ) AS unique_order_key,
  
  -- ==================== DEVICE CATEGORY ====================
  CASE 
    WHEN h.os_name LIKE '%Mobile%' AND h.evar29_digital_platform = 'App' THEN 'Mobile App'
    WHEN h.os_name LIKE '%Mobile%' THEN 'Mobile Web'
    WHEN h.os_name LIKE '%Tablet%' THEN 'Tablet'
    ELSE 'Desktop'
  END AS device_category,
  
  -- ==================== PLACEHOLDER COLUMNS FOR EVENT TRACKING ====================
  CAST(NULL AS STRING) AS link_name,
  CAST(NULL AS STRING) AS error_type,
  CAST(NULL AS STRING) AS event_category,
  CAST(NULL AS STRING) AS event_action,
  CAST(NULL AS STRING) AS event_label,
  CAST(NULL AS STRING) AS event_name,
  CAST(NULL AS STRING) AS custom_link_name,
  CAST(NULL AS STRING) AS previous_page,
  CAST(NULL AS STRING) AS product_list_name,
  CAST(NULL AS STRING) AS component_name,
  CAST(NULL AS STRING) AS post_component_name,
  CAST(0 AS BIGINT) AS total_page_load_time,
  CAST(NULL AS STRING) AS campaign_name,
  CAST(NULL AS STRING) AS utm_content,
  
  -- ==================== TIME COLUMNS FOR MEASURES ====================
  h.date_time AS post_cust_hit_time_gmt,
  LEAD(h.date_time) OVER (PARTITION BY h.visid_high, h.visid_low, h.visit_num ORDER BY h.date_time) AS next_hit_cust_hit_time,
  LEAD(h.pagename) OVER (PARTITION BY h.visid_high, h.visid_low, h.visit_num ORDER BY h.date_time) AS next_hit_event_name,
  
  -- ==================== CAMPAIGN LAUNCH DATE (placeholder - would need SFMC join) ====================
  CAST(NULL AS TIMESTAMP) AS campaign_launchdate

FROM web_analytics_silver.adobe_hits_enriched h
