MODEL (
  name b2b_saas.subscription_usage_analysis,
  kind FULL,
  grains (subscription_id),
  profiles (plan_type, tier, status),
  description 'Subscription plan analysis combining subscription details, plan features, and aggregated usage metrics to understand plan adoption and feature utilization patterns',
  column_descriptions (
    subscription_id = 'Unique identifier for each subscription',
    user_id = 'Foreign key to the user who owns this subscription',
    plan_id = 'Foreign key to the subscription plan',
    plan_name = 'Human-readable name of the plan (Free, Pro, Enterprise)',
    plan_type = 'Type of subscription plan (free, pro, enterprise)',
    tier = 'Service tier level (basic, standard, premium)',
    price_monthly = 'Monthly subscription price in USD',
    price_annual = 'Annual subscription price in USD',
    max_users = 'Maximum number of users allowed in this plan',
    plan_features = 'Comma-separated list of features included in this plan',
    subscription_status = 'Current subscription status (active, cancelled, expired)',
    mrr = 'Monthly Recurring Revenue for this subscription in USD',
    arr = 'Computed Annual Recurring Revenue',
    seats = 'Number of licensed seats in this subscription',
    billing_cycle = 'Billing frequency (monthly, annual)',
    subscription_start_date = 'Timestamp when the subscription began',
    subscription_end_date = 'Timestamp when the subscription ended or will end',
    total_usage_events = 'Total number of usage events for this subscription user',
    total_engagement_score = 'Sum of engagement scores from all usage events',
    avg_session_duration = 'Average session duration in minutes',
    feature_utilization_rate = 'Computed rate of feature usage relative to plan features',
    last_activity_date = 'Most recent usage event date',
    days_since_last_activity = 'Number of days since the last usage event',
    utilization_status = 'Computed utilization classification (high_utilization, moderate, low, none)'
  )
);

-- Subscription plan analysis with usage metrics
-- Joins subscriptions, subscription_plans, and aggregated usage_events
SELECT 
  s.subscription_id,
  s.user_id,
  s.plan_id,
  sp.plan_name,
  s.plan_type,
  sp.tier,
  sp.price_monthly,
  sp.price_annual,
  sp.max_users,
  sp.features as plan_features,
  s.status as subscription_status,
  s.mrr,
  s.arr,
  s.seats,
  s.billing_cycle,
  s.start_date as subscription_start_date,
  s.end_date as subscription_end_date,
  
  -- Aggregated usage metrics
  COALESCE(ue.total_usage_events, 0) as total_usage_events,
  COALESCE(ue.total_engagement_score, 0) as total_engagement_score,
  COALESCE(ue.avg_session_duration, 0) as avg_session_duration,
  ue.last_activity_date,
  COALESCE((CURRENT_DATE - ue.last_activity_date::DATE)::INTEGER, 999) as days_since_last_activity,
  
  -- Feature utilization rate (simplified - could be enhanced with actual feature matching)
  CASE 
    WHEN ue.total_usage_events > 0 AND sp.max_users > 0 
    THEN ROUND((ue.total_usage_events::DOUBLE / NULLIF(sp.max_users, 0)) * 100, 2)
    ELSE 0
  END as feature_utilization_rate,
  
  -- Utilization status classification
  CASE 
    WHEN ue.total_engagement_score >= 500 THEN 'high_utilization'
    WHEN ue.total_engagement_score >= 100 THEN 'moderate'
    WHEN ue.total_engagement_score > 0 THEN 'low'
    ELSE 'none'
  END as utilization_status

FROM hello.subscriptions s
INNER JOIN b2b_saas.subscription_plans sp ON s.plan_id = sp.plan_id
LEFT JOIN (
  SELECT 
    user_id,
    COUNT(*) as total_usage_events,
    SUM(engagement_score) as total_engagement_score,
    AVG(session_duration) as avg_session_duration,
    MAX(event_date)::DATE as last_activity_date
  FROM b2b_saas.usage_events
  GROUP BY user_id
) ue ON s.user_id = ue.user_id;

