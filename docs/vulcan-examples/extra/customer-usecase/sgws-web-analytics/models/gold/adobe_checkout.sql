MODEL (
  name web_analytics_gold.ADOBE_CHECKOUT,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [uuid],
  description 'Gold layer e-commerce checkout funnel fact table joining Add-to-Cart (ATC) events with Checkout completion events, tracking digital cart behavior, product selections, list types, and revenue attribution for web and mobile app channels',
  tags ('gold', 'fact', 'ecommerce', 'checkout_funnel', 'digital', 'adobe_analytics'),
  terms ('checkout', 'cart_conversion', 'ecommerce_funnel', 'checkout_tracking'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    uuid = 'Unique identifier for the ATC-to-Checkout match (SHA256 hash of composite key)',
    unique_key = 'Unique hit identifier for the Add-to-Cart event',
    date_time = 'Timestamp of the Add-to-Cart event',
    hitid = 'Adobe Analytics hit identifier',
    event_list = 'Comma-separated list of Adobe events fired (12=ATC)',
    pagename = 'Name of the page where ATC occurred',
    page_type = 'Categorization of the page type',
    account_unique_id = 'Unique account identifier for the customer',
    search_keywords = 'Search keywords if product was found via search',
    adobe_ecid = 'Adobe Experience Cloud ID for visitor tracking',
    cart_id = 'Shopping cart identifier linking ATC to checkout',
    event_category = 'Event category for custom event tracking',
    event_action = 'Event action description',
    event_label = 'Event label for additional context',
    event_name = 'Friendly name of the event',
    device_category = 'Device type category (Mobile App, Mobile Web, Tablet, Desktop)',
    operating_system = 'Operating system of the device',
    unique_product_list = 'Adobe product list string with product details',
    digital_platform = 'Platform indicator (App or Web)',
    product_id = 'Product identifier extracted from product list',
    site_item_key = 'Composite key linking to product dimension (site-item)',
    atc_quantity = 'Quantity added to cart in ATC event',
    list_algorithmic_type = 'Classification of product list as Algorithmic (recommendations) or Non-Algorithmic (manual lists)',
    list_type = 'Specific list type (Favorites, Ready to Reorder, Customers Like You, Previously Purchased, etc.)',
    list_sub_type = 'Sub-classification of list display (List Page vs Other Page)',
    site_id = 'Site identifier from Adobe eVar1',
    c_order_number = 'Order number from checkout completion event',
    c_event_list = 'Event list from checkout event',
    c_quantity = 'Quantity at checkout completion',
    revenue = 'Total revenue from checkout event',
    actual_rev = 'Actual attributed revenue (min of ATC quantity vs checkout quantity)',
    unique_order_key = 'Unique order key for joining with transactional order data',
    page_type_updated = 'Cleaned and standardized page type'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    uuid = ('identifier', 'primary_key', 'grain', 'unique', 'hash'),
    unique_key = ('identifier', 'atc_event', 'adobe'),
    hitid = ('identifier', 'adobe', 'hit'),
    date_time = ('temporal', 'timestamp', 'event'),
    account_unique_id = ('identifier', 'customer', 'foreign_key'),
    adobe_ecid = ('identifier', 'adobe', 'visitor', 'integration'),
    cart_id = ('identifier', 'shopping_cart', 'session'),
    product_id = ('identifier', 'product', 'foreign_key'),
    site_item_key = ('identifier', 'composite_key', 'foreign_key'),
    device_category = ('classification', 'device', 'channel'),
    operating_system = ('classification', 'device', 'technology'),
    digital_platform = ('classification', 'channel', 'app_web'),
    list_algorithmic_type = ('classification', 'recommendation', 'algorithm'),
    list_type = ('classification', 'feature', 'list_category'),
    list_sub_type = ('classification', 'feature', 'page_context'),
    atc_quantity = ('metric', 'quantity', 'cart'),
    c_quantity = ('metric', 'quantity', 'checkout'),
    revenue = ('metric', 'revenue', 'currency', 'kpi'),
    actual_rev = ('metric', 'revenue', 'currency', 'calculated', 'attributed'),
    unique_order_key = ('identifier', 'join_key', 'integration'),
    c_order_number = ('identifier', 'order_number', 'checkout'),
    page_type = ('classification', 'page_category'),
    page_type_updated = ('classification', 'page_category', 'cleaned')
  ),
  
  -- ==================== COLUMN TERMS ====================
  column_terms (
    uuid = ('funnel_key', 'atc_checkout_match'),
    cart_id = ('cart_id', 'shopping_cart'),
    actual_rev = ('attributed', 'conversion_revenue'),
    list_algorithmic_type = ('type', 'algorithm_classification'),
    list_type = ('list_category', 'list_name'),
    digital_platform = ('platform', 'app_or_web'),
    unique_order_key = ('order_key', 'link_key')
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
    digital_platform,
    cart_id,
    account_unique_id,
    product_id,
    list_type,
    list_algorithmic_type,
    device_category,
    actual_rev,
    c_order_number
  )
);

