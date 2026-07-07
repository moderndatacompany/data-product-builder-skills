MODEL (
  name s3lhyddepot.tpch_analytics.customer_orders_summary,
  kind FULL,
  cron '@daily',
  grain (C_CUSTKEY),
  tags ('tpch', 'analytics', 'customer'),
  description 'Customer-level order aggregation with total spend and order counts'
);

SELECT
  c.C_CUSTKEY,
  c.C_NAME,
  c.C_MKTSEGMENT,
  n.N_NAME AS NATION_NAME,
  COUNT(DISTINCT o.O_ORDERKEY) AS ORDER_COUNT,
  SUM(o.O_TOTALPRICE) AS TOTAL_SPEND,
  AVG(o.O_TOTALPRICE) AS AVG_ORDER_VALUE,
  MIN(o.O_ORDERDATE) AS FIRST_ORDER_DATE,
  MAX(o.O_ORDERDATE) AS LAST_ORDER_DATE
FROM s3lhyddepot.tpch_sf1.customer c
JOIN s3lhyddepot.tpch_sf1.orders o ON c.C_CUSTKEY = o.O_CUSTKEY
JOIN s3lhyddepot.tpch_sf1.nation n ON c.C_NATIONKEY = n.N_NATIONKEY
GROUP BY c.C_CUSTKEY, c.C_NAME, c.C_MKTSEGMENT, n.N_NAME
