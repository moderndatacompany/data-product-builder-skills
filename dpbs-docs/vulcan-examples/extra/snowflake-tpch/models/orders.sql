MODEL (
  name test_db.vulcan_test_project.orders,
  kind VIEW,
  grains (ORDERKEY),
  tags ('tpch', 'fact'),
  description 'TPC-H ORDERS fact table (from SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS)',
  column_descriptions (
    orderkey = 'Primary key for ORDERS',
    custkey = 'Foreign key to CUSTOMER',
    orderstatus = 'Order status code',
    totalprice = 'Total order price',
    orderdate = 'Order date',
    orderpriority = 'Order priority',
    clerk = 'Clerk identifier',
    shippriority = 'Shipping priority',
    comment = 'Free-form comment'
  )
);

SELECT
  O_ORDERKEY::NUMBER(38, 0) AS orderkey,
  O_CUSTKEY::NUMBER(38, 0) AS custkey,
  O_ORDERSTATUS::VARCHAR AS orderstatus,
  O_TOTALPRICE::NUMBER(18, 2) AS totalprice,
  CAST(O_ORDERDATE AS TIMESTAMP) AS orderdate,
  O_ORDERPRIORITY::VARCHAR AS orderpriority,
  O_CLERK::VARCHAR AS clerk,
  O_SHIPPRIORITY::NUMBER(38, 0) AS shippriority,
  O_COMMENT::VARCHAR AS comment
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS;