-- ============================================================================
-- GOLD LAYER: Adobe Checkout
-- ============================================================================
-- Source: web_analytics_silver.adobe_hits_enriched
-- Logic: Join ATC (event 12) with Checkout (event 1) by cart_id and product_id
-- ============================================================================

WITH checkout AS (
  SELECT
    COALESCE(
      evar21_cart_id,
      CONCAT(CAST(visid_high AS STRING), '-', CAST(visid_low AS STRING), '-', CAST(visit_num AS STRING))
    ) AS c_cart_id,
    regexp_extract(COALESCE(product_list, ''), '^([^;,]+)', 1) AS c_product_id,
    hitid AS c_unique_key, 
    date_time AS c_date_time,
    page_type AS c_page_type,
    event_list AS c_event_list,
    COALESCE(
      evar14_account_unique_id,
      CONCAT(CAST(visid_high AS STRING), '-', CAST(visid_low AS STRING))
    ) AS c_account_unique_id,
    os_name AS c_operating_system, 
    CASE WHEN evar29_digital_platform = 'App' THEN 'App' ELSE 'Web' END AS c_digital_platform, 
    post_product_list AS c_unique_product_list,
    CAST(0 AS DECIMAL(15, 2)) AS c_revenue,
    CAST(0 AS DECIMAL(15, 2)) AS c_quantity,
    CAST(0 AS DECIMAL(15, 2)) AS single_revenue,
    regexp_extract(post_product_list, '118=([^|;]+)', 1) AS c_evar18,
    evar24_order_number AS c_order_number
  FROM web_analytics_silver.adobe_hits_enriched
  WHERE event_list LIKE '%1%'
),

