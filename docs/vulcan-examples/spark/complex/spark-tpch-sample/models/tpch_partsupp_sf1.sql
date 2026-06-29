MODEL (
  name lhs3ny001depot.tpch_sparkv3.tpch_partsupp_sf1,
  kind FULL,
  start '2025-01-01',
  grains (ps_partkey, ps_suppkey),
  columns (
    ps_partkey BIGINT,
    ps_suppkey BIGINT,
    ps_availqty BIGINT,
    ps_supplycost DECIMAL(12, 2),
    ps_comment STRING
  ),
  -- assertions (
  --   unique_combination_of_columns(columns := (ps_partkey, ps_suppkey)),
  --   not_null(columns := (ps_partkey, ps_suppkey)),
  --   number_of_rows(threshold := 0)
  -- ),
  profiles (ps_availqty, ps_supplycost),
  column_descriptions (
    ps_partkey = 'Part key',
    ps_suppkey = 'Supplier key',
    ps_availqty = 'Available quantity',
    ps_supplycost = 'Supply cost',
    ps_comment = 'Comment'
  )
);

SELECT
  ps_partkey,
  ps_suppkey,
  ps_availqty,
  ps_supplycost,
  ps_comment
FROM lhs3ny001depot.tpch_sf1.partsupp;
