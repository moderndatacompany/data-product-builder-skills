MODEL (
  name lhs3ny001depot.tpch_sparkv3.full_customer_orders_sf1,
  kind FULL,
  start '2025-01-01',
  owner 'rohitrajtmdcio',
  tags (customer, orders, gold),
  grains (c_custkey),
  physical_properties (
    format = 'iceberg'
  ),
  columns(
    c_custkey BIGINT,
    c_name STRING,
    order_count BIGINT,
    total_amount DECIMAL(12, 2)
  ),
  -- assertions (
  --   unique_values(columns := c_custkey),
  --   not_null(columns := (c_custkey, c_name)),
  --   valid_url(column := c_name)
  -- ),
  profiles (order_count, total_amount),
  column_descriptions (
    c_custkey = 'Customer key',
    c_name = 'Customer name',
    order_count = 'Number of orders',
    total_amount = 'Total order amount'
  )
);

SELECT
  c.c_custkey,
  c.c_name,
  COUNT(DISTINCT o.o_orderkey) AS order_count,
  COALESCE(SUM(l.l_extendedprice * (1 - l.l_discount)), 0) AS total_amount
FROM lhs3ny001depot.tpch_sparkv3.tpch_customer_sf1 c
LEFT JOIN lhs3ny001depot.tpch_sparkv3.tpch_orders_sf1 o ON o.o_custkey = c.c_custkey
LEFT JOIN lhs3ny001depot.tpch_sparkv3.tpch_lineitem_sf1 l ON l.l_orderkey = o.o_orderkey
GROUP BY c.c_custkey, c.c_name;
