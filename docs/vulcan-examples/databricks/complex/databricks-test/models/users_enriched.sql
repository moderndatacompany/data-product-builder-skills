MODEL (
  name b2b_saas.users_enriched,
  kind FULL,
  grains (user_id),
  profiles (industry_name, plan_name, base_price),
  tags ('customer', 'enriched', 'dimension', 'analytics'),
  terms ('customer.enriched_users', 'analytics.user_dimension'),
  description 'Enriched user dimension combining user data with industry classifications and plan details for comprehensive customer analytics',
  column_descriptions (
    user_id = 'Unique identifier for each user',
    email = 'User email address',
    company_name = 'Name of the user company or organization',
    signup_date = 'Timestamp when the user registered on the platform',
    plan_type = 'Current subscription plan type code (free, pro, enterprise)',
    status = 'User account status (active, inactive, churned)',
    company_size = 'Number of employees in the user company',
    signup_channel = 'Marketing channel through which user signed up (organic, paid, referral, etc.)',
    industry = 'Industry code referencing the industry classification',
    days_since_signup = 'Computed number of days since user registration',
    customer_tier = 'Computed customer classification (paying vs free)',
    revenue_status = 'Revenue generation status (revenue_generating, free_tier_15, inactive_user)',
    industry_name = 'Full name of the industry sector (e.g., Technology, Healthcare, Finance)',
    industry_category = 'Broader category grouping for the industry',
    plan_name = 'Human-readable name of the subscription plan',
    base_price = 'Base pricing for the subscription plan',
    max_seats = 'Maximum number of seats allowed in the plan',
    plan_features = 'Features and capabilities included in the subscription plan',
    test_col = 'Test column with constant value for validation purposes'
  )
);

-- Enhanced users model with industry and plan enrichment
SELECT
  u.*,
  i.industry_name,
  i.category as industry_category,
  p.plan_name,
  p.base_price,
  p.max_seats,
  p.features as plan_features,
  '1' as test_col
FROM b2b_saas.users u
LEFT JOIN b2b_saas.industries_seed i ON u.industry = i.industry_code
LEFT JOIN b2b_saas.plan_types_seed p ON u.plan_type = p.plan_code;
