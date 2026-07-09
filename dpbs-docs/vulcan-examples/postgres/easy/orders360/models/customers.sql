MODEL (
  name sales.customers,
  kind FULL,
  dialect postgres,
  grains (customer_id),
  description 'Minimal placeholder customers model (DELETE LATER)',
  columns (
    customer_id      VARCHAR,
    full_name        VARCHAR,
    email            VARCHAR,
    customer_segment VARCHAR,
    account_status   VARCHAR,
    signup_date      DATE,
    loyalty_score    INT
  )
);

SELECT
  customer_id::VARCHAR      AS customer_id,
  full_name::VARCHAR        AS full_name,
  email::VARCHAR            AS email,
  customer_segment::VARCHAR AS customer_segment,
  account_status::VARCHAR   AS account_status,
  signup_date::DATE         AS signup_date,
  loyalty_score::INT        AS loyalty_score
FROM (
  VALUES
    ('C001', 'Alice Johnson', 'alice.johnson@example.com', 'Platinum', 'Active',   DATE '2022-01-15', 92),
    ('C002', 'Bob Smith',     'bob.smith@example.com',     'Gold',     'Active',   DATE '2022-03-20', 78),
    ('C003', 'Carol Davis',   'carol.davis@example.com',   'Silver',   'Inactive', DATE '2023-06-10', 45)
) AS t (customer_id, full_name, email, customer_segment, account_status, signup_date, loyalty_score);
