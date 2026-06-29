MODEL (
  name web_analytics_bronze.V_D_SITE,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics')
);

-- Explicit VARCHAR for site so joins in silver never trigger numeric parse
SELECT * REPLACE (cast(site AS VARCHAR) AS site)
FROM web_analytics_seeds.V_D_SITE;
