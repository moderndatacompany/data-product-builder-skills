MODEL (
  name raw.raw_customers,
  kind SEED (
    path '../../seeds/raw_customers.csv'
  ),
  description 'Seed model loading raw customer data from CSV file',
  columns (
    customer_id STRING,
    first_name STRING,
    last_name STRING,
    email STRING,
    phone STRING,
    address_line1 STRING,
    address_line2 STRING,
    city STRING,
    state STRING,
    postal_code STRING,
    customer_segment STRING,
    account_status STRING,
    signup_date DATE,
    loyalty_score INT
  ),
  grain customer_id,
  audits (
    not_null(columns := (customer_id, email, signup_date)),
    unique_values(columns := (customer_id)),
    accepted_values(column := account_status, is_in := ('Active', 'Inactive', 'Suspended')),
    accepted_values(column := customer_segment, is_in := ('Platinum', 'Gold', 'Silver', 'Bronze', 'Retail'))
  )
);

