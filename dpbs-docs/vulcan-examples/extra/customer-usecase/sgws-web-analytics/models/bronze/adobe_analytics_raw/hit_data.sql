MODEL (
  name web_analytics_bronze.HIT_DATA,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics')
);

-- Raw hit data with all 1178 columns from CSV with proper column names
-- No transformations applied at this layer
SELECT * FROM web_analytics_seeds.HIT_DATA;
