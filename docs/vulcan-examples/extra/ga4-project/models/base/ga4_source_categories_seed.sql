-- GA4 Source Categories Seed Model
-- Loads source category mappings from CSV
MODEL (
  name ga4_analytics.ga4_source_categories_seed,
  kind SEED(
    path '../../seeds/ga4_source_categories.csv',
  ),
  tags ('seed', 'reference', 'ga4'),
  description 'Source to category mapping for traffic source classification',
  column_descriptions (
    source = 'Traffic source name',
    source_category = 'Category classification (Organic, Paid, Social, Direct, Email)'
  )
);

