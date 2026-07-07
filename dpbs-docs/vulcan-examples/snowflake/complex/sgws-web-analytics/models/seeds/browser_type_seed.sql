MODEL (
  name web_analytics_seeds.BROWSER_TYPE,
  kind SEED (
    path '../../seeds/browser_type.tsv',
    csv_settings (
      delimiter = '\t'
    )
  ),
  owner 'rohitrajtmdcio',
  description 'Browser lookup reference data from Adobe Analytics',
  tags ('seed', 'reference_data', 'adobe_analytics', 'lookup'),
  terms ('browser_type'),
  columns (
        browser_type_id BIGINT,
        browser_type_name VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: BROWSER_TYPE
-- ============================================================================

SELECT
  browser_type_id,
  browser_type_name
FROM SEED();
