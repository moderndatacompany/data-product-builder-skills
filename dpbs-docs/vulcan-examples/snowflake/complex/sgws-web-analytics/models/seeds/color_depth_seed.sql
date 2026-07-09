MODEL (
  name web_analytics_seeds.COLOR_DEPTH,
  kind SEED (
    path '../../seeds/color_depth.tsv',
    csv_settings (
      delimiter = '\t'
    )
  ),
  owner 'rohitrajtmdcio',
  description 'Reference data seed for COLOR_DEPTH',
  tags ('seed', 'reference_data', 'lookup'),
  terms ('color_depth'),
  columns (
        color_depth_id BIGINT,
        color_depth_name VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: COLOR_DEPTH
-- ============================================================================

SELECT
  color_depth_id,
  color_depth_name
FROM SEED();
