MODEL (
  name web_analytics_bronze.V_D_CUSTOMER,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Bronze layer customer data with demographics, site information, and sales classifications',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'dimension', 'customer'),
  terms ('customer')
);

-- Explicit VARCHAR for ID columns so alphanumeric values are stored as-is; silver coerces to numeric
SELECT * REPLACE (
  cast(customer_sk AS VARCHAR) AS customer_sk,
  cast(site AS VARCHAR) AS site,
  cast(customer_no AS VARCHAR) AS customer_no,
  cast(univ_customer_no AS VARCHAR) AS univ_customer_no
)
FROM web_analytics_seeds.V_D_CUSTOMER;