atc AS (
  SELECT
    hitid AS unique_key,
    date_time,
    hitid,
    event_list,
    pagename,
    page_type,
    COALESCE(
      evar14_account_unique_id,
      CONCAT(CAST(visid_high AS STRING), '-', CAST(visid_low AS STRING))
    ) AS account_unique_id,
    evar15_search_keywords AS search_keywords,
    CONCAT(CAST(visid_high AS STRING), '-', CAST(visid_low AS STRING)) AS adobe_ecid,
    COALESCE(
      evar21_cart_id,
      CONCAT(CAST(visid_high AS STRING), '-', CAST(visid_low AS STRING), '-', CAST(visit_num AS STRING))
    ) AS cart_id,
    CAST(NULL AS STRING) AS event_category,
    CAST(NULL AS STRING) AS event_action,
    CAST(NULL AS STRING) AS event_label,
    CAST(NULL AS STRING) AS event_name,
    CASE 
      WHEN os_name LIKE '%Mobile%' AND evar29_digital_platform = 'App' THEN 'Mobile App'
      WHEN os_name LIKE '%Mobile%' THEN 'Mobile Web'
      WHEN os_name LIKE '%Tablet%' THEN 'Tablet'
      ELSE 'Desktop'
    END AS device_category,
    os_name AS operating_system,
    post_product_list AS unique_product_list,
    CASE WHEN evar29_digital_platform = 'App' THEN 'App' ELSE 'Web' END AS digital_platform,
    regexp_extract(COALESCE(product_list, ''), '^([^;,]+)', 1) AS product_id,
    CONCAT(CAST(evar1_site_id AS STRING), '-', regexp_extract(COALESCE(product_list, ''), '^([^;,]+)', 1)) AS site_item_key,
    CAST(0 AS DOUBLE) AS atc_quantity,
    regexp_extract(post_product_list, '118=([^|;]+)', 1) AS evar18,
    page_url,
    evar1_site_id AS site_id,
    
    -- ==================== LIST ALGORITHMIC TYPE ====================
    CASE 
      WHEN (page_type = 'customerslikeyou' OR post_product_list LIKE '%125=Customers Like You%' 
          OR post_product_list LIKE '%125=customerslikeyou%' OR post_product_list LIKE '%125=CustomersLikeYou%'
          OR post_product_list LIKE '%284=Customers Like You%' OR post_product_list LIKE '%284=CustomersLikeYou%'
          OR post_product_list LIKE '%284=customerslikeyou%')
      OR (page_type = 'ready2reorder' OR post_product_list LIKE '%125=ReadyToReorder%' OR post_product_list LIKE '%125=ready to reorder%'
          OR post_product_list LIKE '%125=ready2reorder%' OR post_product_list LIKE '%125=search panel:ready to reorder%'
          OR post_product_list LIKE '%284=ReadyToReorder%' OR post_product_list LIKE '%284=ready to reorder%'
          OR post_product_list LIKE '%284=ready2reorder%' OR post_product_list LIKE '%284=search panel:ready to reorder%')
      OR (post_product_list LIKE '%125=FrequentlyBoughtTogether%' OR post_product_list LIKE '%284=FrequentlyBoughtTogether%')
      THEN 'Algorithmic'
      WHEN ((page_type IN ('myfavoritespage', 'sgwssavedlistdetailspage') AND page_url LIKE '%favLists_%')
          OR post_product_list LIKE '%125=favorite%' OR post_product_list LIKE '%125=Favorite%'
          OR post_product_list LIKE '%284=favorites%' OR post_product_list LIKE '%284=Favorite%' OR page_url LIKE '%favLists_%')
      OR (page_type IN ('sgwssavedlistpage', 'sgwssavedlistdetailspage') OR post_product_list LIKE '%125=my lists%' OR post_product_list LIKE '%284=my lists%')
      OR (page_type = 'sgwspreviouslypurchased' OR post_product_list LIKE '%125=RecentlyPurchased%' 
          OR post_product_list LIKE '%125=previouslyPurchased%'
          OR post_product_list LIKE '%125=recently purchased%' OR post_product_list LIKE '%284=RecentlyPurchased%' 
          OR post_product_list LIKE '%284=previouslyPurchased%'
          OR post_product_list LIKE '%284=recently purchased%')
      THEN 'Non-Algorithmic' 
      ELSE NULL
    END AS list_algorithmic_type,
    
    -- ==================== LIST TYPE ====================
    CASE 
      WHEN (page_type IN ('myfavoritespage', 'sgwssavedlistdetailspage') AND page_url LIKE '%favLists_%')
          OR post_product_list LIKE '%125=favorite%' OR post_product_list LIKE '%125=Favorite%'
          OR post_product_list LIKE '%284=favorite%' OR post_product_list LIKE '%284=Favorite%' OR page_url LIKE '%favLists_%'
      THEN 'Favorites'
      WHEN page_type IN ('sgwssavedlistpage', 'sgwssavedlistdetailspage') OR post_product_list LIKE '%125=my lists%' OR post_product_list LIKE '%284=my lists%' 
      THEN 'My List'
      WHEN post_product_list LIKE '%125=FrequentlyBoughtTogether%' OR post_product_list LIKE '%284=FrequentlyBoughtTogether%' 
      THEN 'Frequently Bought Together'
      WHEN page_type = 'sgwspreviouslypurchased' OR post_product_list LIKE '%125=RecentlyPurchased%' 
          OR post_product_list LIKE '%125=previouslyPurchased%'
          OR post_product_list LIKE '%125=recently purchased%' OR post_product_list LIKE '%284=RecentlyPurchased%' 
          OR post_product_list LIKE '%284=previouslyPurchased%'
          OR post_product_list LIKE '%284=recently purchased%'
      THEN 'Previously Purchased'
      WHEN page_type = 'ready2reorder' OR post_product_list LIKE '%125=ReadyToReorder%' OR post_product_list LIKE '%125=ready to reorder%'
          OR post_product_list LIKE '%125=ready2reorder%' OR post_product_list LIKE '%125=search panel:ready to reorder%'
          OR post_product_list LIKE '%284=ReadyToReorder%' OR post_product_list LIKE '%284=ready to reorder%'
          OR post_product_list LIKE '%284=ready2reorder%' OR post_product_list LIKE '%284=search panel:ready to reorder%'
      THEN 'Ready to Reorder'
      WHEN page_type = 'customerslikeyou' OR post_product_list LIKE '%125=Customers Like You%' 
          OR post_product_list LIKE '%125=customerslikeyou%' OR post_product_list LIKE '%125=CustomersLikeYou%'
          OR post_product_list LIKE '%284=Customers Like You%' OR post_product_list LIKE '%284=CustomersLikeYou%'
          OR post_product_list LIKE '%284=customerslikeyou%'
      THEN 'Customers Like You'
      ELSE NULL
    END AS list_type,
    
    -- ==================== LIST SUB TYPE ====================
    CASE
      WHEN page_type IN ('sgwspreviouslypurchased', 'myfavoritespage', 'sgwssavedlistdetailspage', 'sgwssavedlistpage', 'ready2reorder', 'customerslikeyou') 
      THEN 'List Page'
      WHEN post_product_list LIKE '%125=previouslyPurchased%' OR post_product_list LIKE '%125=favorites%' OR post_product_list LIKE '%125=Favorite%' OR post_product_list LIKE '%125=RecentlyPurchased%'
          OR post_product_list LIKE '%125=ReadyToReorder%' OR post_product_list LIKE '%125=Customers Like You%' OR post_product_list LIKE '%125=ready2reorder%'
          OR post_product_list LIKE '%125=recently purchased%'
          OR post_product_list LIKE '%125=FrequentlyBoughtTogether%'
          OR post_product_list LIKE '%125=customerslikeyou%' OR post_product_list LIKE '%125=CustomersLikeYou%'
          OR post_product_list LIKE '%125=search panel:ready to reorder%'
          OR post_product_list LIKE '%125=ready to reorder%' OR post_product_list LIKE '%125=my lists%'
          OR post_product_list LIKE '%284=previouslyPurchased%' OR post_product_list LIKE '%284=favorites%' OR post_product_list LIKE '%284=Favorite%' OR post_product_list LIKE '%284=RecentlyPurchased%'
          OR post_product_list LIKE '%284=ReadyToReorder%' OR post_product_list LIKE '%284=Customers Like You%' OR post_product_list LIKE '%284=ready2reorder%'
          OR post_product_list LIKE '%284=recently purchased%'
          OR post_product_list LIKE '%284=FrequentlyBoughtTogether%' 
          OR post_product_list LIKE '%284=customerslikeyou%' OR post_product_list LIKE '%284=CustomersLikeYou%' OR post_product_list LIKE '%284=search panel:ready to reorder%'
          OR post_product_list LIKE '%284=ready to reorder%' OR post_product_list LIKE '%284=my lists%'
      THEN 'Other Page'
      ELSE NULL
    END AS list_sub_type
    
  FROM web_analytics_silver.adobe_hits_enriched
  WHERE event_list LIKE '%12%'
)

