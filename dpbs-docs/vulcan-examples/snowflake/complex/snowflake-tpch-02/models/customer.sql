MODEL (
  name test_db.vulcan_test_project.customer,
  kind VIEW,
  grains (CUSTKEY),
  tags ('tpch', 'dimension', 'customer'),
  description 'TPC-H CUSTOMER dimension (from SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER)',
  column_descriptions (
    custkey = 'Primary key for CUSTOMER',
    name = 'Customer name',
    address = 'Customer address',
    nationkey = 'Foreign key to NATION',
    phone = 'Customer phone number',
    acctbal = 'Account balance',
    mktsegment = 'Market segment',
    comment = 'Free-form comment'
  )
);

SELECT
  -- Matches requested CUSTOMER column list:
  -- C_CUSTKEY, C_NAME, C_ADDRESS, C_NATIONKEY, C_PHONE, C_ACCTBAL, C_MKTSEGMENT, C_COMMENT
  C_CUSTKEY::NUMBER(38, 0) AS custkey,
  C_NAME::VARCHAR AS name,
  C_ADDRESS::VARCHAR AS address,
  C_NATIONKEY::NUMBER(38, 0) AS nationkey,
  C_PHONE::VARCHAR AS phone,
  C_ACCTBAL::NUMBER(18, 2) AS acctbal,
  C_MKTSEGMENT::VARCHAR AS mktsegment,
  C_COMMENT::VARCHAR AS comment
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER;


