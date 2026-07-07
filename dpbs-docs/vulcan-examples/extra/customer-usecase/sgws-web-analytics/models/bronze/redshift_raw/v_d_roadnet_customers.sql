MODEL (
  name web_analytics_bronze.V_D_ROADNET_CUSTOMERS,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Bronze layer customer data with demographics, site information, and sales classifications',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'dimension', 'customer'),
  terms ('customer')
);

SELECT * FROM web_analytics_seeds.V_D_ROADNET_CUSTOMERS;
