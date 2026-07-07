MODEL (
  name hello.subscriptions,
  kind FULL,
  grains (subscription_id),
  profiles (plan_type, mrr),
  tags ('revenue', 'subscription', 'financial'),
  terms ('revenue.subscription', 'customer.subscription'),
  description 'Subscription lifecycle and revenue tracking table containing active and historical subscriptions with computed ARR, MRR per seat, and revenue categorization metrics',
  column_descriptions (
    subscription_id = 'Unique identifier for each subscription',
    user_id = 'Foreign key to the user who owns this subscription',
    plan_id = 'Foreign key to the subscription plan',
    plan_type = 'Type of subscription plan (free, pro, enterprise)',
    mrr = 'Monthly Recurring Revenue for this subscription in USD',
    seats = 'Number of licensed seats in this subscription',
    start_date = 'Timestamp when the subscription began',
    end_date = 'Timestamp when the subscription ended or will end (null for active subscriptions)',
    status = 'Current subscription status (active, cancelled, expired)',
    billing_cycle = 'Billing frequency (monthly, annual)',
    arr = 'Computed Annual Recurring Revenue (mrr * 12 for annual, mrr for monthly)',
    mrr_per_seat = 'Computed MRR divided by number of seats',
    subscription_duration_days = 'Computed number of days the subscription has been active',
    revenue_category = 'Computed revenue classification (live, recent_churn, historical)'
  ),
  column_tags (
    subscription_id = ('primary_key', 'identifier'),
    user_id = ('foreign_key', 'reference'),
    plan_id = ('foreign_key', 'reference'),
    mrr = ('revenue', 'financial', 'metric'),
    arr = ('revenue', 'financial', 'metric'),
    status = ('business', 'state'),
    billing_cycle = ('business', 'configuration')
  ),
  column_terms (
    subscription_id = ('revenue.subscription_id', 'customer.subscription_id'),
    user_id = ('customer.user_id', 'reference.user_id'),
    mrr = ('revenue.mrr', 'finance.monthly_recurring_revenue'),
    arr = ('revenue.arr', 'finance.annual_recurring_revenue'),
    status = ('revenue.subscription_status', 'customer.status'),
    billing_cycle = ('revenue.billing_cycle', 'customer.billing_frequency')
  ),
  -- cron '@daily'
);

-- Business logic layer with computed metrics  
SELECT 
  subscription_id::string as subscription_id,
  user_id::string as user_id,
  plan_id::string as plan_id,
  plan_type::string as plan_type,
  mrr::float as mrr,
  seats::integer as seats,
  start_date::TIMESTAMP AS start_date,
  end_date::TIMESTAMP AS end_date,
  status::string as status,
  billing_cycle::string as billing_cycle,
  
  -- Computed fields
  CASE WHEN billing_cycle = 'annual' THEN mrr * 12 ELSE mrr END as arr,
  mrr / NULLIF(seats, 0) as mrr_per_seat,
  (COALESCE(end_date, CURRENT_DATE)::DATE - start_date::DATE)::INTEGER as subscription_duration_days,
  
  CASE 
    WHEN status = 'active' THEN 'live'
    WHEN status = 'cancelled' AND end_date >= CURRENT_DATE - INTERVAL '30 days' THEN 'recent_churn'
    ELSE 'historical'
  END as revenue_category

FROM b2b_saas.subscriptions_seed;
