MODEL (
  name mys3lh02depot.tpch_lakehouse.stg_orders,
  kind VIEW,
  start '2025-01-01',
  grains (o_orderkey),
  assertions (
    unique_values(columns := o_orderkey),
    not_null(columns := (o_orderkey, o_custkey, o_orderdate)),
    accepted_values(column := o_orderstatus, is_in := ('F', 'O', 'P'))
  ),
  profiles (o_totalprice, o_orderstatus, o_orderpriority),
  column_descriptions (
    o_orderkey = 'Unique order identifier',
    o_custkey = 'Foreign key to customer',
    o_orderstatus = 'Order status: F=Fulfilled, O=Open, P=Partial',
    o_totalprice = 'Total order price',
    o_orderdate = 'Date the order was placed',
    o_orderpriority = 'Order priority level',
    o_clerk = 'Clerk who handled the order',
    o_shippriority = 'Shipping priority',
    o_comment = 'Free-text comment'
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
FROM mys3lh02depot.tpch_sf1.orders;
