MODEL (
  name lhs3ny001depot.tpch_sparkv3.tpch_region_sf1,
  kind FULL,
  start '2025-01-01',
  grains (r_regionkey),
  columns (
    r_regionkey BIGINT,
    r_name STRING,
    r_comment STRING
  ),
  -- assertions (
  --   unique_values(columns := r_regionkey),
  --   not_null(columns := (r_regionkey, r_name)),
  --   not_constant(column := r_name),
  --   string_length_between(column := r_name, min_v := 3, max_v := 20),
  --   not_match_like_pattern_list(column := r_name, patterns := ('%invalid%'))
  -- ),
  profiles (r_name),
  column_descriptions (
    r_regionkey = 'Region key',
    r_name = 'Region name',
    r_comment = 'Comment'
  )
);

SELECT
  r_regionkey,
  r_name,
  r_comment
FROM lhs3ny001depot.tpch_sf1.region;
