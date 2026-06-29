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
    customer_id VARCHAR,
    full_name VARCHAR,
    email VARCHAR,
    phone VARCHAR,
    address_line VARCHAR,
    customer_segment VARCHAR,
    account_status VARCHAR,
    signup_date DATE,
    loyalty_score INTEGER
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

