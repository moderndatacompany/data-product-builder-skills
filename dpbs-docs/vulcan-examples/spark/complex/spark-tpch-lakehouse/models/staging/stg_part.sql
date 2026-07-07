MODEL (
  name mys3lh02depot.tpch_lakehouse.stg_part,
  kind VIEW,
  start '2025-01-01',
  grains (p_partkey),
  assertions (
    unique_values(columns := p_partkey),
    not_null(columns := (p_partkey, p_name)),
    accepted_range(column := p_retailprice, min_v := 0)
  ),
  profiles (p_retailprice, p_size, p_brand, p_type, p_container),
  column_descriptions (
    p_partkey = 'Unique part identifier',
    p_name = 'Part name',
    p_mfgr = 'Manufacturer',
    p_brand = 'Brand',
    p_type = 'Part type',
    p_size = 'Part size',
    p_container = 'Container type',
    p_retailprice = 'Retail price',
    p_comment = 'Free-text comment'
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
FROM mys3lh02depot.tpch_sf1.part;
