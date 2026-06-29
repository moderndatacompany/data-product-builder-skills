MODEL (
  name mys3lh02depot.tpch_lakehouse.stg_nation,
  kind VIEW,
  start '2025-01-01',
  grains (n_nationkey),
  assertions (
    unique_values(columns := n_nationkey),
    not_null(columns := (n_nationkey, n_name, n_regionkey))
  ),
  profiles (n_regionkey, n_name),
  column_descriptions (
    n_nationkey = 'Unique nation identifier',
    n_name = 'Nation name',
    n_regionkey = 'Foreign key to region',
    n_comment = 'Free-text comment'
  )
);

SELECT
  n_nationkey,
  n_name,
  n_regionkey,
  n_comment
FROM mys3lh02depot.tpch_sf1.nation;
