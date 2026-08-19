MODEL (
  name web_analytics_seeds.PLUGINS,
  kind SEED (
    path '../../seeds/plugins.tsv',
    csv_settings (
      delimiter = '\t'
    )
  ),
  owner '${DATAOS_RUN_AS_USER}',
  description 'Reference data seed for PLUGINS',
  tags ('seed', 'reference_data', 'lookup'),
  terms ('plugins'),
  columns (
        plugin_id BIGINT,
        plugin_name VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: PLUGINS
-- ============================================================================

SELECT
  plugin_id,
  plugin_name
FROM SEED();
