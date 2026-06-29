MODEL (
  name b2b_saas.industries_seed,
  kind SEED (
    path '../../seeds/industries.csv'
  ),
  columns (
    industry_code VARCHAR,
    industry_name VARCHAR,
    category VARCHAR
  ),
  audits (
    not_null(columns := (industry_code, industry_name, category)),
    unique_values(columns := (industry_code))
  )
);
