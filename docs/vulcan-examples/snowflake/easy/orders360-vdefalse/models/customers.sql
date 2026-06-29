MODEL (
  name DEMODB.VDEFALSE.CUSTOMERS,
  kind FULL,
  cron '@daily',
  grain CUSTOMER_ID,
  tags ('dimension', 'customer', 'master_data', 'sales', 'vde_disabled'),
  terms ('customer.profile', 'sales.customer_dimension'),
  description 'Customer dimension table with full refresh delivering normalised customer profile information (identity, contact, address, segment, status, loyalty) for direct SQL consumption.',
  assertions (
    not_null(columns := (CUSTOMER_ID, EMAIL)),
    unique_values(columns := (CUSTOMER_ID))
  ),
  column_descriptions (
    CUSTOMER_ID      = 'Unique identifier for each customer',
    FULL_NAME        = 'Concatenated first + last name',
    EMAIL            = 'Customer email address',
    PHONE            = 'Customer phone number',
    ADDRESS_LINE     = 'Full address: street, optional unit, city, state, postal code',
    CUSTOMER_SEGMENT = 'Customer segment tier (Platinum, Gold, Silver, Bronze, Retail)',
    ACCOUNT_STATUS   = 'Account status (Active, Inactive, Suspended)',
    SIGNUP_DATE      = 'Date the customer signed up',
    LOYALTY_SCORE    = 'Customer loyalty score (0-100)'
  ),
  column_tags (
    CUSTOMER_ID      = ('identifier', 'primary_key', 'grain'),
    FULL_NAME        = ('dimension', 'label', 'pii'),
    EMAIL            = ('dimension', 'contact', 'pii'),
    PHONE            = ('dimension', 'contact', 'pii'),
    ADDRESS_LINE     = ('dimension', 'location', 'pii'),
    CUSTOMER_SEGMENT = ('dimension', 'classification', 'label'),
    ACCOUNT_STATUS   = ('dimension', 'status', 'label'),
    SIGNUP_DATE      = ('temporal', 'date'),
    LOYALTY_SCORE    = ('measure', 'metric', 'score')
  ),
  column_terms (
    CUSTOMER_ID      = ('customer.identifier', 'entity.customer_id'),
    FULL_NAME        = ('customer.name', 'person.full_name'),
    EMAIL            = ('customer.email', 'contact.email'),
    CUSTOMER_SEGMENT = ('customer.segment', 'classification.customer_tier'),
    ACCOUNT_STATUS   = ('customer.status', 'account.state'),
    LOYALTY_SCORE    = ('customer.loyalty', 'metric.customer_score')
  )
);

SELECT
  CUSTOMER_ID::VARCHAR AS CUSTOMER_ID,
  CONCAT(FIRST_NAME, ' ', LAST_NAME)::VARCHAR AS FULL_NAME,
  EMAIL::VARCHAR AS EMAIL,
  PHONE::VARCHAR AS PHONE,
  CONCAT(
    ADDRESS_LINE1, ' ',
    COALESCE(ADDRESS_LINE2, ''), ' ',
    CITY, ' ',
    STATE, ' ',
    POSTAL_CODE
  )::VARCHAR AS ADDRESS_LINE,
  CUSTOMER_SEGMENT::VARCHAR AS CUSTOMER_SEGMENT,
  ACCOUNT_STATUS::VARCHAR AS ACCOUNT_STATUS,
  SIGNUP_DATE::DATE AS SIGNUP_DATE,
  LOYALTY_SCORE::INTEGER AS LOYALTY_SCORE
FROM VULCAN.RAW.CUSTOMERS
