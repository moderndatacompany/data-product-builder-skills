MODEL (
  name web_analytics_bronze.NEW_BADGE,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Bronze layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'web_analytics'),
  terms ('web_analytics')
);

-- Reference seed model
SELECT * FROM web_analytics_seeds.NEW_BADGE;

