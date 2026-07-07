MODEL (
  name web_analytics_seeds.BESTSELLER_BADGE,
  kind SEED (
    path '../../seeds/bestseller_badge.csv'
  ),
  owner 'rohitrajtmdcio',
  description 'Product badge classification reference data',
  tags ('seed', 'reference_data', 'lookup'),
  terms ('bestseller_badge'),
  columns (
        class VARCHAR,
        site BIGINT,
        corp_item_no BIGINT,
        unit_sales_rolling_yoy DECIMAL(18, 4),
        bestseller_rank BIGINT,
        badge VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: BESTSELLER_BADGE
-- ============================================================================

SELECT
  class,
  site,
  corp_item_no,
  unit_sales_rolling_yoy,
  bestseller_rank,
  badge
FROM SEED();
