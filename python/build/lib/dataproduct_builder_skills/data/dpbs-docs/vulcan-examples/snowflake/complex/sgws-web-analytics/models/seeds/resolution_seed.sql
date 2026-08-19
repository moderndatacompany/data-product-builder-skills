MODEL (
  name web_analytics_seeds.RESOLUTION,
  kind SEED (
    path '../../seeds/resolution.tsv',
    csv_settings (
      delimiter = '\t'
    )
  ),
  owner '${DATAOS_RUN_AS_USER}',
  description 'Screen resolution lookup reference data',
  tags ('seed', 'reference_data', 'adobe_analytics', 'lookup'),
  terms ('resolution'),
  columns (
        resolution_id BIGINT,
        resolution_name VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: RESOLUTION
-- ============================================================================

SELECT
  resolution_id,
  resolution_name
FROM SEED();
