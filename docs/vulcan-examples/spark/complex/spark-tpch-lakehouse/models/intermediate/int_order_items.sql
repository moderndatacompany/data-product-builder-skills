MODEL (
  name mys3lh02depot.tpch_lakehouse.int_order_items,
  kind VIEW,
  start '2025-01-01',
  grains (l_orderkey, l_linenumber),
  assertions (
    unique_combination_of_columns(columns := (l_orderkey, l_linenumber)),
    not_null(columns := (l_orderkey, l_linenumber, o_orderdate)),
    forall(criteria := (net_amount >= 0))
  ),
  profiles (net_amount, l_quantity, o_orderstatus),
  column_descriptions (
    l_orderkey = 'Order key',
    l_linenumber = 'Line number',
    o_custkey = 'Customer key',
    o_orderdate = 'Order date',
    o_orderstatus = 'Order status',
    o_orderpriority = 'Order priority',
    l_partkey = 'Part key',
    l_suppkey = 'Supplier key',
    l_quantity = 'Line quantity',
    l_extendedprice = 'Extended price before discount',
    l_discount = 'Discount percentage',
    l_tax = 'Tax rate',
    net_amount = 'Net amount after discount: extendedprice * (1 - discount)',
    l_returnflag = 'Return flag',
    l_shipdate = 'Ship date',
    l_shipmode = 'Ship mode'
  )
);

SELECT
  l.l_orderkey,
  l.l_linenumber,
  o.o_custkey,
  o.o_orderdate,
  o.o_orderstatus,
  o.o_orderpriority,
  l.l_partkey,
  l.l_suppkey,
  l.l_quantity,
  l.l_extendedprice,
  l.l_discount,
  l.l_tax,
  l.l_extendedprice * (1 - l.l_discount) AS net_amount,
  l.l_returnflag,
  l.l_shipdate,
  l.l_shipmode
FROM mys3lh02depot.tpch_lakehouse.stg_orders o
JOIN mys3lh02depot.tpch_lakehouse.stg_lineitem l ON l.l_orderkey = o.o_orderkey;
