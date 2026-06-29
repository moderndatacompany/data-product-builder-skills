MODEL (
  name raw.raw_customers,
  kind SEED (
    path '../../seeds/raw_customers.csv'
  ),
  description 'Seed model loading raw customer data from CSV file',
  columns (
    customer_id VARCHAR,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    customer_segment VARCHAR
  ),
  column_descriptions (
    customer_id = 'Unique identifier for each customer',
    first_name = 'Customer first name',
    last_name = 'Customer last name',
    email = 'Customer email address',
    customer_segment = 'Customer tier (Platinum, Gold, Silver, Bronze)'
  ),
  assertions (
    unique_values(columns := (customer_id)),
    not_null(columns := (customer_id, email, customer_segment))
  ),
  grain customer_id
);
