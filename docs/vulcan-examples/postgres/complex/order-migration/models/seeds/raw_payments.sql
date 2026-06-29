MODEL (
  name raw.raw_payments,
  kind SEED (
    path '../../seeds/raw_payments.csv'
  ),
  description 'Seed model loading raw payment data from CSV file',
  columns (
    payment_id VARCHAR,
    order_id VARCHAR,
    payment_date DATE,
    payment_method VARCHAR,
    provider VARCHAR,
    transaction_id VARCHAR,
    amount FLOAT,
    status VARCHAR
  ),
  grain payment_id
);

