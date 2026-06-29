MODEL (
  name web_analytics_seeds.OPERATING_SYSTEMS,
  kind SEED (
    path '../../seeds/operating_systems.tsv',
    csv_settings (
      delimiter = '\t'
    )
  ),
  owner 'rohitrajtmdcio',
  description 'Operating system lookup reference data from Adobe Analytics',
  tags ('seed', 'reference_data', 'adobe_analytics', 'lookup'),
  terms ('operating_systems'),
  columns (
        os_id BIGINT,
        os_name VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: OPERATING_SYSTEMS
-- ============================================================================

SELECT
  os_id,
  os_name
FROM SEED();
