MODEL (
  name mys3lh02depot.tpch_lakehouse.stg_partsupp,
  kind VIEW,
  start '2025-01-01',
  grains (ps_partkey, ps_suppkey),
  assertions (
    unique_combination_of_columns(columns := (ps_partkey, ps_suppkey)),
    not_null(columns := (ps_partkey, ps_suppkey))
  ),
  profiles (ps_availqty, ps_supplycost),
  column_descriptions (
    ps_partkey = 'Foreign key to part',
    ps_suppkey = 'Foreign key to supplier',
    ps_availqty = 'Available quantity from this supplier',
    ps_supplycost = 'Supply cost from this supplier',
    ps_comment = 'Free-text comment'
  )
);

SELECT
  ps_partkey,
  ps_suppkey,
  ps_availqty,
  ps_supplycost,
  ps_comment
FROM mys3lh02depot.tpch_sf1.partsupp;
