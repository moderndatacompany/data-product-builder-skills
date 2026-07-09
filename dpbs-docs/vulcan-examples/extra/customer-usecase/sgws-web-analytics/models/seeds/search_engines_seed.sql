MODEL (
  name web_analytics_seeds.SEARCH_ENGINES,
  kind SEED (
    path '../../seeds/search_engines.tsv',
    csv_settings (
      delimiter = '\t'
    )
  ),
  owner 'rohitrajtmdcio',
  description 'Reference data seed for SEARCH_ENGINES',
  tags ('seed', 'reference_data', 'lookup'),
  terms ('search_engines'),
  columns (
        search_engine_id BIGINT,
        search_engine_name VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: SEARCH_ENGINES
-- ============================================================================

SELECT
  search_engine_id,
  search_engine_name
FROM SEED();
