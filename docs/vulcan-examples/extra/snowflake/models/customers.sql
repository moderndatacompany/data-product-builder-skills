MODEL (
  name SALES.CUSTOMERS,
  kind FULL,
  cron '@daily',
  grain CUSTOMER_ID,
  tags ('dimension', 'customer', 'master_data', 'sales'),
  terms ('customer.profile', 'sales.customer_dimension'),
  description 'Customer dimension table with full refresh delivering comprehensive customer profile information for sales analysis and customer segmentation',
  column_descriptions (
    CUSTOMER_ID = 'Unique identifier for each customer',
    FULL_NAME = 'Customer full name',
    EMAIL = 'Customer email address',
    PHONE = 'Customer phone number',
    ADDRESS_LINE = 'Full address including street, city, state, and postal code',
    CUSTOMER_SEGMENT = 'Customer segment tier (Platinum, Gold, Silver, Bronze)',
    ACCOUNT_STATUS = 'Account status (Active, Inactive, Suspended)',
    SIGNUP_DATE = 'Date when customer signed up',
    LOYALTY_SCORE = 'Customer loyalty score'
  ),
  column_tags (
    CUSTOMER_ID = ('identifier', 'primary_key', 'grain'),
    FULL_NAME = ('dimension', 'label', 'pii'),
    EMAIL = ('dimension', 'contact', 'pii'),
    PHONE = ('dimension', 'contact', 'pii'),
    ADDRESS_LINE = ('dimension', 'location', 'pii'),
    CUSTOMER_SEGMENT = ('dimension', 'classification', 'label'),
    ACCOUNT_STATUS = ('dimension', 'status', 'label'),
    SIGNUP_DATE = ('temporal', 'date'),
    LOYALTY_SCORE = ('measure', 'metric', 'score')
  ),
  column_terms (
    CUSTOMER_ID = ('customer.identifier', 'entity.customer_id'),
    FULL_NAME = ('customer.name', 'person.full_name'),
    EMAIL = ('customer.email', 'contact.email'),
    CUSTOMER_SEGMENT = ('customer.segment', 'classification.customer_tier'),
    ACCOUNT_STATUS = ('customer.status', 'account.state'),
    LOYALTY_SCORE = ('customer.loyalty', 'metric.customer_score')
  )
);

SELECT
  CUSTOMER_ID::VARCHAR AS CUSTOMER_ID,
  CONCAT(FIRST_NAME, ' ', LAST_NAME)::VARCHAR AS FULL_NAME,
  EMAIL::VARCHAR AS EMAIL,
  PHONE::VARCHAR AS PHONE,
  CONCAT(ADDRESS_LINE1, ' ', COALESCE(ADDRESS_LINE2, ''), ' ', CITY, ' ', STATE, ' ', POSTAL_CODE)::VARCHAR AS ADDRESS_LINE,
  CUSTOMER_SEGMENT,
  ACCOUNT_STATUS,
  SIGNUP_DATE::DATE AS SIGNUP_DATE,
  LOYALTY_SCORE::INTEGER AS LOYALTY_SCORE
FROM VULCAN.RAW.CUSTOMERS
