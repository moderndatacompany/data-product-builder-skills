MODEL (
  name web_analytics_seeds.COUNTRY,
  kind SEED (
    path '../../seeds/country.tsv',
    csv_settings (
      delimiter = '\t'
    )
  ),
  owner 'rohitrajtmdcio',
  description 'Country code lookup reference data',
  tags ('seed', 'reference_data', 'adobe_analytics', 'lookup'),
  terms ('country'),
  columns (
        country_id BIGINT,
        country_name VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: COUNTRY
-- ============================================================================

SELECT
  country_id,
  country_name
FROM SEED();
