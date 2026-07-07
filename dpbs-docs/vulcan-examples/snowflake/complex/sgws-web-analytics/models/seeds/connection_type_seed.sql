MODEL (
  name web_analytics_seeds.CONNECTION_TYPE,
  kind SEED (
    path '../../seeds/connection_type.tsv',
    csv_settings (
      delimiter = '\t'
    )
  ),
  owner 'rohitrajtmdcio',
  description 'Reference data seed for CONNECTION_TYPE',
  tags ('seed', 'reference_data', 'lookup'),
  terms ('connection_type'),
  columns (
        connection_type_id BIGINT,
        connection_type_name VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: CONNECTION_TYPE
-- ============================================================================

SELECT
  connection_type_id,
  connection_type_name
FROM SEED();
