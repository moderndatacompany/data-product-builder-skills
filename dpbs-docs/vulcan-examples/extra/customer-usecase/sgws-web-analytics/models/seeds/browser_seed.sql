MODEL (
  name web_analytics_seeds.BROWSER,
  kind SEED (
    path '../../seeds/browser.tsv',
    csv_settings (
      delimiter = '\t'
    )
  ),
  owner 'rohitrajtmdcio',
  description 'Browser lookup reference data from Adobe Analytics',
  tags ('seed', 'reference_data', 'adobe_analytics', 'lookup'),
  terms ('browser'),
  columns (
        browser_id BIGINT,
        browser_name VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: BROWSER
-- ============================================================================

SELECT
  browser_id,
  browser_name
FROM SEED();
