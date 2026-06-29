MODEL (
  name web_analytics_bronze.PLUGINS,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [PLUGIN_ID],
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    PLUGIN_ID = 'Plugin Id - identifier',
    PLUGIN_NAME = 'Plugin Name'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    PLUGIN_ID = ('identifier', 'fact'),
    PLUGIN_NAME = ('attribute', 'fact')
  )
);

SELECT 
  plugin_id::INTEGER AS PLUGIN_ID,
  plugin_name::VARCHAR AS PLUGIN_NAME
FROM web_analytics_seeds.PLUGINS;
