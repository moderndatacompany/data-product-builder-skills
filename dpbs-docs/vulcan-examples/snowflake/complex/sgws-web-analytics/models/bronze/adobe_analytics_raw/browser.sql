MODEL (
  name web_analytics_bronze.BROWSER,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [BROWSER_ID],
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    BROWSER_ID = 'Browser Id - identifier',
    BROWSER_NAME = 'Browser Name'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    BROWSER_ID = ('identifier', 'fact'),
    BROWSER_NAME = ('attribute', 'fact')
  )
);

SELECT 
  browser_id::INTEGER AS BROWSER_ID,
  browser_name::VARCHAR AS BROWSER_NAME
FROM web_analytics_seeds.BROWSER;
