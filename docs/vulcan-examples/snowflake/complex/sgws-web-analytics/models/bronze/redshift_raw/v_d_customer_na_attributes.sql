MODEL (
  name web_analytics_bronze.V_D_CUSTOMER_NA_ATTRIBUTES,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Bronze layer customer data with demographics, site information, and sales classifications',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'dimension', 'customer'),
  terms ('customer')
);

SELECT * REPLACE (
  cast(site AS VARCHAR) AS site,
  cast(customer_no AS VARCHAR) AS customer_no
)
FROM web_analytics_seeds.V_D_CUSTOMER_NA_ATTRIBUTES;
