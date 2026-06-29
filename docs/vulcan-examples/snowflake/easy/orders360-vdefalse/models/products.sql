MODEL (
  name DEMODB.VDEFALSE.PRODUCTS,
  kind FULL,
  cron '@daily',
  grain PRODUCT_ID,
  tags ('dimension', 'product', 'master_data', 'catalog', 'inventory', 'vde_disabled'),
  terms ('product.catalog', 'inventory.product_dimension'),
  description 'Product dimension table with full refresh providing the canonical product catalog (category, brand, price, cost, stock, rating) for direct SQL consumption.',
  assertions (
    not_null(columns := (PRODUCT_ID, PRODUCT_NAME)),
    unique_values(columns := (PRODUCT_ID))
  ),
  column_descriptions (
    PRODUCT_ID      = 'Unique identifier for each product',
    PRODUCT_NAME    = 'Product name',
    CATEGORY        = 'Product category (Electronics, Home, Clothing, Sports, Food, Toys)',
    SUBCATEGORY     = 'Product subcategory',
    BRAND           = 'Product brand name',
    SKU             = 'Stock keeping unit code',
    PRICE           = 'Product selling price',
    COST            = 'Product cost price',
    RATING          = 'Product rating (1.0-5.0)',
    STOCK_QUANTITY  = 'Current stock quantity available',
    DISCONTINUED    = 'Whether the product is discontinued'
  ),
  column_tags (
    PRODUCT_ID      = ('identifier', 'primary_key', 'grain'),
    PRODUCT_NAME    = ('dimension', 'label'),
    CATEGORY        = ('dimension', 'classification', 'label'),
    SUBCATEGORY     = ('dimension', 'classification', 'label'),
    BRAND           = ('dimension', 'label'),
    SKU             = ('identifier', 'code'),
    PRICE           = ('measure', 'financial', 'price'),
    COST            = ('measure', 'financial', 'price'),
    RATING          = ('measure', 'metric', 'score'),
    STOCK_QUANTITY  = ('measure', 'metric', 'count'),
    DISCONTINUED    = ('dimension', 'flag', 'boolean')
  ),
  column_terms (
    PRODUCT_ID      = ('product.identifier', 'entity.product_id'),
    PRODUCT_NAME    = ('product.name', 'catalog.product_name'),
    CATEGORY        = ('product.category', 'classification.category'),
    SUBCATEGORY     = ('product.subcategory', 'classification.subcategory'),
    BRAND           = ('product.brand', 'catalog.brand'),
    SKU             = ('product.sku', 'inventory.sku'),
    PRICE           = ('product.price', 'pricing.selling_price'),
    COST            = ('product.cost', 'pricing.cost_price'),
    RATING          = ('product.rating', 'metric.customer_rating'),
    STOCK_QUANTITY  = ('product.stock', 'inventory.quantity'),
    DISCONTINUED    = ('product.discontinued', 'status.active_flag')
  )
);

SELECT
  PRODUCT_ID::VARCHAR AS PRODUCT_ID,
  PRODUCT_NAME::VARCHAR AS PRODUCT_NAME,
  CATEGORY::VARCHAR AS CATEGORY,
  SUBCATEGORY::VARCHAR AS SUBCATEGORY,
  BRAND::VARCHAR AS BRAND,
  SKU::VARCHAR AS SKU,
  PRICE::FLOAT AS PRICE,
  COST::FLOAT AS COST,
  RATING::FLOAT AS RATING,
  STOCK_QUANTITY::INTEGER AS STOCK_QUANTITY,
  DISCONTINUED::BOOLEAN AS DISCONTINUED
FROM VULCAN.RAW.PRODUCTS
