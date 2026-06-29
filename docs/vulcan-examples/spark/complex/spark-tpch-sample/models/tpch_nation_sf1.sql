MODEL (
  name lhs3ny001depot.tpch_sparkv3.tpch_nation_sf1,
  kind SCD_TYPE_2_BY_TIME (
    unique_key n_nationkey,
    valid_from_name valid_from,
    valid_to_name valid_to,
    invalidate_hard_deletes true,
    updated_at_as_valid_from true
  ),
  start '2025-01-01',
  owner 'rohitrajtmdcio',
  tags (nation, scd2, dimension),
  grains (n_nationkey),
  physical_properties (
    format = 'iceberg'
  ),
  columns (
    n_nationkey BIGINT,
    n_name STRING,
    n_regionkey BIGINT,
    n_comment STRING,
    updated_at TIMESTAMP
  ),
  -- assertions (
  --   unique_values(columns := n_nationkey),
  --   not_null(columns := (n_nationkey, n_name)),
  --   at_least_one(column := n_regionkey),
  --   mutually_exclusive_ranges(lower_bound_column := valid_from, upper_bound_column := valid_to)
  -- ),
  profiles (n_regionkey, n_name),
  column_descriptions (
    n_nationkey = 'Nation key',
    n_name = 'Nation name',
    n_regionkey = 'Region key',
    n_comment = 'Comment',
    updated_at = 'Row version time'
  )
);

SELECT
  n_nationkey,
  n_name,
  n_regionkey,
  n_comment,
  CURRENT_TIMESTAMP AS updated_at
FROM lhs3ny001depot.tpch_sf1.nation;
