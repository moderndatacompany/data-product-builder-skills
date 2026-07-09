MODEL (
  name b2b_saas.plan_types_seed,
  kind SEED (
    path '../../seeds/plan_types.csv'
  ),
  columns (
    plan_code VARCHAR,
    plan_name VARCHAR,
    base_price DECIMAL(10,2),
    max_seats VARCHAR,
    features VARCHAR
  ),
  audits (
    not_null(columns := (plan_code, plan_name, base_price)),
    unique_values(columns := (plan_code))
  )
);
