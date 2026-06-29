MODEL (
  name web_analytics_bronze.OPERATING_SYSTEMS,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [OS_ID],
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    OS_ID = 'Os Id - identifier',
    OS_NAME = 'Os Name'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    OS_ID = ('identifier', 'fact'),
    OS_NAME = ('attribute', 'fact')
  )
);

SELECT 
  os_id::INTEGER AS OS_ID,
  os_name::VARCHAR AS OS_NAME
FROM web_analytics_seeds.OPERATING_SYSTEMS;
