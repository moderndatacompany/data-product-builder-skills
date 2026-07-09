MODEL (
  name lhs3ny001depot.tpch_sparkv3.customer_snapshot_sf1,
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
  columns(
    c_custkey BIGINT,
    c_name STRING,
    c_acctbal DECIMAL(12, 2)
  ),
  -- assertions (
  --   unique_values(columns := c_custkey),
  --   not_null(columns := (c_custkey, c_name))
  -- ),
  profiles (c_acctbal),
  column_descriptions (
    c_custkey = 'Customer key',
    c_name = 'Customer name',
    c_acctbal = 'Account balance'
  )
);

SELECT
  c.c_custkey,
  c.c_name,
  c.c_acctbal
FROM lhs3ny001depot.tpch_sparkv3.tpch_customer_sf1 c;
