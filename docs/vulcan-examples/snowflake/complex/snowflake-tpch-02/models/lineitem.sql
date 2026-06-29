MODEL (
  name test_db.vulcan_test_project.lineitem,
  kind VIEW,
  grains (ORDERKEY, LINENUMBER),
  tags ('tpch', 'fact', 'line'),
  description 'TPC-H LINEITEM fact table (from SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM)',
  column_descriptions (
    orderkey = 'Foreign key to ORDERS',
    partkey = 'Foreign key to PART',
    suppkey = 'Foreign key to SUPPLIER',
    linenumber = 'Line number within an order (part of primary key)',
    quantity = 'Quantity ordered',
    extendedprice = 'Extended price',
    discount = 'Discount applied',
    tax = 'Tax applied',
    returnflag = 'Return flag code',
    linestatus = 'Line status code',
    shipdate = 'Shipping date',
    commitdate = 'Commit date',
    receiptdate = 'Receipt date',
    shipinstruct = 'Shipping instructions',
    shipmode = 'Shipping mode',
    comment = 'Free-form comment'
  )
);

SELECT
  L_ORDERKEY::NUMBER(38, 0) AS orderkey,
  L_PARTKEY::NUMBER(38, 0) AS partkey,
  L_SUPPKEY::NUMBER(38, 0) AS suppkey,
  L_LINENUMBER::NUMBER(38, 0) AS linenumber,
  L_QUANTITY::NUMBER(18, 2) AS quantity,
  L_EXTENDEDPRICE::NUMBER(18, 2) AS extendedprice,
  L_DISCOUNT::NUMBER(18, 2) AS discount,
  L_TAX::NUMBER(18, 2) AS tax,
  L_RETURNFLAG::VARCHAR AS returnflag,
  L_LINESTATUS::VARCHAR AS linestatus,
  CAST(L_SHIPDATE AS TIMESTAMP) AS shipdate,
  CAST(L_COMMITDATE AS TIMESTAMP) AS commitdate,
  CAST(L_RECEIPTDATE AS TIMESTAMP) AS receiptdate,
  L_SHIPINSTRUCT::VARCHAR AS shipinstruct,
  L_SHIPMODE::VARCHAR AS shipmode,
  L_COMMENT::VARCHAR AS comment
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM;


