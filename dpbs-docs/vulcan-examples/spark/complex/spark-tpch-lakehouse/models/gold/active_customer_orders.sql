MODEL (
  name mys3lh02depot.tpch_lakehouse.active_customer_orders,
  kind FULL,
  start '2025-01-01',
  owner 'rohitrajtmdcio',
  tags (customer, active, orders, gold),
  grains (c_custkey),
  physical_properties (
    format = 'iceberg'
  ),
  assertions (
    unique_values(columns := c_custkey),
    not_null(columns := (c_custkey, c_name)),
    forall(criteria := (order_count >= 0))
  ),
  column_descriptions (
    c_custkey = 'Customer key',
    c_name = 'Customer name',
    c_mktsegment = 'Market segment',
    r_name = 'Region name',
    order_count = 'Number of orders for active customers only (acctbal > 0)'
  )
);

SELECT
  ac.c_custkey,
  ac.c_name,
  ac.c_mktsegment,
  ac.r_name,
  COUNT(DISTINCT oi.l_orderkey) AS order_count
FROM mys3lh02depot.tpch_lakehouse.emb_active_customers ac
LEFT JOIN mys3lh02depot.tpch_lakehouse.int_order_items oi
  ON oi.o_custkey = ac.c_custkey
GROUP BY ac.c_custkey, ac.c_name, ac.c_mktsegment, ac.r_name;
