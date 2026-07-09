MODEL (
  name b2b_saas.subscriptions_seed,
  kind SEED (
    path '../../seeds/subscriptions.csv'
  ),
  columns (
    subscription_id INTEGER,
    user_id INTEGER,
    plan_id INTEGER,
    plan_type VARCHAR,
    mrr DECIMAL(10,2),
    seats INTEGER,
    start_date DATE,
    end_date DATE,
    status VARCHAR,
    billing_cycle VARCHAR
  ),
  audits (
    not_null(columns := (subscription_id, user_id, plan_type, mrr)),
    unique_values(columns := (subscription_id)),
    accepted_values(column := status, is_in := ('active', 'cancelled', 'paused', 'upgraded')),
    accepted_range(column := mrr, min_v := 0, max_v := 50000)
  )
);
