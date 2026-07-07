MODEL (
  name web_analytics_bronze.V_D_CURRENT_ACCOUNT_SALESPERSON,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Bronze layer sales transaction fact table with revenue, quantities, and invoice details',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'sales'),
  terms ('sales')
);

SELECT * REPLACE (
  cast(site AS VARCHAR) AS site,
  cast(customer_no AS VARCHAR) AS customer_no
)
FROM web_analytics_seeds.V_D_CURRENT_ACCOUNT_SALESPERSON;
