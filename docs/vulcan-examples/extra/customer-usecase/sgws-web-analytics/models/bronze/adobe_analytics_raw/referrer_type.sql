MODEL (
  name web_analytics_bronze.REFERRER_TYPE,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [REFERRER_TYPE_ID],
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    REFERRER_TYPE_ID = 'Referrer Type Id - identifier',
    REFERRER_TYPE_NAME = 'Referrer Type Name',
    REFERRER_TYPE_CATEGORY = 'Referrer Type Category'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    REFERRER_TYPE_ID = ('identifier', 'fact'),
    REFERRER_TYPE_NAME = ('attribute', 'fact'),
    REFERRER_TYPE_CATEGORY = ('attribute', 'fact')
  )
);

SELECT 
  referrer_type_id::INTEGER AS REFERRER_TYPE_ID,
  referrer_type_name::VARCHAR AS REFERRER_TYPE_NAME,
  referrer_type_category::VARCHAR AS REFERRER_TYPE_CATEGORY
FROM web_analytics_seeds.REFERRER_TYPE;
