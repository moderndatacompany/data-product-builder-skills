MODEL (
  name sales.customers,
  kind FULL,
  cron '@daily',
  grain customer_id,
  description 'Customer dimension table with full refresh',
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
  customer_id::VARCHAR AS customer_id,
  CONCAT(first_name, ' ', last_name)::VARCHAR AS full_name,
  email::VARCHAR AS email,
  phone::VARCHAR AS phone,
  CONCAT(address_line1, ' ', COALESCE(address_line2, ''), ' ', city, ' ', state, ' ', postal_code)::VARCHAR AS address_line,
  customer_segment,
  account_status,
  signup_date::DATE AS signup_date,
  loyalty_score::INTEGER AS loyalty_score
FROM raw.raw_customers

