MODEL (
  name lhs3ny001depot.tpch_sparkv3.tpch_orders_sf1,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column o_orderdate,
    batch_size 30,
    batch_concurrency 2,
    lookback 7,
    forward_only false
  ),
  start '2025-01-01',
  owner 'rohitrajtmdcio',
  tags (orders, incremental, tpch),
  grains (o_orderkey),
  physical_properties (
    format = 'iceberg'
  ),
  columns (
    o_orderkey BIGINT,
    o_custkey BIGINT,
    o_orderstatus STRING,
    o_totalprice DECIMAL(12, 2),
    o_orderdate DATE,
    o_orderpriority STRING,
    o_clerk STRING,
    o_shippriority BIGINT,
    o_comment STRING
  ),
  allow_partials true,
  -- assertions (
  --   forall(criteria := (o_totalprice >= 0)),
  --   accepted_values(column := o_orderstatus, is_in := ('F', 'O', 'P')),
  --   string_length_equal(column := o_orderstatus, v := 1),
  --   chi_square(column_a := o_orderstatus, column_b := o_orderpriority, critical_value := 20)
  -- ),
  profiles (o_totalprice, o_orderstatus, o_orderpriority),
  column_descriptions (
    o_orderkey = 'Order key',
    o_custkey = 'Customer key',
    o_orderstatus = 'Order status',
    o_totalprice = 'Total price',
    o_orderdate = 'Order date',
    o_orderpriority = 'Order priority',
    o_clerk = 'Clerk',
    o_shippriority = 'Ship priority',
    o_comment = 'Comment'
  )
);

SELECT
  o_orderkey,
  o_custkey,
  o_orderstatus,
  o_totalprice,
  o_orderdate,
  o_orderpriority,
  o_clerk,
  o_shippriority,
  o_comment
FROM lhs3ny001depot.tpch_sf1.orders
WHERE o_orderdate BETWEEN @start_ds AND @end_ds;
