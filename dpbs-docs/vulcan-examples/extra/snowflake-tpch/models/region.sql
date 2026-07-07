MODEL (
  name test_db.vulcan_test_project.region,
  kind VIEW,
  grains (REGIONKEY),
  tags ('tpch', 'dimension'),
  description 'TPC-H REGION dimension (from SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION)',
  column_descriptions (
    regionkey = 'Primary key for REGION',
    name = 'Region name',
    comment = 'Free-form comment'
  )
);

SELECT
  R_REGIONKEY::NUMBER(38, 0) AS regionkey,
  R_NAME::VARCHAR AS name,
  R_COMMENT::VARCHAR AS comment
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION;


