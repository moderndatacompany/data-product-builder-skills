MODEL (
  name web_analytics_bronze.CONNECTION_TYPE,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [CONNECTION_TYPE_ID],
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    CONNECTION_TYPE_ID = 'Connection Type Id - identifier',
    CONNECTION_TYPE_NAME = 'Connection Type Name'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    CONNECTION_TYPE_ID = ('identifier', 'fact'),
    CONNECTION_TYPE_NAME = ('attribute', 'fact')
  )
);

SELECT 
  connection_type_id::INTEGER AS CONNECTION_TYPE_ID,
  connection_type_name::VARCHAR AS CONNECTION_TYPE_NAME
FROM web_analytics_seeds.CONNECTION_TYPE;
