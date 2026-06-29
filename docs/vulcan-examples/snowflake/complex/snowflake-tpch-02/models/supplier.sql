MODEL (
  name test_db.vulcan_test_project.supplier,
  kind VIEW,
  grains (SUPPKEY),
  tags ('tpch', 'dimension', 'supplier'),
  description 'TPC-H SUPPLIER dimension (from SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.SUPPLIER)',
  column_descriptions (
    suppkey = 'Primary key for SUPPLIER',
    name = 'Supplier name',
    address = 'Supplier address',
    nationkey = 'Foreign key to NATION',
    phone = 'Supplier phone number',
    acctbal = 'Account balance',
    comment = 'Free-form comment'
  )
);

SELECT
  S_SUPPKEY::NUMBER(38, 0) AS suppkey,
  S_NAME::VARCHAR AS name,
  S_ADDRESS::VARCHAR AS address,
  S_NATIONKEY::NUMBER(38, 0) AS nationkey,
  S_PHONE::VARCHAR AS phone,
  S_ACCTBAL::NUMBER(18, 2) AS acctbal,
  S_COMMENT::VARCHAR AS comment
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.SUPPLIER;


