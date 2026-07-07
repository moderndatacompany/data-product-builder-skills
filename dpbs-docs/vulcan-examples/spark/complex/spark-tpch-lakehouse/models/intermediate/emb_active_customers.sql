MODEL (
  name mys3lh02depot.tpch_lakehouse.emb_active_customers,
  kind EMBEDDED,
  grains (c_custkey)
);

SELECT
  c.c_custkey,
  c.c_name,
  c.c_mktsegment,
  c.c_acctbal,
  c.n_name,
  c.r_name
FROM mys3lh02depot.tpch_lakehouse.int_customer_nation c
WHERE c.c_acctbal > 0;
