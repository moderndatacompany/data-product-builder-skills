MODEL (
  name mys3lh02depot.tpch_lakehouse.order_line_summary,
  kind VIEW,
  start '2025-01-01',
  grains (l_orderkey),
  assertions (
    unique_values(columns := l_orderkey),
    not_null(columns := (l_orderkey, o_orderdate)),
    forall(criteria := (total_quantity >= 0)),
    forall(criteria := (total_revenue >= 0))
  ),
  profiles (total_quantity, total_revenue, line_count),
  column_descriptions (
    l_orderkey = 'Order key',
    o_custkey = 'Customer key',
    o_orderdate = 'Order date',
    total_quantity = 'Sum of line quantities',
    total_revenue = 'Sum of net line amounts',
    line_count = 'Number of line items in this order'
  )
);

SELECT
  oi.l_orderkey,
  oi.o_custkey,
  oi.o_orderdate,
  SUM(oi.l_quantity) AS total_quantity,
  SUM(oi.net_amount) AS total_revenue,
  COUNT(*) AS line_count
FROM mys3lh02depot.tpch_lakehouse.int_order_items oi
GROUP BY oi.l_orderkey, oi.o_custkey, oi.o_orderdate;
