MODEL (
  name web_analytics_bronze.COLOR_DEPTH,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [COLOR_DEPTH_ID],
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    COLOR_DEPTH_ID = 'Color Depth Id - identifier',
    COLOR_DEPTH_DESC = 'Color Depth Desc'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    COLOR_DEPTH_ID = ('identifier', 'fact'),
    COLOR_DEPTH_DESC = ('attribute', 'fact')
  )
);

SELECT 
  color_depth_id::INTEGER AS COLOR_DEPTH_ID,
  color_depth_name::VARCHAR AS COLOR_DEPTH_DESC
FROM web_analytics_seeds.COLOR_DEPTH;
