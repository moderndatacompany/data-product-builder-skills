MODEL (
  name web_analytics_bronze.LANGUAGES,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [LANGUAGE_ID],
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    LANGUAGE_ID = 'Language Id - identifier',
    LANGUAGE_NAME = 'Language Name'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    LANGUAGE_ID = ('identifier', 'fact'),
    LANGUAGE_NAME = ('attribute', 'fact')
  )
);

SELECT 
  language_id::INTEGER AS LANGUAGE_ID,
  language_name::VARCHAR AS LANGUAGE_NAME
FROM web_analytics_seeds.LANGUAGES;
