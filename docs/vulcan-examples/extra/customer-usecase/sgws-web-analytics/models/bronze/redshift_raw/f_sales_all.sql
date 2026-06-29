MODEL (
  name web_analytics_bronze.F_SALES_ALL,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Bronze layer sales transaction fact table with revenue, quantities, and invoice details',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'sales'),
  terms ('sales')
);

-- Explicit VARCHAR for ID columns so CUSTOMER silver can coerce; avoids "Numeric value ... is not recognized"
SELECT * REPLACE (
  cast(site AS VARCHAR) AS site,
  cast(warehouse_no AS VARCHAR) AS warehouse_no,
  cast(customer_no AS VARCHAR) AS customer_no,
  cast(item_no AS VARCHAR) AS item_no,
  cast(salesman_no AS VARCHAR) AS salesman_no
)
FROM web_analytics_seeds.F_SALES_ALL;

