MODEL (
  name web_analytics_bronze.V_D_CURR_ITEM,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Bronze layer product catalog data with brand, classification, and supplier information',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'dimension', 'product'),
  terms ('product')
);

-- Explicit VARCHAR for ID columns so joins in silver never trigger numeric parse (e.g. ASEKD)
SELECT * REPLACE (
  cast(site AS VARCHAR) AS site,
  cast(item_no AS VARCHAR) AS item_no
)
FROM web_analytics_seeds.V_D_CURR_ITEM;
