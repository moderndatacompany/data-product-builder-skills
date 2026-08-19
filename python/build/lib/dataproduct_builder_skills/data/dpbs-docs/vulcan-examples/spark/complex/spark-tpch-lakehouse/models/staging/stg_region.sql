MODEL (
  name mys3lh02depot.tpch_lakehouse.stg_region,
  kind VIEW,
  start '2025-01-01',
  grains (r_regionkey),
  assertions (
    unique_values(columns := r_regionkey),
    not_null(columns := (r_regionkey, r_name))
  ),
  profiles (r_name),
  column_descriptions (
    r_regionkey = 'Unique region identifier',
    r_name = 'Region name (AFRICA, AMERICA, ASIA, EUROPE, MIDDLE EAST)',
    r_comment = 'Free-text comment'
  )
);

SELECT
  r_regionkey,
  r_name,
  r_comment
FROM mys3lh02depot.tpch_sf1.region;
