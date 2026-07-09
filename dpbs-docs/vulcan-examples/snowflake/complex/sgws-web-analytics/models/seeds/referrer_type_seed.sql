MODEL (
  name web_analytics_seeds.REFERRER_TYPE,
  kind SEED (
    path '../../seeds/referrer_type.tsv',
    csv_settings (
      delimiter = '\t'
    )
  ),
  owner 'rohitrajtmdcio',
  description 'Reference data seed for REFERRER_TYPE',
  tags ('seed', 'reference_data', 'lookup'),
  terms ('referrer_type'),
  columns (
        referrer_type_id BIGINT,
        referrer_type_name VARCHAR,
        referrer_type_category VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: REFERRER_TYPE
-- ============================================================================

SELECT
  referrer_type_id,
  referrer_type_name,
  referrer_type_category
FROM SEED();
