MODEL (
  name web_analytics_seeds.TRENDING_BADGE,
  kind SEED (
    path '../../seeds/trending_badge.csv'
  ),
  owner 'rohitrajtmdcio',
  description 'Product badge classification reference data',
  tags ('seed', 'reference_data', 'lookup'),
  terms ('trending_badge'),
  columns (
        class VARCHAR,
        site BIGINT,
        corp_item_no BIGINT,
        month_over_month_sales_growth DECIMAL(18, 4),
        trending_rank BIGINT,
        badge VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: TRENDING_BADGE
-- ============================================================================

SELECT
  class,
  site,
  corp_item_no,
  month_over_month_sales_growth,
  trending_rank,
  badge
FROM SEED();
