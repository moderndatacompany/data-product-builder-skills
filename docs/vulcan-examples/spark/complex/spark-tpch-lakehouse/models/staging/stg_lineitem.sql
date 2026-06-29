MODEL (
  name mys3lh02depot.tpch_lakehouse.stg_lineitem,
  kind VIEW,
  start '2025-01-01',
  grains (l_orderkey, l_linenumber),
  assertions (
    unique_combination_of_columns(columns := (l_orderkey, l_linenumber)),
    not_null(columns := (l_orderkey, l_linenumber, l_quantity, l_extendedprice))
  ),
  profiles (l_quantity, l_extendedprice, l_discount, l_tax, l_returnflag, l_linestatus, l_shipmode),
  column_descriptions (
    l_orderkey = 'Foreign key to orders',
    l_partkey = 'Foreign key to part',
    l_suppkey = 'Foreign key to supplier',
    l_linenumber = 'Line number within the order',
    l_quantity = 'Quantity ordered',
    l_extendedprice = 'Extended price (quantity x unit price)',
    l_discount = 'Discount percentage',
    l_tax = 'Tax rate',
    l_returnflag = 'Return flag (R=Returned, A=Accepted, N=None)',
    l_linestatus = 'Line status (O=Open, F=Fulfilled)',
    l_shipdate = 'Ship date',
    l_commitdate = 'Commit date',
    l_receiptdate = 'Receipt date',
    l_shipinstruct = 'Shipping instructions',
    l_shipmode = 'Ship mode (AIR, MAIL, RAIL, SHIP, TRUCK, FOB, REG AIR)',
    l_comment = 'Free-text comment'
  )
);

SELECT
  l_orderkey,
  l_partkey,
  l_suppkey,
  l_linenumber,
  l_quantity,
  l_extendedprice,
  l_discount,
  l_tax,
  l_returnflag,
  l_linestatus,
  l_shipdate,
  l_commitdate,
  l_receiptdate,
  l_shipinstruct,
  l_shipmode,
  l_comment
FROM mys3lh02depot.tpch_sf1.lineitem;
