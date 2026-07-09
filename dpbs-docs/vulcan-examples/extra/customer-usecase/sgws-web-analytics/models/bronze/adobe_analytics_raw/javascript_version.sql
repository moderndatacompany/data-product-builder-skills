MODEL (
  name web_analytics_bronze.JAVASCRIPT_VERSION,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [JAVASCRIPT_VERSION_ID],
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    JAVASCRIPT_VERSION_ID = 'Javascript Version Id - identifier',
    JAVASCRIPT_VERSION_DESC = 'Javascript Version Desc'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    JAVASCRIPT_VERSION_ID = ('identifier', 'fact'),
    JAVASCRIPT_VERSION_DESC = ('attribute', 'fact')
  )
);

SELECT 
  javascript_version_id::INTEGER AS JAVASCRIPT_VERSION_ID,
  javascript_version_name::VARCHAR AS JAVASCRIPT_VERSION_DESC
FROM web_analytics_seeds.JAVASCRIPT_VERSION;
