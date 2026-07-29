MODEL (
  name web_analytics_bronze.PRODUCT_DETAILS,
  kind FULL,
  owner '${DATAOS_RUN_AS_USER}',
  description 'Bronze layer product catalog data with brand, classification, and supplier information',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'dimension', 'product'),
  terms ('product')
);

SELECT * FROM web_analytics_seeds.PRODUCT_DETAILS;