SELECT 
  -- ==================== UUID (Primary Key) ====================
  -- Avoid global window (single-partition) UUID generation.
  sha2(
    concat_ws(
      '||',
      cast(a.unique_key AS STRING),
      cast(a.cart_id AS STRING),
      cast(a.product_id AS STRING),
      cast(c.c_unique_key AS STRING)
    ),
    256
  ) AS uuid,
  
  -- ==================== ATC DATA ====================
  a.unique_key,
  a.date_time,
  a.hitid,
  a.event_list,
  a.pagename,
  a.page_type,
  a.account_unique_id,
  a.search_keywords,
  a.adobe_ecid,
  a.cart_id,
  a.event_category,
  a.event_action,
  a.event_label,
  a.event_name,
  a.device_category,
  a.operating_system,
  a.unique_product_list,
  a.digital_platform,
  a.product_id,
  a.site_item_key,
  a.atc_quantity,
  a.list_algorithmic_type,
  a.list_type,
  a.list_sub_type,
  a.site_id,
  
  -- ==================== CHECKOUT DATA ====================
  c.c_order_number AS c_order_number,
  c.c_event_list,
  c.c_quantity,
  c.c_revenue AS revenue,
  
  -- ==================== ACTUAL REVENUE CALCULATION ====================
  CASE 
    WHEN a.atc_quantity <= c.c_quantity THEN c.single_revenue * a.atc_quantity 
    ELSE c.c_revenue 
  END AS actual_rev,
  
  -- ==================== UNIQUE ORDER KEY ====================
  CONCAT(
    CAST(
      CAST(
        CASE
          WHEN length(a.account_unique_id) = 12 THEN substr(a.account_unique_id, 1, 2)
          WHEN length(a.account_unique_id) = 10 THEN substr(a.account_unique_id, 1, 3)
          WHEN length(a.account_unique_id) = 9 THEN substr(a.account_unique_id, 1, 2)
          WHEN length(a.account_unique_id) = 8 THEN substr(a.account_unique_id, 1, 1)
          ELSE NULL
        END AS INT
      ) AS STRING
    ),
    '-',
    CAST(
      CAST(
        CASE
          WHEN length(a.account_unique_id) = 12 THEN substr(a.account_unique_id, 3)
          WHEN length(a.account_unique_id) = 10 THEN substr(a.account_unique_id, -7)
          WHEN length(a.account_unique_id) = 9 THEN substr(a.account_unique_id, -7)
          WHEN length(a.account_unique_id) = 8 THEN substr(a.account_unique_id, -7)
          ELSE NULL
        END AS INT
      ) AS STRING
    ),
    '-',
    COALESCE(c.c_order_number, '')
  ) AS unique_order_key,
  
  -- ==================== PAGE TYPE UPDATED ====================
  CASE 
    WHEN a.page_type LIKE '%proof by southern%' THEN 'Brand Details Page'
    WHEN a.page_type LIKE '%| proof southern%' THEN 'Brand Details Page'
    ELSE COALESCE(a.page_type, 'uncategorized pages')
  END AS page_type_updated

FROM atc a
JOIN checkout c 
  ON a.cart_id = c.c_cart_id 
  AND a.product_id = c.c_product_id 
  AND a.evar18 = c.c_evar18
