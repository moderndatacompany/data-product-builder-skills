MODEL (
  name lhs3ny001depot.tpch_sparkv3.tpch_lineitem_sf1,
  kind FULL,
  start '2025-01-01',
  grains (l_orderkey, l_linenumber),
  columns (
    l_orderkey BIGINT,
    l_partkey BIGINT,
    l_suppkey BIGINT,
    l_linenumber BIGINT,
    l_quantity DECIMAL(12, 2),
    l_extendedprice DECIMAL(12, 2),
    l_discount DECIMAL(12, 2),
    l_tax DECIMAL(12, 2),
    l_returnflag STRING,
    l_linestatus STRING,
    l_shipdate DATE,
    l_commitdate DATE,
    l_receiptdate DATE,
    l_shipinstruct STRING,
    l_shipmode STRING,
    l_comment STRING
  ),
  -- assertions (
  --   unique_combination_of_columns(columns := (l_orderkey, l_linenumber)),
  --   not_null(columns := (l_orderkey, l_linenumber)),
  --   not_accepted_values(column := l_returnflag, is_in := ('X')),
  --   match_regex_pattern_list(column := l_shipmode, patterns := ('^AIR$', '^REG AIR$', '^MAIL$', '^FOB$', '^TRUCK$', '^RAIL$', '^SHIP$'))
  -- ),
  profiles (l_quantity, l_extendedprice, l_discount, l_tax, l_returnflag, l_linestatus, l_shipmode),
  column_descriptions (
    l_orderkey = 'Order key',
    l_partkey = 'Part key',
    l_suppkey = 'Supplier key',
    l_linenumber = 'Line number',
    l_quantity = 'Quantity',
    l_extendedprice = 'Extended price',
    l_discount = 'Discount',
    l_tax = 'Tax',
    l_returnflag = 'Return flag',
    l_linestatus = 'Line status',
    l_shipdate = 'Ship date',
    l_commitdate = 'Commit date',
    l_receiptdate = 'Receipt date',
    l_shipinstruct = 'Ship instruct',
    l_shipmode = 'Ship mode',
    l_comment = 'Comment'
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
FROM lhs3ny001depot.tpch_sf1.lineitem;
