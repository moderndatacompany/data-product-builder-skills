MODEL (
  name test_db.vulcan_test_project.part,
  kind VIEW,
  grains (PARTKEY),
  tags ('tpch', 'dimension', 'product'),
  description 'TPC-H PART dimension (from SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PART)',
  column_descriptions (
    partkey = 'Primary key for PART',
    name = 'Part name',
    mfgr = 'Manufacturer',
    brand = 'Brand',
    type = 'Part type',
    size = 'Part size',
    container = 'Container',
    retailprice = 'Retail price',
    comment = 'Free-form comment'
  )
);

SELECT
  P_PARTKEY::NUMBER(38, 0) AS partkey,
  P_NAME::VARCHAR AS name,
  P_MFGR::VARCHAR AS mfgr,
  P_BRAND::VARCHAR AS brand,
  P_TYPE::VARCHAR AS type,
  P_SIZE::NUMBER(38, 0) AS size,
  P_CONTAINER::VARCHAR AS container,
  P_RETAILPRICE::NUMBER(18, 2) AS retailprice,
  P_COMMENT::VARCHAR AS comment
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PART;


