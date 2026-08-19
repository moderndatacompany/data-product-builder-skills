MODEL (
  name DEMODB.VDETRUE.CUSTOMERS,
  kind FULL,
  cron '@daily',
  grain CUSTOMER_ID,
  tags ('dimension', 'customer', 'master_data', 'sales', 'vde_enabled'),
  terms ('customer.profile', 'sales.customer_dimension'),
  description 'Customer dimension table with full refresh. Joins VULCAN.RAW.CUSTOMERS to the customer_segments seed to attach segment tier and default discount rate, producing the canonical customer record for downstream order analytics.',
  assertions (
    not_null(columns := (CUSTOMER_ID, EMAIL)),
    unique_values(columns := (CUSTOMER_ID))
  ),
  column_descriptions (
    CUSTOMER_ID           = 'Unique identifier for each customer',
    FULL_NAME             = 'Concatenated first + last name',
    EMAIL                 = 'Customer email address',
    PHONE                 = 'Customer phone number',
    ADDRESS_LINE          = 'Full address: street, optional unit, city, state, postal code',
    SEGMENT_CODE          = 'Raw segment code from source - resolves against the customer_segments seed (12 segments across tiers 0-4)',
    SEGMENT_NAME          = 'Human-readable segment name (joined from customer_segments seed)',
    SEGMENT_TIER          = 'Ordinal segment tier (joined from customer_segments seed; 0 if unmatched)',
    SEGMENT_DISCOUNT_RATE = 'Default discount fraction for this segment (joined from customer_segments seed)',
    ACCOUNT_STATUS        = 'Account status (Active, Inactive, Suspended)',
    SIGNUP_DATE           = 'Timestamp when the customer signed up',
    LOYALTY_SCORE         = 'Customer loyalty score (0-100)'
  ),
  column_tags (
    CUSTOMER_ID           = ('identifier', 'primary_key', 'grain'),
    FULL_NAME             = ('dimension', 'label', 'pii'),
    EMAIL                 = ('dimension', 'contact', 'pii'),
    PHONE                 = ('dimension', 'contact', 'pii'),
    ADDRESS_LINE          = ('dimension', 'location', 'pii'),
    SEGMENT_CODE          = ('dimension', 'classification'),
    SEGMENT_NAME          = ('dimension', 'classification', 'label'),
    SEGMENT_TIER          = ('measure', 'ordinal', 'rank'),
    SEGMENT_DISCOUNT_RATE = ('measure', 'financial', 'percentage'),
    ACCOUNT_STATUS        = ('dimension', 'status', 'label'),
    SIGNUP_DATE           = ('temporal', 'timestamp'),
    LOYALTY_SCORE         = ('measure', 'metric', 'score')
  ),
  column_terms (
    CUSTOMER_ID           = ('customer.identifier', 'entity.customer_id'),
    FULL_NAME             = ('customer.name', 'person.full_name'),
    EMAIL                 = ('customer.email', 'contact.email'),
    SEGMENT_CODE          = ('customer.segment_code', 'classification.customer_tier'),
    SEGMENT_NAME          = ('customer.segment_name', 'classification.customer_tier_name'),
    SEGMENT_DISCOUNT_RATE = ('customer.segment_discount', 'pricing.segment_discount_rate'),
    ACCOUNT_STATUS        = ('customer.status', 'account.state'),
    LOYALTY_SCORE         = ('customer.loyalty', 'metric.customer_score')
  )
);

SELECT
  c.CUSTOMER_ID::VARCHAR AS CUSTOMER_ID,
  CONCAT(c.FIRST_NAME, ' ', c.LAST_NAME)::VARCHAR AS FULL_NAME,
  c.EMAIL::VARCHAR AS EMAIL,
  c.PHONE::VARCHAR AS PHONE,
  CONCAT(
    c.ADDRESS_LINE1, ' ',
    COALESCE(c.ADDRESS_LINE2, ''), ' ',
    c.CITY, ' ',
    c.STATE, ' ',
    c.POSTAL_CODE
  )::VARCHAR AS ADDRESS_LINE,
  c.CUSTOMER_SEGMENT::VARCHAR AS SEGMENT_CODE,
  COALESCE(s.SEGMENT_NAME, 'Unknown')::VARCHAR AS SEGMENT_NAME,
  COALESCE(s.SEGMENT_TIER, 0)::INTEGER AS SEGMENT_TIER,
  COALESCE(s.DISCOUNT_RATE, 0.0)::FLOAT AS SEGMENT_DISCOUNT_RATE,
  c.ACCOUNT_STATUS::VARCHAR AS ACCOUNT_STATUS,
  c.SIGNUP_DATE::TIMESTAMP AS SIGNUP_DATE,
  c.LOYALTY_SCORE::INTEGER AS LOYALTY_SCORE
FROM VULCAN.RAW.CUSTOMERS AS c
LEFT JOIN DEMODB.VDETRUE.CUSTOMER_SEGMENTS AS s
  ON c.CUSTOMER_SEGMENT = s.SEGMENT_CODE
