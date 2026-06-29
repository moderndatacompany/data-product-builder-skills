MODEL (
  name s3lhyddepot.tpch_analytics.order_line_revenue,
  kind FULL,
  cron '@daily',
  grain (O_ORDERKEY),
  tags ('tpch', 'analytics', 'revenue'),
  description 'Order-level revenue aggregation with line item details'
);

SELECT
  o.O_ORDERKEY,
  o.O_CUSTKEY,
  o.O_ORDERDATE,
  o.O_ORDERSTATUS,
  o.O_ORDERPRIORITY,
  SUM(l.L_QUANTITY) AS TOTAL_QUANTITY,
  SUM(l.L_EXTENDEDPRICE) AS GROSS_REVENUE,
  SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS NET_REVENUE,
  SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT) * (1 + l.L_TAX)) AS TOTAL_WITH_TAX,
  AVG(l.L_DISCOUNT) AS AVG_DISCOUNT,
  COUNT(DISTINCT l.L_LINENUMBER) AS LINE_COUNT
FROM s3lhyddepot.tpch_sf1.orders o
JOIN s3lhyddepot.tpch_sf1.lineitem l ON o.O_ORDERKEY = l.L_ORDERKEY
GROUP BY o.O_ORDERKEY, o.O_CUSTKEY, o.O_ORDERDATE, o.O_ORDERSTATUS, o.O_ORDERPRIORITY
