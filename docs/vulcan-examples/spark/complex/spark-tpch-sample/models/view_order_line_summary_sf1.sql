MODEL (
  name lhs3ny001depot.tpch_sparkv3.view_order_line_summary_sf1,
  kind FULL,
  start '2025-01-01',
  grains (o_orderkey),
  columns (
    o_orderkey BIGINT,
    o_custkey BIGINT,
    o_orderdate DATE,
    total_quantity DECIMAL(12, 2),
    total_extended_price DECIMAL(12, 2),
    line_count BIGINT
  ),
  -- assertions (
  --   unique_values(columns := o_orderkey),
  --   not_null(columns := (o_orderkey, o_orderdate)),
  --   mean_in_range(column := line_count, min_v := 0, max_v := 1000000)
  -- ),
  profiles (total_quantity, total_extended_price, line_count),
  column_descriptions (
    o_orderkey = 'Order key',
    o_custkey = 'Customer key',
    o_orderdate = 'Order date',
    total_quantity = 'Total quantity',
    total_extended_price = 'Total extended price',
    line_count = 'Number of lines'
  )
);

SELECT
  o.o_orderkey,
  o.o_custkey,
  o.o_orderdate,
  SUM(l.l_quantity) AS total_quantity,
  SUM(l.l_extendedprice) AS total_extended_price,
  COUNT(*) AS line_count
FROM lhs3ny001depot.tpch_sparkv3.tpch_orders_sf1 o
JOIN lhs3ny001depot.tpch_sparkv3.tpch_lineitem_sf1 l ON l.l_orderkey = o.o_orderkey
GROUP BY o.o_orderkey, o.o_custkey, o.o_orderdate;
