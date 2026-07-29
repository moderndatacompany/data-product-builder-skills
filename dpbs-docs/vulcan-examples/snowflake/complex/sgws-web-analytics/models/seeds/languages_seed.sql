MODEL (
  name web_analytics_seeds.LANGUAGES,
  kind SEED (
    path '../../seeds/languages.tsv',
    csv_settings (
      delimiter = '\t'
    )
  ),
  owner '${DATAOS_RUN_AS_USER}',
  description 'Language code lookup reference data',
  tags ('seed', 'reference_data', 'adobe_analytics', 'lookup'),
  terms ('languages'),
  columns (
        language_id BIGINT,
        language_name VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: LANGUAGES
-- ============================================================================

SELECT
  language_id,
  language_name
FROM SEED();
