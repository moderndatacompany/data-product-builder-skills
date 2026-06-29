MODEL (
  name b2b_saas.users_seed,
  kind SEED (
    path '../../seeds/users.csv'
  ),
  columns (
    user_id INTEGER,
    email VARCHAR,
    company_name VARCHAR,
    signup_date DATE,
    plan_type VARCHAR,
    status VARCHAR,
    company_size VARCHAR,
    signup_channel VARCHAR,
    industry VARCHAR
  ),
  audits (
    not_null(columns := (user_id, email, signup_date)),
    unique_values(columns := (user_id, email)),
    accepted_values(column := plan_type, is_in := ('free', 'starter', 'pro', 'enterprise')),
    accepted_values(column := status, is_in := ('active', 'churned', 'suspended'))
  )
);
