MODEL (
  name lhs3ny001depot.tpch_sparkv3.emb_active_customers_sf1,
  kind EMBEDDED,
  grains (c_custkey),
  columns (
    c_custkey BIGINT,
    c_name STRING,
    c_mktsegment STRING,
    c_acctbal DECIMAL(12, 2),
    c_nationkey BIGINT
  )
);

SELECT
  c.c_custkey,
  c.c_name,
  c.c_mktsegment,
  c.c_acctbal,
  c.c_nationkey
FROM lhs3ny001depot.tpch_sparkv3.tpch_customer_sf1 c
WHERE c.c_acctbal > 0;
