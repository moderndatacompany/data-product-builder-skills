MODEL (
  name web_analytics_bronze.EVENT,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [EVENT_ID],
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    EVENT_ID = 'Event Id - identifier',
    EVENT_NAME = 'Event Name'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    EVENT_ID = ('identifier', 'fact'),
    EVENT_NAME = ('attribute', 'fact')
  )
);

SELECT 
  event_id::INTEGER AS EVENT_ID,
  event_name::VARCHAR AS EVENT_NAME
FROM web_analytics_seeds.EVENT;
