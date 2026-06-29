MODEL (
  name test_db.vulcan_test_project.partsupp,
  kind VIEW,
  grains (PARTKEY, SUPPKEY),
  tags ('tpch', 'bridge'),
  description 'TPC-H PARTSUPP bridge table (from SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PARTSUPP)',
  column_descriptions (
    partkey = 'Foreign key to PART',
    suppkey = 'Foreign key to SUPPLIER',
    availqty = 'Available quantity',
    supplycost = 'Supply cost',
    comment = 'Free-form comment'
  )
);

SELECT
  PS_PARTKEY::NUMBER(38, 0) AS partkey,
  PS_SUPPKEY::NUMBER(38, 0) AS suppkey,
  PS_AVAILQTY::NUMBER(38, 0) AS availqty,
  PS_SUPPLYCOST::NUMBER(18, 2) AS supplycost,
  PS_COMMENT::VARCHAR AS comment
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PARTSUPP;


