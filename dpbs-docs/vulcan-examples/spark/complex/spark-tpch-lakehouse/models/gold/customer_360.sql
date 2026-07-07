MODEL (
  name mys3lh02depot.tpch_lakehouse.customer_360,
  kind FULL,
  start '2025-01-01',
  owner 'rohitrajtmdcio',
  tags (customer, analytics, gold),
  grains (c_custkey),
  physical_properties (
    format = 'iceberg'
  ),
  assertions (
    unique_values(columns := c_custkey),
    not_null(columns := (c_custkey, c_name)),
    forall(criteria := (order_count >= 0)),
    forall(criteria := (total_revenue >= 0))
  ),
  profiles (order_count, total_revenue, avg_order_value, c_mktsegment, r_name),
  column_descriptions (
    c_custkey = 'Customer key',
    c_name = 'Customer name',
    c_mktsegment = 'Market segment',
    c_acctbal = 'Account balance',
    n_name = 'Nation name',
    r_name = 'Region name',
    order_count = 'Total number of distinct orders',
    total_revenue = 'Total revenue (sum of net line amounts)',
    avg_order_value = 'Average order value'
  )
);

SELECT
  cn.c_custkey,
  cn.c_name,
  cn.c_mktsegment,
  cn.c_acctbal,
  cn.n_name,
  cn.r_name,
  COUNT(DISTINCT oi.l_orderkey) AS order_count,
  COALESCE(SUM(oi.net_amount), 0) AS total_revenue,
  COALESCE(
    SUM(oi.net_amount) / NULLIF(COUNT(DISTINCT oi.l_orderkey), 0),
    0
  ) AS avg_order_value
FROM mys3lh02depot.tpch_lakehouse.int_customer_nation cn
LEFT JOIN mys3lh02depot.tpch_lakehouse.int_order_items oi
  ON oi.o_custkey = cn.c_custkey
GROUP BY
  cn.c_custkey,
  cn.c_name,
  cn.c_mktsegment,
  cn.c_acctbal,
  cn.n_name,
  cn.r_name;
