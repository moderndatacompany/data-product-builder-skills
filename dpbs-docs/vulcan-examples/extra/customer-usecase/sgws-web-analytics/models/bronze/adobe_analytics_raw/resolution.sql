MODEL (
  name web_analytics_bronze.RESOLUTION,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [RESOLUTION_ID],
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    RESOLUTION_ID = 'Resolution Id - identifier',
    RESOLUTION_DESC = 'Resolution Desc'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    RESOLUTION_ID = ('identifier', 'fact'),
    RESOLUTION_DESC = ('attribute', 'fact')
  )
);

SELECT 
  resolution_id::INTEGER AS RESOLUTION_ID,
  resolution_name::VARCHAR AS RESOLUTION_DESC
FROM web_analytics_seeds.RESOLUTION;
