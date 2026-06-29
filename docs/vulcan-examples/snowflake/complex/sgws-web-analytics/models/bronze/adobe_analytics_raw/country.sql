MODEL (
  name web_analytics_bronze.COUNTRY,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [COUNTRY_ID],
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    COUNTRY_ID = 'Country Id - identifier',
    COUNTRY_NAME = 'Country Name'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    COUNTRY_ID = ('identifier', 'fact'),
    COUNTRY_NAME = ('attribute', 'fact')
  )
);

SELECT 
  country_id::INTEGER AS COUNTRY_ID,
  country_name::VARCHAR AS COUNTRY_NAME
FROM web_analytics_seeds.COUNTRY;
