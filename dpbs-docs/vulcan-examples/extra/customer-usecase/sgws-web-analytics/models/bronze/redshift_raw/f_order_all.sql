MODEL (
  name web_analytics_bronze.F_ORDER_ALL,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Bronze layer order transaction fact table with order status and fulfillment tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'orders'),
  terms ('orders')
);

-- Explicit VARCHAR for ID columns so CUSTOMER silver can coerce; avoids "Numeric value ... is not recognized"
SELECT * REPLACE (
  cast(site_id AS VARCHAR) AS site_id,
  cast(item_no AS VARCHAR) AS item_no,
  cast(customer_no AS VARCHAR) AS customer_no,
  cast(order_no AS VARCHAR) AS order_no
)
FROM web_analytics_seeds.F_ORDER_ALL;

