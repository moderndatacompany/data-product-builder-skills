MODEL (
  name lhs3ny001depot.tpch_sparkv3.tpch_supplier_sf1,
  kind FULL,
  start '2025-01-01',
  grains (s_suppkey),
  columns (
    s_suppkey BIGINT,
    s_name STRING,
    s_address STRING,
    s_nationkey BIGINT,
    s_phone STRING,
    s_acctbal DECIMAL(12, 2),
    s_comment STRING
  ),
  -- assertions (
  --   unique_values(columns := s_suppkey),
  --   not_null(columns := (s_suppkey, s_name)),
  --   not_empty_string(column := s_name)
  -- ),
  profiles (s_acctbal, s_nationkey),
  column_descriptions (
    s_suppkey = 'Supplier key',
    s_name = 'Supplier name',
    s_address = 'Address',
    s_nationkey = 'Nation key',
    s_phone = 'Phone',
    s_acctbal = 'Account balance',
    s_comment = 'Comment'
  )
);

SELECT
  s_suppkey,
  s_name,
  s_address,
  s_nationkey,
  s_phone,
  s_acctbal,
  s_comment
FROM lhs3ny001depot.tpch_sf1.supplier;
