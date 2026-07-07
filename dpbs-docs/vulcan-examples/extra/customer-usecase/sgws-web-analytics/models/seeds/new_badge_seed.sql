MODEL (
  name web_analytics_seeds.NEW_BADGE,
  kind SEED (
    path '../../seeds/new_badge.csv'
  ),
  owner 'rohitrajtmdcio',
  description 'Product badge classification reference data',
  tags ('seed', 'reference_data', 'lookup'),
  terms ('new_badge'),
  columns (
        _metadata VARCHAR,
        corp_item_no BIGINT,
        site BIGINT,
        link_item_creation_dt VARCHAR,
        badge VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: NEW_BADGE
-- ============================================================================

SELECT
  _metadata,
  corp_item_no,
  site,
  link_item_creation_dt,
  badge
FROM SEED();
