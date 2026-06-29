MODEL (
  name mys3lh02depot.tpch_lakehouse.int_customer_nation,
  kind VIEW,
  start '2025-01-01',
  grains (c_custkey),
  assertions (
    unique_values(columns := c_custkey),
    not_null(columns := (c_custkey, c_name, n_name, r_name))
  ),
  profiles (c_nationkey, n_name, r_name, c_mktsegment),
  column_descriptions (
    c_custkey = 'Customer key',
    c_name = 'Customer name',
    c_address = 'Customer address',
    c_phone = 'Customer phone',
    c_acctbal = 'Account balance',
    c_mktsegment = 'Market segment',
    c_nationkey = 'Nation key',
    n_name = 'Nation name',
    r_regionkey = 'Region key',
    r_name = 'Region name'
  )
);

SELECT
  c.c_custkey,
  c.c_name,
  c.c_address,
  c.c_phone,
  c.c_acctbal,
  c.c_mktsegment,
  c.c_nationkey,
  n.n_name,
  r.r_regionkey,
  r.r_name
FROM mys3lh02depot.tpch_lakehouse.stg_customer c
JOIN mys3lh02depot.tpch_lakehouse.stg_nation n ON n.n_nationkey = c.c_nationkey
JOIN mys3lh02depot.tpch_lakehouse.stg_region r ON r.r_regionkey = n.n_regionkey;
