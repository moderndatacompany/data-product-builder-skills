AUDIT (
  name subscription_revenue_validation,
  standalone true,
  blocking false
);

-- Validate that enterprise accounts have appropriate MRR
WITH enterprise_revenue AS (
  SELECT 
    u.user_id,
    u.company_name,
    u.plan_type,
    s.mrr,
    s.seats
  FROM b2b_saas.users u
  JOIN hello.subscriptions s ON u.user_id = s.user_id
  WHERE u.plan_type = 'enterprise' 
    AND s.status = 'active'
)
SELECT 
  user_id,
  company_name,
  plan_type,
  mrr,
  seats,
  'Enterprise account with unexpectedly low MRR' as issue_type
FROM enterprise_revenue
WHERE mrr < 1000;  -- Enterprise should be >= $1000 MRR

AUDIT (
  name user_subscription_consistency,
  standalone true,
  blocking false
);

-- Validate that user plan_type matches their subscription plan_type
WITH plan_mismatches AS (
  SELECT 
    u.user_id,
    u.company_name,
    u.plan_type as user_plan_type,
    s.plan_type as subscription_plan_type,
    s.status as subscription_status
  FROM b2b_saas.users u
  JOIN hello.subscriptions s ON u.user_id = s.user_id
  WHERE u.plan_type != s.plan_type 
    AND s.status = 'active'
    AND u.status = 'active'
)
SELECT 
  user_id,
  company_name,
  user_plan_type,
  subscription_plan_type,
  'User plan type does not match active subscription' as issue_type
FROM plan_mismatches;

AUDIT (
  name usage_without_subscription,
  standalone true,
  blocking false
);

-- Validate that users with usage events have active subscriptions
WITH usage_without_sub AS (
  SELECT DISTINCT
    ue.user_id,
    u.company_name,
    u.status as user_status,
    COUNT(ue.event_id) as event_count
  FROM b2b_saas.usage_events ue
  JOIN b2b_saas.users u ON ue.user_id = u.user_id
  LEFT JOIN hello.subscriptions s ON u.user_id = s.user_id AND s.status = 'active'
  WHERE s.subscription_id IS NULL
    AND ue.event_date >= CURRENT_DATE - INTERVAL '7 days'
  GROUP BY ue.user_id, u.company_name, u.status
  HAVING COUNT(ue.event_id) > 5  -- More than 5 events without subscription
)
SELECT 
  user_id,
  company_name,
  user_status,
  event_count,
  'High usage activity without active subscription' as issue_type
FROM usage_without_sub;

AUDIT (
  name all_users_enterprise,
  blocking true
);

-- This audit will INTENTIONALLY FAIL to test telemetry capture
-- Check if all users are enterprise (they're not - will fail for free/pro users)
SELECT 
  user_id,
  email,
  company_name,
  plan_type,
  'User is not on enterprise plan' as issue_type
FROM b2b_saas.users
WHERE plan_type != 'enterprise';

AUDIT (
  name recent_signups_only,
  blocking true
);

-- This audit will INTENTIONALLY FAIL to test telemetry capture  
-- Check if all users signed up in last 30 days (will fail for older users)
SELECT 
  user_id,
  email,
  company_name,
  signup_date,
  (CURRENT_DATE - signup_date::DATE)::INTEGER as days_since_signup,
  'User signed up more than 30 days ago' as issue_type
FROM b2b_saas.users
WHERE (CURRENT_DATE - signup_date::DATE)::INTEGER > 50;
