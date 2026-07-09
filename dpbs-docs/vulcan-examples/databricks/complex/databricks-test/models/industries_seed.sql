MODEL (
  name b2b_saas.industries_seed1,
  kind SEED (
    path '../seeds/industries.csv'
  ),
  columns (
    industry_code VARCHAR,
    industry_name VARCHAR,
    category VARCHAR
  )
);
