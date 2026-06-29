MODEL (
  name web_analytics_bronze.V_F_ORDER,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Bronze layer order transaction fact table with order status and fulfillment tracking',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'orders'),
  terms ('orders')
);

SELECT * FROM web_analytics_seeds.V_F_ORDER;
