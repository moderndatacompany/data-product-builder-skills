-- This is Model Description
-- Core user dimension table containing registered B2B SaaS platform users with enriched attributes including signup information, plan types, company details, and computed customer tier classifications
MODEL (
  name b2b_saas.users,
  kind FULL,
  profiles (plan_type, email, status, company_name),
  grains [user_id],
  cron '@daily',
  tags ('customer', 'dimension', 'classification:PII'),
  terms ('customer.user_profile', 'identity.user'),
  -- description 'Core user dimension table containing registered B2B SaaS platform users with enriched attributes including signup information, plan types, company details, and computed customer tier classifications',
  column_descriptions (
    user_id = 'Unique identifier for each user',
    email_01 = 'User email address',
    company_name = 'Name of the user company or organization',
    signup_date = 'Timestamp when the user registered on the platform',
    status = 'User account status (active, inactive, churned)',
    company_size = 'Number of employees in the user company',
    signup_channel = 'Marketing channel through which user signed up (organic, paid, referral, etc.)',
    industry = 'Industry vertical of the user company',
    days_since_signup = 'Computed number of days since user registration',
    customer_tier = 'Computed customer classification (paying vs free)',
    revenue_status = 'Revenue generation status (revenue_generating, free_tier_15, inactive_user)'
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
  column_terms (
    user_id = ('customer.user_id', 'identity.user_id_01'),
    email_01 = ('contact.email_address', 'identity.email'),
    company_name = ('business.company_name', 'organization.name'),
    signup_date = ('customer.signup_date', 'event.registration_date'),
    status = 'customer.status',
    company_size = ('business.company_size', 'demographic.size'),
    signup_channel = ('marketing.channel', 'acquisition.channel'),
    industry = ('business.industry', 'classification.industry')
  ),
  -- assertions [
  --   all_users_enterprise,
  --   recent_signups_only,
  -- ]
  
);

-- Business logic layer on top of seed data  
-- Add computed fields, data enrichment, etc.
-- Testing check integration - final test
SELECT
  user_id,
  email, -- email is a column dimension
  company_name,
  signup_date::TIMESTAMP AS signup_date,
  -- modified plan type (Animesh)
  plan_type, 
  status,
  company_size,
  signup_channel,
  industry,
  (CURRENT_DATE - signup_date::DATE)::INTEGER as days_since_signup,
  CASE 
    WHEN plan_type IN ('pro', 'enterprise') THEN 'paying'
    ELSE 'free'
  END as customer_tier,
  
  CASE 
    WHEN status = 'active' AND plan_type != 'free' THEN 'revenue_generating'
    WHEN status = 'active' AND plan_type = 'free' THEN 'free_tier_31'
    ELSE 'inactive_user'
  END as revenue_status

FROM b2b_saas.users_seed;
