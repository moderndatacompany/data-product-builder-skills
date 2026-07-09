MODEL (
  name lhs3ny001depot.tpch_sparkv3.full_active_customer_orders_sf1,
  kind FULL,
  start '2025-01-01',
  owner 'rohitrajtmdcio',
  tags (customer, orders, active, gold),
  grains (c_custkey),
  physical_properties (
    format = 'iceberg'
  ),
  columns(
    c_custkey BIGINT,
    c_name STRING,
    c_mktsegment STRING,
    order_count BIGINT
  ),
  -- assertions (
  --   unique_values(columns := c_custkey),
  --   not_null(columns := (c_custkey, c_name)),
  --   z_score(column := order_count, threshold := 5),
  --   valid_http_method(column := c_name)
  -- ),
  column_descriptions (
    c_custkey = 'Customer key',
    c_name = 'Customer name',
    c_mktsegment = 'Market segment',
    order_count = 'Number of orders for active customers only'
  )
);

SELECT
  ac.c_custkey,
  ac.c_name,
  ac.c_mktsegment,
  COUNT(DISTINCT o.o_orderkey) AS order_count
FROM lhs3ny001depot.tpch_sparkv3.emb_active_customers_sf1 ac
LEFT JOIN lhs3ny001depot.tpch_sparkv3.tpch_orders_sf1 o ON o.o_custkey = ac.c_custkey
GROUP BY ac.c_custkey, ac.c_name, ac.c_mktsegment;
