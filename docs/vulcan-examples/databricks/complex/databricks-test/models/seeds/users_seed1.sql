MODEL (
  name b2b_saas.users_seed2,
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
  grain(user_id)
);
