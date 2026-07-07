MODEL (
  name web_analytics_bronze.BROWSER_TYPE,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [BROWSER_TYPE_ID],
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    BROWSER_TYPE_ID = 'Browser Type Id - identifier',
    BROWSER_TYPE_NAME = 'Browser Type Name'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    BROWSER_TYPE_ID = ('identifier', 'fact'),
    BROWSER_TYPE_NAME = ('attribute', 'fact')
  )
);

-- Reference seed and rename columns
SELECT 
  browser_type_id::INTEGER AS BROWSER_TYPE_ID,
  browser_type_name::VARCHAR AS BROWSER_TYPE_NAME
FROM web_analytics_seeds.BROWSER_TYPE;
