MODEL (
  name lhs3ny001depot.tpch_sparkv3.tpch_customer_sf1,
  kind FULL,
  start '2025-01-01',
  grains (c_custkey),
  columns (
    c_custkey BIGINT,
    c_name STRING,
    c_address STRING,
    c_nationkey BIGINT,
    c_phone STRING,
    c_acctbal DECIMAL(12, 2),
    c_mktsegment STRING,
    c_comment STRING
  ),
  -- assertions (
  --   unique_values(columns := c_custkey),
  --   not_null(columns := (c_custkey, c_name)),
  --   match_like_pattern_list(column := c_name, patterns := ('%'))
  -- ),
  profiles (c_acctbal, c_mktsegment, c_nationkey),
  column_descriptions (
    c_custkey = 'Customer key',
    c_name = 'Customer name',
    c_address = 'Customer address',
    c_nationkey = 'Nation key',
    c_phone = 'Phone',
    c_acctbal = 'Account balance',
    c_mktsegment = 'Market segment',
    c_comment = 'Comment'
  )
);

SELECT
  c_custkey,
  c_name,
  c_address,
  c_nationkey,
  c_phone,
  c_acctbal,
  c_mktsegment,
  c_comment
FROM lhs3ny001depot.tpch_sf1.customer;
