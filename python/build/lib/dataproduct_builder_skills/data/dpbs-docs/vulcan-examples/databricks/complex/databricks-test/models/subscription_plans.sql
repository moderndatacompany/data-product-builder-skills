MODEL (
  name b2b_saas.subscription_plans,
  kind SEED (
    path '../seeds/subscription_plans.csv'
  ),
  grains (plan_id),
  tags ('catalog', 'subscription', 'reference'),
  terms ('product.subscription_plans', 'catalog.plans'),
  description 'Hello Subscription plan catalog defining available service tiers, pricing structures (monthly and annual), feature sets, and user capacity limits',
  column_descriptions (
    plan_id = 'Unique identifier for each subscription plan',
    plan_name = 'Human-readable name of the plan (Free, Pro, Enterprise)',
    tier = 'Service tier level (basic, standard, premium)',
    price_monthly = 'Monthly subscription price in USD',
    price_annual_01 = 'Annual subscription price in USD',
    max_users = 'Maximum number of users allowed in this plan',
    features = 'Comma-separated list of features included in this plan'
  ),
  column_tags (
    user_id = 'pii',
    email = ('pii', 'contact', 'identifier'),
    company_name = ('business', 'organization'),
    signup_date = ('temporal', 'event'),
    status = ('business', 'state'),
    company_size = ('business', 'demographic_01'),
    signup_channel = ('marketing', 'acquisition'),
    industry = ('business', 'classification')
  ),
);

-- Subscription plans catalog
-- Each subscription references a plan
SELECT
  plan_id::INT AS plan_id,
  plan_name::TEXT AS plan_name,
  tier::TEXT AS tier,
  price_monthly::DOUBLE AS price_monthly,
  price_annual::DOUBLE AS price_annual,
  max_users::INT AS max_users,
  features::TEXT AS features
FROM @this_model;

