MODEL (
  name web_analytics_bronze.SITE_PRODUCT_DETAILS,
  kind FULL,
  owner '${DATAOS_RUN_AS_USER}',
  description 'Bronze layer product catalog data with brand, classification, and supplier information',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'dimension', 'product'),
  terms ('product')
);

SELECT * FROM web_analytics_seeds.SITE_PRODUCT_DETAILS;
