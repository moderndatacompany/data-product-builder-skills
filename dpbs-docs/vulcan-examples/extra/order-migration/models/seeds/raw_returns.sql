MODEL (
  name raw.raw_returns,
  kind SEED (
    path '../../seeds/raw_returns.csv'
  ),
  description 'Seed model loading raw return data from CSV file',
  columns (
    return_id VARCHAR,
    order_id VARCHAR,
    order_item_id VARCHAR,
    return_date DATE,
    return_reason VARCHAR,
    return_status VARCHAR,
    refund_amount FLOAT
  ),
  grain return_id
);

