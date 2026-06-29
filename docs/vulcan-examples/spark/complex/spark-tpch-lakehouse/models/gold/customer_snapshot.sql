MODEL (
  name mys3lh02depot.tpch_lakehouse.customer_snapshot,
  kind INCREMENTAL_BY_UNIQUE_KEY (
    unique_key c_custkey
  ),
  start '2025-01-01',
  cron '@daily',
  owner 'rohitrajtmdcio',
  tags (customer, incremental, snapshot),
  grains (c_custkey),
  physical_properties (
    format = 'iceberg'
  ),
  assertions (
    unique_values(columns := c_custkey),
    not_null(columns := (c_custkey, c_name))
  ),
  profiles (c_acctbal, latest_order_date),
  column_descriptions (
    c_custkey = 'Customer key',
    c_name = 'Customer name',
    c_mktsegment = 'Market segment',
    c_acctbal = 'Current account balance',
    n_name = 'Nation name',
    latest_order_date = 'Most recent order date',
    total_orders = 'Cumulative order count',
    snapshot_ts = 'Timestamp of this snapshot'
  )
);

SELECT
  cn.c_custkey,
  cn.c_name,
  cn.c_mktsegment,
  cn.c_acctbal,
  cn.n_name,
  MAX(oi.o_orderdate) AS latest_order_date,
  COUNT(DISTINCT oi.l_orderkey) AS total_orders,
  CURRENT_TIMESTAMP AS snapshot_ts
FROM mys3lh02depot.tpch_lakehouse.int_customer_nation cn
LEFT JOIN mys3lh02depot.tpch_lakehouse.int_order_items oi
  ON oi.o_custkey = cn.c_custkey
GROUP BY
  cn.c_custkey,
  cn.c_name,
  cn.c_mktsegment,
  cn.c_acctbal,
  cn.n_name;
