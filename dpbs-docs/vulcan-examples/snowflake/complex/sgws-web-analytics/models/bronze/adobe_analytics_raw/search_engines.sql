MODEL (
  name web_analytics_bronze.SEARCH_ENGINES,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [SEARCH_ENGINE_ID],
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    SEARCH_ENGINE_ID = 'Search Engine Id - identifier',
    SEARCH_ENGINE_NAME = 'Search Engine Name'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    SEARCH_ENGINE_ID = ('identifier', 'fact'),
    SEARCH_ENGINE_NAME = ('attribute', 'fact')
  )
);

SELECT 
  search_engine_id::INTEGER AS SEARCH_ENGINE_ID,
  search_engine_name::VARCHAR AS SEARCH_ENGINE_NAME
FROM web_analytics_seeds.SEARCH_ENGINES;
