MODEL (
  name raw.raw_customers,
  kind SEED (
    path '../../seeds/raw_customers.csv'
  ),
  description 'Seed model loading raw customer data from CSV file',
  columns (
    customer_id VARCHAR(10),
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    address_line1 VARCHAR(100),
    address_line2 VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    customer_segment VARCHAR(20),
    account_status VARCHAR(20),
    signup_date DATE,
    loyalty_score INT
  ),
  grain customer_id
);

