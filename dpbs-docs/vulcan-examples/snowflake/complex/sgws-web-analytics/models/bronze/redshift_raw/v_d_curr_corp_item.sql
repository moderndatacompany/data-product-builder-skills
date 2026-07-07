MODEL (
  name web_analytics_bronze.V_D_CURR_CORP_ITEM,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Bronze layer product catalog data with brand, classification, and supplier information',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'dimension', 'product'),
  terms ('product')
);

-- Explicit VARCHAR for corp_item_no so joins in silver never trigger numeric parse
SELECT * REPLACE (cast(corp_item_no AS VARCHAR) AS corp_item_no)
FROM web_analytics_seeds.V_D_CURR_CORP_ITEM;
