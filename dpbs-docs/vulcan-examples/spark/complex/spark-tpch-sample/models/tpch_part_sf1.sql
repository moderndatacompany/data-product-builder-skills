MODEL (
  name lhs3ny001depot.tpch_sparkv3.tpch_part_sf1,
  kind SCD_TYPE_2_BY_COLUMN (
    unique_key [p_partkey],
    columns [p_name, p_retailprice, p_size],
    valid_from_name valid_from,
    valid_to_name valid_to,
    invalidate_hard_deletes true
  ),
  start '2025-01-01',
  owner 'rohitrajtmdcio',
  tags (part, scd2, dimension),
  grains (p_partkey),
  physical_properties (
    format = 'iceberg'
  ),
  columns (
    p_partkey BIGINT,
    p_name STRING,
    p_mfgr STRING,
    p_brand STRING,
    p_type STRING,
    p_size BIGINT,
    p_container STRING,
    p_retailprice DECIMAL(12, 2),
    p_comment STRING
  ),
  -- assertions (
  --   unique_values(columns := p_partkey),
  --   not_null(columns := (p_partkey, p_name)),
  --   accepted_range(column := p_retailprice, min_v := 0),
  --   not_match_regex_pattern_list(column := p_type, patterns := ('^$'))
  -- ),
  profiles (p_retailprice, p_size, p_brand, p_type, p_container),
  column_descriptions (
    p_partkey = 'Part key',
    p_name = 'Part name',
    p_mfgr = 'Manufacturer',
    p_brand = 'Brand',
    p_type = 'Type',
    p_size = 'Size',
    p_container = 'Container',
    p_retailprice = 'Retail price',
    p_comment = 'Comment'
  )
);

SELECT
  p_partkey,
  p_name,
  p_mfgr,
  p_brand,
  p_type,
  p_size,
  p_container,
  p_retailprice,
  p_comment
FROM lhs3ny001depot.tpch_sf1.part;
