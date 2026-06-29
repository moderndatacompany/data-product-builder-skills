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
    phone VARCHAR,
    address_line1 VARCHAR,
    address_line2 VARCHAR,
    city VARCHAR,
    state VARCHAR,
    postal_code VARCHAR,
    customer_segment VARCHAR,
    account_status VARCHAR,
    signup_date DATE,
    loyalty_score INTEGER
  ),
  grain customer_id
);

