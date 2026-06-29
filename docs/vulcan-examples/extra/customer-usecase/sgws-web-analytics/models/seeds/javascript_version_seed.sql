MODEL (
  name web_analytics_seeds.JAVASCRIPT_VERSION,
  kind SEED (
    path '../../seeds/javascript_version.tsv',
    csv_settings (
      delimiter = '\t'
    )
  ),
  owner 'rohitrajtmdcio',
  description 'Reference data seed for JAVASCRIPT_VERSION',
  tags ('seed', 'reference_data', 'lookup'),
  terms ('javascript_version'),
  columns (
        javascript_version_id BIGINT,
        javascript_version_name VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: JAVASCRIPT_VERSION
-- ============================================================================

SELECT
  javascript_version_id,
  javascript_version_name
FROM SEED();
