MODEL (
  name test_db.vulcan_test_project.nation,
  kind VIEW,
  grains (NATIONKEY),
  tags ('tpch', 'dimension'),
  description 'TPC-H NATION dimension (from SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION)',
  column_descriptions (
    nationkey = 'Primary key for NATION',
    name = 'Nation name',
    regionkey = 'Foreign key to REGION',
    comment = 'Free-form comment'
  )
);

SELECT
  N_NATIONKEY::NUMBER(38, 0) AS nationkey,
  N_NAME::VARCHAR AS name,
  N_REGIONKEY::NUMBER(38, 0) AS regionkey,
  N_COMMENT::VARCHAR AS comment
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION;


