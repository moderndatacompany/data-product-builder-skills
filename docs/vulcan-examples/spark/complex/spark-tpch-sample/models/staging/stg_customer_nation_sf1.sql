MODEL (
  name lhs3ny001depot.tpch_sparkv3.stg_customer_nation_sf1,
  kind FULL,
  start '2025-01-01',
  grains (c_custkey),
  columns (
    c_custkey BIGINT,
    c_name STRING,
    c_nationkey BIGINT,
    n_name STRING
  ),
  -- assertions (
  --   unique_values(columns := c_custkey),
  --   not_null(columns := (c_custkey, c_name, n_name)),
  --   valid_email(column := c_name)
  -- ),
  profiles (c_nationkey, n_name),
  column_descriptions (
    c_custkey = 'Customer key',
    c_name = 'Customer name',
    c_nationkey = 'Nation key',
    n_name = 'Nation name'
  )
);

SELECT
  c.c_custkey,
  c.c_name,
  c.c_nationkey,
  n.n_name
FROM lhs3ny001depot.tpch_sparkv3.tpch_customer_sf1 c
LEFT JOIN lhs3ny001depot.tpch_sparkv3.tpch_nation_sf1 n
  ON n.n_nationkey = c.c_nationkey
  AND n.valid_to IS NULL;
