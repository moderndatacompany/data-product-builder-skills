MODEL (
  name lhs3ny001depot.tpch_sparkv3.seed_segment_sf1,
  kind SEED (
    path '../seeds/segment_lookup.csv'
  ),
  columns (
    segment_id INT,
    segment_name STRING,
    min_acctbal DOUBLE
  ),
  grain (segment_id)
  -- assertions (
  --   unique_values(columns := segment_id),
  --   not_null(columns := (segment_id, segment_name)),
  --   sequential_values(column := segment_id, interval := 1)
  -- )
);
