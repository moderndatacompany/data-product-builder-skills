MODEL (
  name web_analytics_gold.PRODUCT,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [SITE_ITEM_PK_PRODUCT],
  description 'Gold layer product dimension providing alcohol product catalog with brand, classification, varietal information, and supplier details for sales analytics',
  tags ('gold', 'dimension', 'product', 'catalog', 'alcohol'),
  terms ('product', 'product_master', 'alcohol_products'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    SITE_ITEM_PK_PRODUCT = 'Unique composite primary key combining site and item number',
    SITE_NUMBER = 'Distribution site number where product is available',
    SITE_NAME = 'Name of the distribution site',
    PIM_PRODUCT_NAME = 'Product Information Management (PIM) standardized product name',
    ITEMNUMBER = 'Item number from inventory management system',
    BRAND_NAME = 'Brand name of the alcohol product (e.g., Jack Daniels, Grey Goose)',
    SUPPLIER = 'Supplier or distributor company name',
    CLASS = 'Primary product classification category (Wine, Spirits, Beer)',
    SUB_CLASS = 'Secondary product classification subcategory',
    VARIETAL = 'Wine varietal or spirit type (e.g., Chardonnay, Bourbon, IPA)',
    CORP_ITEM_PROD_CAT_NAME = 'Corporate-level product category name for reporting',
    ITEM_STATUS_DESCR = 'Current status of the product item (Active, Discontinued, etc.)'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    SITE_ITEM_PK_PRODUCT = ('identifier', 'primary_key', 'grain', 'composite_key'),
    SITE_NUMBER = ('identifier', 'foreign_key', 'dimension'),
    SITE_NAME = ('attribute', 'text', 'location'),
    PIM_PRODUCT_NAME = ('attribute', 'text', 'standardized', 'business_name'),
    ITEMNUMBER = ('identifier', 'business_key', 'source_system'),
    BRAND_NAME = ('attribute', 'text', 'hierarchical', 'alcohol'),
    SUPPLIER = ('attribute', 'text', 'vendor', 'supply_chain'),
    CLASS = ('classification', 'hierarchical', 'level1', 'alcohol'),
    SUB_CLASS = ('classification', 'hierarchical', 'level2', 'alcohol'),
    VARIETAL = ('classification', 'alcohol', 'product_type'),
    CORP_ITEM_PROD_CAT_NAME = ('classification', 'corporate', 'reporting'),
    ITEM_STATUS_DESCR = ('status', 'lifecycle', 'availability')
  ),
  
  -- ==================== COLUMN TERMS ====================
  column_terms (
    SITE_ITEM_PK_PRODUCT = ('composite_key', 'product_id'),
    PIM_PRODUCT_NAME = ('standard_name', 'product_name'),
    BRAND_NAME = ('brand'),
    CLASS = ('category', 'primary_classification'),
    VARIETAL = ('varietal', 'type'),
    SUPPLIER = ('supplier', 'name'),
    ITEM_STATUS_DESCR = ('status', 'state')
  ),
  
  -- ==================== ASSERTIONS (Critical - Blocking) ====================
  assertions (
    not_null(columns := (SITE_ITEM_PK_PRODUCT)),
    unique_values(columns := (SITE_ITEM_PK_PRODUCT)),
    not_null(columns := (ITEMNUMBER, SITE_NUMBER))
  ),
  
  -- ==================== PROFILES (Observation - Tracking) ====================
  profiles (
    SITE_ITEM_PK_PRODUCT,
    PIM_PRODUCT_NAME,
    BRAND_NAME,
    CLASS,
    SUB_CLASS,
    VARIETAL,
    ITEM_STATUS_DESCR
  )
);

-- ============================================================================
-- GOLD LAYER: Product
-- ============================================================================
-- Source: web_analytics_silver.PRODUCT
-- ============================================================================

WITH ranked AS (
  SELECT
    SITE_ITEM_PK_PRODUCT,
    SITE_NUMBER,
    SITE_NAME,
    PIM_PRODUCT_NAME,
    ITEMNUMBER,
    BRAND_NAME,
    SUPPLIER,
    CLASS,
    SUB_CLASS,
    VARIETAL,
    CORP_ITEM_PROD_CAT_NAME,
    ITEM_STATUS_DESCR,
    ROW_NUMBER() OVER (
      PARTITION BY SITE_ITEM_PK_PRODUCT
      ORDER BY LAST_MODIFIED_DT DESC NULLS LAST
    ) AS _RN
  FROM web_analytics_silver.PRODUCT
)
SELECT
  -- ==================== PRIMARY KEY ====================
  site_item_pk_product,

  -- ==================== SITE INFO ====================
  site_number,
  site_name,

  -- ==================== PRODUCT INFO ====================
  pim_product_name,
  itemnumber,

  -- ==================== BRAND & SUPPLIER ====================
  brand_name,
  supplier,

  -- ==================== CLASSIFICATION ====================
  class,
  sub_class,
  varietal,

  -- ==================== CATEGORY ====================
  corp_item_prod_cat_name,

  -- ==================== STATUS ====================
  item_status_descr
FROM ranked
WHERE _rn = 1
