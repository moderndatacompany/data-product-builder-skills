MODEL (
  name sales.customers,
  kind FULL,
  cron '@daily',
  grain customer_id,
  description 'Customer dimension table with full refresh',
  audits (
    validate_customer_id
  ),
  columns (
    customer_id STRING,
    full_name STRING,
    email STRING,
    phone STRING,
    address_line STRING,
    customer_segment STRING,
    account_status STRING,
    signup_date DATE,
    loyalty_score INT64
  ),
  column_descriptions (
    customer_id = 'Unique identifier for each customer',
    full_name = 'Customer full name',
    email = 'Customer email address',
    phone = 'Customer phone number',
    address_line = 'Full address including street, city, state, and postal code',
    customer_segment = 'Customer segment tier (Platinum, Gold, Silver, Bronze)',
    account_status = 'Account status (Active, Inactive, Suspended)',
    signup_date = 'Date when customer signed up',
    loyalty_score = 'Customer loyalty score'
  )
);

SELECT
  customer_id,
  CONCAT(first_name, ' ', last_name) AS full_name,
  email,
  phone,
  CONCAT(address_line1, ' ', COALESCE(address_line2, ''), ' ', city, ' ', state, ' ', postal_code) AS address_line,
  customer_segment,
  account_status,
  signup_date,
  loyalty_score
FROM raw.raw_customers

